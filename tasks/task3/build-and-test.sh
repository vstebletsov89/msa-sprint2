#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RESULTS_DIR="./results"
COMPOSE="docker compose -f docker-compose.yml"
GATEWAY_URL="http://localhost:4000/"

mkdir -p "$RESULTS_DIR"

echo "============================================"
echo "  Hotelio Federation — Build & Test"
echo "  $(date)"
echo "============================================"

# ─── 1. Остановить старые контейнеры ─────────────────────────
echo ""
echo "🧹 Останавливаем старые контейнеры..."
$COMPOSE down --remove-orphans 2>/dev/null || true

# ─── 2. Сборка без кеша ──────────────────────────────────────
echo ""
echo "🔨 Сборка образов (--no-cache)..."
$COMPOSE build --no-cache

# ─── 3. Запуск ────────────────────────────────────────────────
echo ""
echo "🚀 Запуск контейнеров..."
$COMPOSE up -d

# ─── 4. Ожидание готовности ───────────────────────────────────
echo ""
echo "⏳ Ожидание готовности сервисов (до 90 сек)..."

wait_for_service() {
  local name="$1"
  local url="$2"
  local max_attempts=30
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if curl -sf -X POST "$url" \
         -H "Content-Type: application/json" \
         -d '{"query":"{__typename}"}' -o /dev/null 2>/dev/null; then
      echo "  ✅ $name готов"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 3
  done

  echo "  ❌ $name не ответил за ${max_attempts} попыток"
  return 1
}

wait_for_service "booking-subgraph"   "http://localhost:4001/"
wait_for_service "hotel-subgraph"     "http://localhost:4002/"
wait_for_service "promocode-subgraph" "http://localhost:4003/"
wait_for_service "apollo-gateway"     "http://localhost:4000/"

# ─── 5. docker ps ─────────────────────────────────────────────
echo ""
echo "📋 Сохраняем docker ps..."
{
  echo "=== DOCKER PS ==="
  echo "Timestamp: $(date)"
  echo ""
  docker ps --filter "name=task3" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
} > "$RESULTS_DIR/docker-ps.txt"
cat "$RESULTS_DIR/docker-ps.txt"

# ─── 6. Успешный запрос (ACL pass) ────────────────────────────
echo ""
echo "🧪 Тест 1: Успешный запрос userBookings (userid: test-user-1)..."

SUCCESS_QUERY='{"query":"query GetUserBookings { userBookings(userId: \"test-user-1\") { id userId hotelId promoCode checkIn checkOut status hotel { id name city address rating pricePerNight } discountPercent discountInfo { isValid originalDiscount finalDiscount description expiresAt applicableHotels } } }"}'

SUCCESS_RESPONSE=$(curl -s -X POST "$GATEWAY_URL" \
  -H "Content-Type: application/json" \
  -H "userid: test-user-1" \
  -d "$SUCCESS_QUERY" 2>&1)

{
  echo "=== УСПЕШНЫЙ ВЫЗОВ (ACL PASS) ==="
  echo "Timestamp: $(date)"
  echo ""
  echo "Request:"
  echo "  Header: userid: test-user-1"
  echo "  Query: GetUserBookings { userBookings(userId: \"test-user-1\") { id userId hotelId promoCode hotel { name } discountPercent discountInfo { isValid originalDiscount finalDiscount description } } }"
  echo ""
  echo "Response:"
  echo "$SUCCESS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$SUCCESS_RESPONSE"
} > "$RESULTS_DIR/success-query.txt"

echo "  Ответ сохранён в $RESULTS_DIR/success-query.txt"

# ─── 7. ACL Deny запрос ──────────────────────────────────────
echo ""
echo "🧪 Тест 2: ACL Deny — user-2 пытается получить бронирования user-1..."

DENY_QUERY='{"query":"query { userBookings(userId: \"test-user-1\") { id userId hotelId } }"}'

DENY_RESPONSE=$(curl -s -X POST "$GATEWAY_URL" \
  -H "Content-Type: application/json" \
  -H "userid: test-user-2" \
  -d "$DENY_QUERY" 2>&1)

{
  echo "=== ACL DENY ==="
  echo "Timestamp: $(date)"
  echo ""
  echo "Request:"
  echo "  Header: userid: test-user-2"
  echo "  Query: userBookings(userId: \"test-user-1\") — чужие бронирования"
  echo ""
  echo "Response (ожидается ошибка Access denied):"
  echo "$DENY_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$DENY_RESPONSE"
} > "$RESULTS_DIR/acl-deny-query.txt"

echo "  Ответ сохранён в $RESULTS_DIR/acl-deny-query.txt"

# ─── 8. Логи контейнеров ─────────────────────────────────────
echo ""
echo "📝 Сохраняем логи контейнеров..."

{
  echo "=== ЛОГИ BOOKING-SUBGRAPH ==="
  echo "Timestamp: $(date)"
  echo ""
  $COMPOSE logs booking-subgraph 2>&1
} > "$RESULTS_DIR/booking-subgraph-logs.txt"

{
  echo "=== ЛОГИ ВСЕХ КОНТЕЙНЕРОВ ==="
  echo "Timestamp: $(date)"
  echo ""
  $COMPOSE logs 2>&1
} > "$RESULTS_DIR/all-containers-logs.txt"

# ─── 9. Report ────────────────────────────────────────────────
echo ""
echo "📄 Генерируем report..."

cat > "$RESULTS_DIR/report.md" << 'REPORT'
# Task 3 — GraphQL Federation Report

## Архитектура
Реализован федеративный GraphQL API на базе Apollo Federation v2 с тремя субграфами и одним gateway:

## Внесённые изменения

### 1. booking-subgraph
- Реализован federated subgraph с `@key(fields: "id")` на типе `Booking`
- Поля: id, userId, hotelId, promoCode, discountPercent, checkIn, checkOut, status
- **ACL**: проверка `req.headers['userid']` — пользователь видит только свои бронирования
- Ссылка на Hotel через `hotel: Hotel @provides(fields: "id")`
- Query: `userBookings(userId)`, `booking(id)`

### 2. hotel-subgraph
- Тип Hotel с `@key(fields: "id")`: id, name, city, address, rating, pricePerNight
- **DataLoader** для устранения N+1: `createHotelLoader()` с batching и caching
- `__resolveReference` использует DataLoader для батчированных запросов
- Query: `hotel(id)`, `hotelsByIds(ids)`, `hotels`

### 3. promocode-subgraph (новый сервис)
- **Миграция типов**: промокодная логика выделена из booking в отдельный субграф
- Federation v2 с `extend schema @link(url: "https://specs.apollo.dev/federation/v2.0")`
- `@override(from: "booking")` на поле `discountPercent` — теперь рассчитывается из promocode-subgraph
- Тип `DiscountInfo` с полями: isValid, originalDiscount, finalDiscount, description, expiresAt, applicableHotels
- Query: `validatePromoCode(code, hotelId)`, `activePromoCodes`

### 4. apollo-gateway
- `IntrospectAndCompose` агрегирует все 3 субграфа
- Проксирование заголовков (включая userid) в субграфы
- Логирование GraphQL-операций через плагин

### 5. Docker Compose (production-ready)
- Multi-stage Dockerfile для всех сервисов (минимальный размер образа)
- Non-root user (appuser) для безопасности
- Healthcheck через POST GraphQL `{__typename}`
- `depends_on: service_healthy` — gateway стартует только после субграфов
- Resource limits, restart policy, log rotation

## Ключевые паттерны
- **ACL на уровне GraphQL**: заголовок `userid` проверяется в резолверах
- **DataLoader**: батчинг + кеширование = решение N+1 при загрузке отелей
- **@override**: миграция поля `discountPercent` из booking в promocode
- **Federation v2**: `extend schema @link` для поддержки директив v2
REPORT

echo "  Report сохранён в $RESULTS_DIR/report.md"

# ─── 10. Итог ─────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  ✅ Готово! Результаты в $RESULTS_DIR/"
echo "============================================"
echo ""
ls -la "$RESULTS_DIR/"
echo ""

# Краткая проверка
if echo "$SUCCESS_RESPONSE" | grep -q '"userBookings"'; then
  echo "✅ Успешный запрос: данные получены"
else
  echo "❌ Успешный запрос: данные НЕ получены"
fi

if echo "$DENY_RESPONSE" | grep -q -i "denied\|error"; then
  echo "✅ ACL Deny: ошибка доступа получена"
else
  echo "❌ ACL Deny: ошибка НЕ обнаружена"
fi