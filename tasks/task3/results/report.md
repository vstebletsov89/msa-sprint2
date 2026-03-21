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
