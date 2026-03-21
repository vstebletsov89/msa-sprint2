## 🛠️ Подготовка окружения

Ознакомьтесь с предложенной структурой.
В дальнейшем поднять сервис можно будет с помощью:
```bash
docker compose up -d --build
```
---

## 🚀 Проверка корректности

Выполните следующий GraphQL-запрос через GraphQL Playground на http://localhost:4000/:
```
graphql
	query {
		bookingsByUser(userId: "user1") {
			id
			hotel {
				name
				city
			}
			discountPercent
		}
	}
```
Можно запрашивать больше данных.
Перед этим добавьте заголовок userid: user1, иначе данные не вернутся из-за ACL.

---

📌 Подсказки
- Все заголовки передаются из Gateway в подграфы автоматически.
- Для реализации ACL проверяйте req.headers['userid'] в резолверах.
- Если пользователь не авторизован, не возвращайте бронирование.
- При использовании реальных модулей не забудьте использовать одну и ту же сеть в docker!

### 1. Успешный запрос с ACL


bash curl -X POST [http://localhost:4000/graphql](http://localhost:4000/graphql)
-H "Content-Type: application/json"
-H "userid: test-user-1"
-d '{ "query": "query { userBookings(userId: "test-user-1") { id promoCode hotel { name } discountPercent } }" }'

### 2. ACL Deny (неправильный пользователь)

bash curl -X POST [http://localhost:4000/graphql](http://localhost:4000/graphql)
-H "Content-Type: application/json"
-H "userid: test-user-2"
-d '{ "query": "query { userBookings(userId: "test-user-1") { id } }" }'

``` 
3. Тест N+1 решения
```
bash curl -X POST [http://localhost:4000/graphql](http://localhost:4000/graphql)
-H "Content-Type: application/json"
-H "userid: test-user-1"
-d '{ "query": "query { userBookings(userId: "test-user-1") { id hotel { name address rating } } }" }'

docker-compose up
# Продакшн
docker-compose -f docker-compose.yml up -d
# Логи
docker-compose logs -f booking-subgraph
