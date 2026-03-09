#!/bin/bash

echo "🔄 RESETTING CONSUMER OFFSET TO READ ALL MESSAGES"
echo "================================================"

echo "🛑 Останавливаем booking-history-service..."
docker stop hotelio-booking-history-service

echo "⏳ Ждем 5 секунд..."
sleep 5

echo "🔄 Сбрасываем offset для чтения всех сообщений..."
docker exec hotelio-kafka kafka-consumer-groups \
    --bootstrap-server kafka:9092 \
    --group booking-history-service \
    --reset-offsets \
    --to-earliest \
    --topic booking-created \
    --execute

echo "📊 Проверяем сообщения в топике..."
docker exec hotelio-kafka kafka-console-consumer \
    --bootstrap-server kafka:9092 \
    --topic booking-created \
    --from-beginning \
    --timeout-ms 5000

echo "🚀 Запускаем booking-history-service снова..."
docker start hotelio-booking-history-service

echo "⏳ Ждем 10 секунд для инициализации..."
sleep 10

echo "🔍 Проверяем новые логи Consumer..."
docker logs hotelio-booking-history-service --tail 20

echo "📊 Проверяем offset после перезапуска..."
docker exec hotelio-kafka kafka-consumer-groups \
    --bootstrap-server kafka:9092 \
    --describe \
    --group booking-history-service

echo "🔍 Проверяем данные в booking-history БД..."
docker exec hotelio-booking-history-db psql -U booking_history -d booking_history_db -c "SELECT COUNT(*) as total_records FROM booking_history;"

echo "✅ Сброс завершен!"
