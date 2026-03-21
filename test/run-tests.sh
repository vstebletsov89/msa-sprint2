#!/bin/bash
set -e

echo "⚙️ Установка переменных окружения..."

export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=hotelio
export DB_PASSWORD=hotelio
export DB_NAME=hotelio
export API_URL=http://localhost:8084

echo "🚀 Запуск регрессионных тестов..."

bash regress.sh