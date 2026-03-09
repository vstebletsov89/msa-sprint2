#!/bin/bash

echo "🧪 TESTING EVENT SENDING"
echo "========================"

echo "🔍 Проверяем текущие offset в Kafka..."
docker exec hotelio-kafka kafka-consumer-groups --bootstrap-server kafka:9092 --describe --group booking-history-service 2>/dev/null || echo "Consumer group пока не активна"

echo ""
echo "🔄 Сбрасываем Consumer offset для чтения всех сообщений..."
docker exec hotelio-kafka kafka-consumer-groups --bootstrap-server kafka:9092 --group booking-history-service --reset-offsets --to-earliest --topic booking-created --execute 2>/dev/null || echo "Consumer group активна, сброс невозможен"

echo ""
echo "📤 Отправляем тестовое бронирование через REST API..."
curl -X POST "http://localhost:8084/api/bookings" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "userId=test-user-2&hotelId=test-hotel-1" \
  -v

echo ""
echo "⏳ Ждем 10 секунд для обработки события..."
sleep 10

echo ""
echo "🔍 Проверяем логи booking-service за последние 20 строк..."
docker logs hotelio-booking-service --tail 20

echo ""
echo "🔍 Проверяем логи booking-history-service за последние 20 строк..."
docker logs hotelio-booking-history-service --tail 20

echo ""
echo "🔍 Проверяем offset после отправки..."
docker exec hotelio-kafka kafka-consumer-groups --bootstrap-server kafka:9092 --describe --group booking-history-service 2>/dev/null || echo "Consumer group пока не активна"

echo ""
echo "🔍 Проверяем данные в booking-history БД..."
docker exec hotelio-booking-history-db psql -U booking_history -d booking_history_db -c "SELECT COUNT(*) as total_records FROM booking_history;"

echo ""
echo "✅ Тест завершен!"
