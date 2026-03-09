#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RESULTS_DIR="results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Создаем папку results если её нет
mkdir -p $RESULTS_DIR

echo -e "${BLUE}🚀 Начинаем сборку и тестирование системы Hotelio (Task 2)${NC}"
echo "=================================================="

echo -e "${YELLOW}🌐 Создаем Docker network...${NC}"
docker network create hotelio-net 2>/dev/null || echo "Network hotelio-net уже существует"

echo -e "${YELLOW}🛑 Останавливаем предыдущие контейнеры...${NC}"
docker compose down -v --remove-orphans 2>/dev/null

echo -e "${YELLOW}🗑️ Удаляем старые образы для принудительной пересборки...${NC}"
docker compose down --rmi local 2>/dev/null || true

echo -e "${YELLOW}🧽 Очищаем Docker кеш...${NC}"
docker builder prune -f 2>/dev/null || true

echo -e "${YELLOW}☕ Пересобираем Java проекты...${NC}"
cd ../..
mvn clean package -DskipTests -pl tasks/task2/booking-service,tasks/task2/booking-history-service,hotelio-monolith
cd tasks/task2

echo -e "${YELLOW}🏗️ Собираем образы без кеша...${NC}"
docker compose build --no-cache --pull

echo -e "${YELLOW}🚀 Запускаем систему задания 2...${NC}"
docker compose up -d

echo -e "${YELLOW}⏳ Ждем поднятия сервисов (30 секунд)...${NC}"
sleep 30

echo -e "${BLUE}🔍 Убеждаемся что Consumer готов принимать сообщения...${NC}"
CONSUMER_READY=0
for i in {1..5}; do
    if docker logs hotelio-booking-history-service 2>&1 | grep -q "partitions assigned"; then
        echo "✅ Consumer готов к получению сообщений (попытка $i)"
        CONSUMER_READY=1
        break
    else
        echo "⏳ Consumer еще инициализируется, ждем... (попытка $i)"
        sleep 10
    fi
done

if [ $CONSUMER_READY -eq 0 ]; then
    echo "⚠️ WARNING: Consumer может быть не готов!"
fi

echo -e "${BLUE}🔍 Проверяем версии кода в логах...${NC}"
echo "Проверка Booking Service:"
docker logs hotelio-booking-service 2>&1 | grep "CODE VERSION" || echo "❌ Новая версия кода не обнаружена в Booking Service"
echo "Проверка Booking History Service:"
docker logs hotelio-booking-history-service 2>&1 | grep "CODE VERSION" || echo "❌ Новая версия кода не обнаружена в Booking History Service"

echo -e "${BLUE}📊 Сохраняем docker ps в результаты...${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" > $RESULTS_DIR/docker-ps-log.txt
docker ps

echo -e "${BLUE}🔍 Проверяем логи всех сервисов...${NC}"
docker logs hotelio-booking-service > $RESULTS_DIR/booking-service-logs.txt 2>&1
docker logs hotelio-booking-history-service > $RESULTS_DIR/booking-history-service-logs.txt 2>&1

echo -e "${BLUE}📋 Проверяем логи монолита...${NC}"
docker logs hotelio-monolith > $RESULTS_DIR/monolith-logs.txt 2>&1
echo "Логи монолита сохранены в $RESULTS_DIR/monolith-logs.txt"

echo -e "${BLUE}🔍 Диагностика Kafka...${NC}"
{
    echo ""
    echo "=== KAFKA DIAGNOSTICS ==="
    echo "Timestamp: $(date)"
    echo ""

    echo "--- Проверка доступности Kafka broker ---"
    docker exec hotelio-kafka kafka-broker-api-versions --bootstrap-server kafka:9092 2>/dev/null | head -10 || echo "❌ Kafka недоступна"
    echo ""

    echo "--- Список топиков Kafka ---"
    docker exec hotelio-kafka kafka-topics --bootstrap-server kafka:9092 --list 2>/dev/null || echo "❌ Не удалось получить список топиков"
    echo ""

    echo "--- Проверка топика booking-created ---"
    docker exec hotelio-kafka kafka-topics --bootstrap-server kafka:9092 --describe --topic booking-created 2>/dev/null || echo "❌ Топик booking-created не найден"
    echo ""

    echo "--- Проверка сообщений в booking-created ---"
    docker exec hotelio-kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic booking-created --from-beginning --timeout-ms 5000 2>/dev/null || echo "Нет сообщений в топике"
    echo ""

    echo "--- Проверка consumer group booking-history-service ---"
    docker exec hotelio-kafka kafka-consumer-groups --bootstrap-server kafka:9092 --describe --group booking-history-service 2>/dev/null || echo "❌ Consumer group не найдена"
    echo ""

} > $RESULTS_DIR/kafka-diagnostics.txt

echo -e "${BLUE}🧪 Проверяем доступность сервисов...${NC}"
{
    echo "=== HEALTH CHECKS ==="
    echo "Timestamp: $(date)"
    echo ""

    echo "--- Монолит health check ---"
    curl -s http://localhost:8084/health || curl -s http://localhost:8084/ || echo "❌ Монолит недоступен"
    echo ""

    echo "--- Booking service health check ---"
    curl -s http://localhost:8085/actuator/health || echo "❌ Booking service недоступен"
    echo ""

    echo "--- Booking history service health check ---"
    curl -s http://localhost:8086/actuator/health || echo "❌ Booking history service недоступен"
    echo ""
} > $RESULTS_DIR/health-checks.txt

echo -e "${GREEN}🎯 Запускаем регрессионные тесты с инициализацией БД...${NC}"

# Устанавливаем переменные окружения для regress.sh
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_USER="hotelio"
export DB_NAME="hotelio"
export BOOKING_DB_HOST="localhost"
export BOOKING_DB_PORT="5433"
export BOOKING_DB_USER="booking"
export BOOKING_DB_NAME="booking_db"
export API_URL="http://localhost:8084"

# Переходим в папку test и запускаем regress.sh
TEST_LOG="$RESULTS_DIR/test-log.txt"
cd ../../test

echo "=== HOTELIO BOOKING SERVICE TEST LOG ===" > "../tasks/task2/$TEST_LOG"
echo "Timestamp: $(date)" >> "../tasks/task2/$TEST_LOG"
echo "Environment: Task 2 - Microservices Migration" >> "../tasks/task2/$TEST_LOG"
echo "" >> "../tasks/task2/$TEST_LOG"

echo -e "${BLUE}🧪 Запуск полного регрессионного тестирования...${NC}"
if ./regress.sh >> "../tasks/task2/$TEST_LOG" 2>&1; then
    echo -e "${GREEN}✅ Регрессионные тесты успешно завершены${NC}"
else
    echo -e "${YELLOW}⚠️ Некоторые тесты могут не пройти из-за миграции на микросервисы${NC}"
fi

# Возвращаемся в исходную папку
cd ../tasks/task2

echo -e "${BLUE}💾 Сохраняем данные из баз данных...${NC}"

# Данные из booking service БД
{
    echo "=== СТРУКТУРА И ДАННЫЕ ИЗ BOOKING SERVICE БД ==="
    echo "Список таблиц:"
    docker exec hotelio-booking-db psql -U booking -d booking_db -c "\dt"
    echo ""
    echo "Структура таблицы bookings:"
    docker exec hotelio-booking-db psql -U booking -d booking_db -c "\d bookings"
    echo ""
    echo "Данные из таблицы bookings:"
    docker exec hotelio-booking-db psql -U booking -d booking_db -c "SELECT * FROM bookings;" || echo "Ошибка получения данных"
} > $RESULTS_DIR/booking-service-db-data.txt 2>&1

# Данные из монолита БД
{
    echo "=== СТРУКТУРА И ДАННЫЕ ИЗ МОНОЛИТА БД ==="
    echo "Список таблиц:"
    docker exec hotelio-db psql -U hotelio -d hotelio -c "\dt"
    echo ""
    echo "Структура таблицы booking:"
    docker exec hotelio-db psql -U hotelio -d hotelio -c "\d booking"
    echo ""
    echo "Данные из таблицы booking:"
    docker exec hotelio-db psql -U hotelio -d hotelio -c "SELECT * FROM booking;" || echo "Таблица booking не найдена"
} > $RESULTS_DIR/monolith-db-data.txt 2>&1

# Данные из booking history БД
{
    echo "=== СТРУКТУРА И ДАННЫЕ ИЗ BOOKING HISTORY БД ==="
    echo "Список таблиц:"
    docker exec hotelio-booking-history-db psql -U booking_history -d booking_history_db -c "\dt"
    echo ""
    echo "Структура таблицы booking_history:"
    docker exec hotelio-booking-history-db psql -U booking_history -d booking_history_db -c "\d booking_history"
    echo ""
    echo "Данные из таблицы booking_history:"
    docker exec hotelio-booking-history-db psql -U booking_history -d booking_history_db -c "SELECT * FROM booking_history;" || echo "Ошибка получения данных"
} > $RESULTS_DIR/booking-history-db-data.txt 2>&1

echo -e "${BLUE}📋 Создаем листинги бронирований...${NC}"

# Листинг через REST из монолита (после инициализации БД)
{
    echo "=== ЛИСТИНГ БРОНИРОВАНИЙ ПОСЛЕ РЕГРЕССИОННЫХ ТЕСТОВ ==="
    echo "Timestamp: $(date)"
    echo ""

    echo "--- Тестовые пользователи (должны быть доступны) ---"
    echo "GET /api/bookings?userId=test-user-2:"
    curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:8084/api/bookings?userId=test-user-2" | jq . 2>/dev/null || curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:8084/api/bookings?userId=test-user-2"
    echo ""

    echo "GET /api/bookings?userId=test-user-3:"
    curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:8084/api/bookings?userId=test-user-3" | jq . 2>/dev/null || curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:8084/api/bookings?userId=test-user-3"
    echo ""

    echo "--- Все бронирования после тестов ---"
    curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:8084/api/bookings" | jq . 2>/dev/null || curl -s -w "\nHTTP_CODE:%{http_code}" "http://localhost:8084/api/bookings"
    echo ""

    echo "--- Статистика пользователей ---"
    echo "test-user-1 (в блэклисте):"
    curl -s "http://localhost:8084/api/users/test-user-1" || echo "Пользователь недоступен"
    echo ""
    echo "test-user-2 (активный):"
    curl -s "http://localhost:8084/api/users/test-user-2" || echo "Пользователь недоступен"
    echo ""
    echo "test-user-3 (VIP):"
    curl -s "http://localhost:8084/api/users/test-user-3" || echo "Пользователь недоступен"
} > $RESULTS_DIR/rest-bookings-listing.txt

# Информация о gRPC
{
    echo "=== ЛИСТИНГ БРОНИРОВАНИЙ ЧЕРЕЗ gRPC ==="
    echo "gRPC Endpoint: booking-service:9090"
    echo "Timestamp: $(date)"
    echo ""
    echo "ПРИМЕЧАНИЕ: gRPC сервис работает только для inter-service коммуникации"
    echo "REST запросы к монолиту автоматически проксируются в gRPC booking-service"
    echo ""
    echo "Архитектура:"
    echo "Client -> REST API (монолит:8084) -> gRPC (booking-service:9090) -> БД"
    echo ""
    echo "Логи gRPC вызовов в booking-service:"
    docker logs hotelio-booking-service 2>&1 | grep -i "grpc\|booking" | tail -20
} > $RESULTS_DIR/grpc-bookings-listing.txt

echo -e "${BLUE}📋 Создаем итоговый отчет...${NC}"
{
    echo "=== ИТОГОВЫЙ ОТЧЕТ ТЕСТИРОВАНИЯ TASK 2 ==="
    echo "Timestamp: $(date)"
    echo "Environment: Microservices Migration"
    echo ""

    echo "=== АРХИТЕКТУРА ==="
    echo "Монолит (порт 8084) -> gRPC Booking Service (порт 9090) -> Booking DB (порт 5433)"
    echo "Kafka Events -> Booking History Service (порт 8086) -> History DB (порт 5434)"
    echo ""

    echo "=== СТАТУС КОНТЕЙНЕРОВ ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep hotelio || echo "Нет запущенных контейнеров"
    echo ""

    echo "=== КОЛИЧЕСТВО ДАННЫХ В БД ==="
    echo "Монолит БД (основные данные):"
    docker exec hotelio-db psql -U hotelio -d hotelio -t -c "SELECT 'Users: ' || COUNT(*) FROM app_user;" 2>/dev/null || echo "БД недоступна"
    docker exec hotelio-db psql -U hotelio -d hotelio -t -c "SELECT 'Hotels: ' || COUNT(*) FROM hotel;" 2>/dev/null || echo "БД недоступна"
    docker exec hotelio-db psql -U hotelio -d hotelio -t -c "SELECT 'Reviews: ' || COUNT(*) FROM review;" 2>/dev/null || echo "БД недоступна"
    docker exec hotelio-db psql -U hotelio -d hotelio -t -c "SELECT 'Promos: ' || COUNT(*) FROM promo_code;" 2>/dev/null || echo "БД недоступна"
    echo ""
    echo "Booking БД (микросервис):"
    docker exec hotelio-booking-db psql -U booking -d booking_db -t -c "SELECT 'Bookings: ' || COUNT(*) FROM bookings;" 2>/dev/null || echo "БД недоступна"
    echo ""
    echo "History БД (микросервис):"
    docker exec hotelio-booking-history-db psql -U booking_history -d booking_history_db -t -c "SELECT 'History: ' || COUNT(*) FROM booking_history;" 2>/dev/null || echo "БД недоступна"
    echo ""

    echo "=== РЕЗУЛЬТАТ ТЕСТИРОВАНИЯ ==="
    if grep -q "✅ Все HTTP-тесты пройдены!" "$TEST_LOG" 2>/dev/null; then
        echo "✅ РЕГРЕССИОННЫЕ ТЕСТЫ ПРОШЛИ УСПЕШНО"
    else
        echo "⚠️ ЕСТЬ ПРОБЛЕМЫ В ТЕСТАХ - проверьте $TEST_LOG"
    fi

} > $RESULTS_DIR/final-report.txt

echo -e "${GREEN}🎉 Тестирование Task 2 завершено!${NC}"
echo "Результаты сохранены в папке: $RESULTS_DIR/"
echo "Основные файлы:"
echo "  - test-log.txt - полный лог тестов"
echo "  - final-report.txt - итоговый отчет"
echo "  - *-db-data.txt - содержимое баз данных"
echo "  - health-checks.txt - статус сервисов"

echo -e "${BLUE}📡 Проверяем Kafka и топики...${NC}"

{
    echo "=== KAFKA DIAGNOSTICS ==="
    echo "Timestamp: $(date)"
    echo ""

    echo "--- Проверка доступности Kafka broker ---"
    docker exec hotelio-kafka kafka-broker-api-versions --bootstrap-server kafka:9092 2>/dev/null \
        || echo "❌ Kafka broker недоступен"
    echo ""

    echo "--- Список топиков Kafka ---"
    docker exec hotelio-kafka kafka-topics \
        --bootstrap-server kafka:9092 \
        --list 2>/dev/null || echo "❌ Не удалось получить список топиков"
    echo ""

    echo "--- Проверка топика booking-created ---"
    docker exec hotelio-kafka kafka-topics \
        --bootstrap-server kafka:9092 \
        --describe \
        --topic booking-created 2>/dev/null || echo "❌ Топик booking-created не найден"
    echo ""

    echo "--- Проверка сообщений в booking-created ---"
    docker exec hotelio-kafka kafka-console-consumer \
        --bootstrap-server kafka:9092 \
        --topic booking-created \
        --from-beginning \
        --timeout-ms 3000 2>/dev/null || echo "Нет сообщений или ошибка чтения"
    echo ""

    echo "--- Проверка consumer group booking-history-service ---"
    docker exec hotelio-kafka kafka-consumer-groups \
        --bootstrap-server kafka:9092 \
        --describe \
        --group booking-history-service 2>/dev/null || echo "Consumer group не найдена"
    echo ""

} > $RESULTS_DIR/kafka-diagnostics.txt 2>&1

