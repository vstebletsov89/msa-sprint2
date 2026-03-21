#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RESULTS_DIR="results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p $RESULTS_DIR

echo -e "${BLUE}🚀 Начинаем сборку и тестирование системы Hotelio (Task 2)${NC}"
echo "=================================================="

wait_for_consumer() {
  echo -e "${BLUE}⏳ Ожидаем готовность Kafka consumer...${NC}"
  for i in {1..30}; do
      if docker logs hotelio-booking-history-service 2>&1 | grep -q "partitions assigned"; then
          echo -e "${GREEN}✅ Kafka consumer готов${NC}"
          return 0
      fi
      sleep 2
  done
  echo -e "${RED}❌ Kafka consumer не запустился${NC}"
  exit 1
}

echo -e "${YELLOW}🌐 Создаем Docker network...${NC}"
docker network create hotelio-net 2>/dev/null || true

echo -e "${YELLOW}🛑 Останавливаем предыдущие контейнеры...${NC}"
docker compose down -v --remove-orphans 2>/dev/null

echo -e "${YELLOW}🗑️ Удаляем старые образы...${NC}"
docker compose down --rmi local 2>/dev/null || true
docker builder prune -f 2>/dev/null || true

echo -e "${YELLOW}☕ Пересобираем Java проекты...${NC}"
cd ../..
mvn clean package -DskipTests -pl tasks/task2/booking-service,tasks/task2/booking-history-service,hotelio-monolith
cd tasks/task2

echo -e "${YELLOW}🏗️ Собираем образы без кеша...${NC}"
docker compose build --no-cache --pull

echo -e "${YELLOW}🚀 Запускаем систему...${NC}"
docker compose up -d

echo -e "${YELLOW}⏳ Ждем старта сервисов...${NC}"
sleep 20

wait_for_consumer

echo -e "${BLUE}🔄 Сбрасываем Kafka offsets...${NC}"
docker exec hotelio-kafka kafka-consumer-groups \
  --bootstrap-server kafka:9092 \
  --group booking-history-service \
  --topic booking-created \
  --reset-offsets --to-earliest --execute 2>/dev/null || true

sleep 3

echo -e "${BLUE}🧪 Проверяем доступность сервисов...${NC}"
{
echo "=== HEALTH CHECKS ==="
echo "Timestamp: $(date)"
echo ""
echo "--- Монолит ---"
curl -s http://localhost:8084/health || curl -s http://localhost:8084/
echo ""
echo "--- Booking Service ---"
curl -s http://localhost:8085/actuator/health
echo ""
echo "--- Booking History Service ---"
curl -s http://localhost:8086/actuator/health
} > $RESULTS_DIR/health-checks.txt

# 1. СНАЧАЛА ЗАПУСКАЕМ ТЕСТЫ!
echo -e "${GREEN}🎯 Запускаем регрессионные тесты...${NC}"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_USER="hotelio"
export DB_NAME="hotelio"
export BOOKING_DB_HOST="localhost"
export BOOKING_DB_PORT="5433"
export BOOKING_DB_USER="booking"
export BOOKING_DB_NAME="booking_db"
export API_URL="http://localhost:8084"

TEST_LOG="$RESULTS_DIR/test-log.txt"

cd ../../test
echo "=== HOTELIO TEST LOG ===" > "../tasks/task2/$TEST_LOG"
echo "Timestamp: $(date)" >> "../tasks/task2/$TEST_LOG"

if ./regress.sh >> "../tasks/task2/$TEST_LOG" 2>&1; then
    echo -e "${GREEN}✅ Регрессионные тесты завершены${NC}"
else
    echo -e "${YELLOW}⚠️ Некоторые тесты могли не пройти${NC}"
fi
cd ../tasks/task2

# 2. КРИТИЧЕСКИ ВАЖНО: ЖДЕМ ПОКА KAFKA CONSUMER ОБРАБОТАЕТ СООБЩЕНИЯ!
echo -e "${YELLOW}⏳ Ждем 5 секунд для асинхронной обработки Kafka сообщений...${NC}"
sleep 5

# 3. ТОЛЬКО ТЕПЕРЬ СОБИРАЕМ ЛОГИ И ПРОВЕРЯЕМ БД!
echo -e "${BLUE}💾 Проверяем запись в booking_history...${NC}"
docker exec hotelio-booking-history-db \
  psql -U booking_history \
  -d booking_history_db \
  -c "SELECT * FROM booking_history;" \
  > $RESULTS_DIR/booking-history-db-data.txt 2>&1

echo -e "${BLUE}📊 Сохраняем docker ps...${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" > $RESULTS_DIR/docker-ps-log.txt

echo -e "${BLUE}🔍 Сохраняем логи сервисов (теперь они содержат реальные запросы!)...${NC}"
docker logs hotelio-booking-service > $RESULTS_DIR/booking-service-logs.txt 2>&1
docker logs hotelio-booking-history-service > $RESULTS_DIR/booking-history-service-logs.txt 2>&1
docker logs hotelio-monolith > $RESULTS_DIR/monolith-logs.txt 2>&1

echo -e "${BLUE}🔍 Kafka диагностика...${NC}"
{
echo "=== KAFKA DIAGNOSTICS ==="
echo "Timestamp: $(date)"
echo ""
echo "--- Messages in topic (должны быть здесь!) ---"
docker exec hotelio-kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic booking-created \
  --from-beginning \
  --timeout-ms 5000
echo ""
echo "--- Consumer group ---"
docker exec hotelio-kafka kafka-consumer-groups \
  --bootstrap-server kafka:9092 \
  --describe \
  --group booking-history-service
} > $RESULTS_DIR/kafka-diagnostics.txt 2>&1

echo -e "${BLUE}📋 Финальный отчет...${NC}"
{
echo "=== FINAL REPORT ==="
echo "Timestamp: $(date)"
echo ""
echo "--- Containers ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
echo "--- Booking DB ---"
docker exec hotelio-booking-db psql -U booking -d booking_db -t \
  -c "SELECT COUNT(*) FROM bookings;"
echo ""
echo "--- History DB ---"
docker exec hotelio-booking-history-db psql -U booking_history -d booking_history_db -t \
  -c "SELECT COUNT(*) FROM booking_history;"
} > $RESULTS_DIR/final-report.txt

echo -e "${GREEN}🎉 Тестирование завершено! Проверьте логи теперь!${NC}"