#!/bin/bash

echo "🧪 SIMPLE BOOKING TEST - DEBUG EVENT PUBLISHING"
echo "==============================================="

echo "🔍 Проверяем логи booking-service ПЕРЕД созданием бронирования..."
docker logs hotelio-booking-service --tail 5

echo ""
echo "📤 Отправляем ОДНО тестовое бронирование..."
curl -X POST "http://localhost:8084/api/bookings" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "userId=test-user-2&hotelId=test-hotel-1"

echo ""
echo "⏳ Ждем 5 секунд..."
sleep 5

echo ""
echo "🔍 Проверяем логи booking-service ПОСЛЕ бронирования..."
docker logs hotelio-booking-service --tail 30

echo ""
echo "🔍 Проверяем логи booking-history-service..."
docker logs hotelio-booking-history-service --tail 15

echo ""
echo "📊 Проверяем топик Kafka..."
docker exec hotelio-kafka kafka-console-consumer \
    --bootstrap-server kafka:9092 \
    --topic booking-created \
    --from-beginning \
    --timeout-ms 3000

echo ""
echo "✅ Тест завершен!"
