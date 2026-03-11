## Проектная работа второго спринта по курсу Микро-сервисная архитектура от Яндекс Практикума
Hotelio — онлайн-платформа для бронирования отелей и апартаментов. У неё около 1 млн зарегистрированных пользователей и основной трафик приходится на поиск и бронирование жилья. Система построена на Java-монолите, который обеспечивает API для клиентов и партнёрских каналов.

## Проблематика
Сервис Hotelio реализован как единое приложение, в котором все бизнес-функции собраны в одном коде, разворачиваются как единый сервис и используют одну базу данных.
С ростом бизнеса возникли серьёзные архитектурные и операционные проблемы. Команда приняла решение о переходе на микросервисную архитектуру с постепенным выносом сервисов.

## Текущие проблемы

### 1. Сложность сопровождения
- Любое изменение требует понимания всей кодовой базы.
- Невозможно менять один модуль, не затрагивая другие.

### 2. Низкая масштабируемость
- При пиковых нагрузках (например, на бронирование) нельзя масштабировать только нужный компонент.
- Производительность неравномерна.

### 3. Невозможность гибкой разработки
- Разные команды не могут работать независимо.
- Трудно внедрить быстрый CI/CD.

### 4. Ограничения на фронтенде
- REST API монолита слишком универсален и плохо адаптируется под разные платформы.
- Нет поддержки BFF (Backend for Frontend).

### 5. Сложности с запуском новых фич
- Большой риск ошибок из-за плотной связанности.
- Тестирование требует понимания всех зависимостей.

Текущая архитектура: [current_state.puml](tasks/task1/results/diagrams/01-context-as-is.puml)

## Назначение модулей

### 1. BookingService
Обрабатывает создание бронирований.

Функции:
- Выполняет проверки пользователя, отеля, промокода и отзывов.
- Вычисляет финальную цену и размер скидки.
- Сохраняет результат бронирования.

---

### 2. UserService
Отвечает за проверку статуса пользователя.

Функции:
- Проверяет, активен ли пользователь.
- Проверяет, находится ли пользователь в чёрном списке.
- Возвращает текущий статус пользователя.

---

### 3. HotelService
Предоставляет информацию об отелях.

Используется для:
- Валидации бронирования.
- Отображения информации об отелях в интерфейсе.

---

### 4. PromoCodeService
Отвечает за обработку промокодов.

Функции:
- Проверяет действительность промокода.
- Проверяет применимость промокода к конкретному пользователю.

---

### 5. ReviewService
Отвечает за систему отзывов и рейтинг отелей.

Функции:
- Управляет отзывами пользователей.
- Предоставляет рейтинг отеля.
- Может влиять на возможность бронирования при низкой репутации отеля.

## Цели бизнеса

Начать поэтапный переход к микросервисной архитектуре, применяя паттерн **Strangler Fig** — выносить по одному компоненту, оставляя остальной функционал в монолите.

Это позволит:
- упростить масштабирование;
- снизить время вывода новых фич;
- повысить отказоустойчивость системы;
- упростить независимую разработку разных команд.

---

## Целевое состояние через год

- Полный переход на **микросервисную архитектуру**.
- Использование **Service Mesh** с автоматизированными *rollouts*.
- Масштабируемая **Kafka-инфраструктура**.
- Метрики и распределённая трассировка для каждого сервиса.
- Использование **GraphQL** для взаимодействия с фронтендом.

---

## Ближайшие цели (промежуточное состояние через несколько месяцев)

В рамках проектной работы необходимо спроектировать изменения на ближайший этап.

### Планируемые изменения

- Миграция нескольких сервисов из монолита.
- Старые сервисы больше не дорабатываются.
- Новая функциональность разрабатывается только в уже мигрированных сервисах.
- Начато разделение баз данных для:
    - балансировки нагрузки;
    - подготовки к переезду инфраструктуры в облако.

## Что нужно сделать

### 1. Подготовка репозитория
Сделайте форк репозитория с исходными файлами для выполнения проектной работы:

https://github.com/Yandex-Practicum/msa-sprint2

---

### 2. Структура проекта
Проект состоит из **четырёх заданий**.

В репозитории для них создана папка:

```
tasks/
```

Работать над заданиями можно в любом удобном месте.  
Результаты выполнения необходимо складывать в подпапку:

```
results/
```

Для **каждого из четырёх заданий** должна быть отдельная папка с результатами.

---

### 3. Завершение работы
После выполнения всех заданий:

1. Создайте **Pull Request** из веток с результатами заданий.
2. Направьте его в **основную ветку вашего репозитория**.
3. Убедитесь, что Pull Request содержит **все внесённые изменения**.

## Задание 1. Проработка миграции от монолита к микросервисам

### Цель задания: подготовить архитектурный анализ и план начала миграции на микросервисы.
Впереди масштабная трансформация — разделение монолитного Java-приложения на независимые сервисы.

### Что нужно сделать
Изучите текущий код монолита. В директории architecture в readme.md вы найдёте описание модулей системы, структуру проекта и список API-эндпоинтов и их поведение.
Составьте ADR. Оно будет описывать целевое состояние системы. Выберите уровень детализации и количество диаграмм и ADR. Подсветите ключевые проблемы — существующие и найденные вами. Предложите опции решений и их дизайн — как решить текущие проблемы. Прописать план миграции — как перейти к целевому состоянию.
Поскольку ресурсы ограничены, начать миграцию нужно с одного модуля. Определите, какой модуль это будет, и обоснуйте, почему именно он. Сформулируйте план на основе Strangler Fig.
Перед переходом к заданию запустите приложение и базу данных, выполните тесты (см. tests/readme). Это поможет лучше понять архитектуру системы.

Образ результата
Структура и содержание репозитория, в котором нужно сдать решение:

├── ADR/diagram
└── test-log.txt — выгрузка логов или скриншот проверки API и кодовой базы
Загрузите результат в директорию task1/results/ вашего репозитория.

Шаблон ADR: [Шаблон ADR.md](%D0%A8%D0%B0%D0%B1%D0%BB%D0%BE%D0%BD%20ADR.md)

## Задание 2. Реализация новых сервисов

Цель задания: начать миграцию сервисов — реализовать сервис бронирования с использованием Kafka.
В этом задании вы будете реализовывать один из сервисов системы. Предлагаем сделать это на примере сервиса бронирований BookingService. Вы можете сделать это на любом языке, который вам ближе. Общение между сервисом и остальной системой было решено реализовать через gRPC.
Для включения прокси в монолите нужно передать в environment контейнера следующие значения:

      BOOKING_SERVICE_EXTERNAL_HOST: booking-service
      BOOKING_SERVICE_EXTERNAL_PORT: 9090 

Вам предстоит реализовать сервис booking-statistics с помощью Kafka.
Отдел аналитики передал, что ему нужны данные по бронированиям — по пользователям, по отелям, по дням и так далее. DevOps-инженер не даёт доступ к боевой базе. Статистику нужно посчитать в новом сервисе.
Решение — не добавлять дополнительную логику в только что выделенный сервис. Вместо этого — создать отдельный микросервис booking-history-service.
Для реализации этого нужно пока добавить Kafka в контейнер монолита: общая сеть ещё не готова.
Пример готовой конфигурации есть в workspace для task2.

### Что нужно сделать
- Создайте сервис booking-service.
Сервис должен:
Использовать booking.proto контракт — расположен в рабочей директории task2.
Подниматься в Docker.
Использовать отдельную базу в Docker (можно выполнить аналогично monolith).
Быть в той же сети.
  networks:
  hotelio-net:
  external: true
  В docker-compose файле измените host/port на host/port вашего сервиса (дефолт localhost:9090).
  Измените тесты для booking сервиса так, чтобы они соотвестсвовали вашей текущей реализации. Тесты расположены в папке test в корне проекта.
- Создайте сервис booking-history-service, читающие из Kafka. Kafka уже создаётся в рамках docker-compose.
- Доработайте booking-service, чтобы он писал события в Kafka.
- Визуально проверьте появление исторической записи после запуска тестов. Возможно, нужно будет добавить тесты.

### Образ результата
- При создании бронирования монолит перенаправляет запрос на create booking на указанный gRPC Server.
- Запрос списка бронирований в монолите работает так же, как раньше, — будет убран другой командой позже.
- В сервисе booking-service реализована вся необходимая логика.
- Входной точкой для booking-логики становится новый микросервис.
- Все остальные вызовы остаются в монолите.
- Логику для остальных сервисов переносить не нужно: данные в микросервисе должны получаться через REST.
- Сервис booking-service отправляет событие в Kafka (BookingCreated).
- Сервис booking-history-service слушает события и формирует статистику асинхронно, без нагрузки на боевую БД.

### Структура и содержание репозитория, в котором нужно сдать решение
task2/results/
├── Лог/скриншот `docker ps`
├── Доработанный regress.sh (мб. init-fixtures)
├── test-log.txt (проведение тестовых запросов)
├── select * from bookings из новой системы и старой в текстовом виде после выполнения тестов
├── README.md с объяснением стратегии миграции данных при запуске нового сервиса и стратегии To Be
└── листинг бронирований, вызванный через REST из монолита и GRPC из микросервиса
└── select * из таблицы с историческими данными о бронированиях

Загрузите результат в директорию task2/results/ вашего репозитория.

## Задание 3. Личный кабинет

Цель задания — GraphQL Federation:
реализовывать federated-сервисы на Node.js;
интегрировать внешние сервисы;
добавить ACL на уровне GraphQL-поля или запроса;
сделать миграцию типов из схемы монолита в отдельный микросервис;
реализовать оптимальную загрузку данных по отелям.
После первых шагов по выделению модуля бронирования в отдельный gRPC-сервис команда Hotelio столкнулась с новой задачей. Теперь ей нужно создать личный кабинет, чтобы обеспечить удобный и быстрый доступ к информации сразу из нескольких доменов — бронирований и отелей. Этот модуль важен для расширения бизнеса.
Текущие REST-интерфейсы монолита и один gRPC не позволяют гибко агрегировать данные между сервисами без множества последовательных вызовов. Особенно это ощущается при разработке фронтенда. Попробовав несколько решений, команда поняла, что в данном случае просто необходим BFF: решить такую задачу удобно и гибко лишь на API Gateway тяжело.
Hotelio решила перейти к GraphQL-шлюзу, используя Apollo Federation, где каждый домен будет представлен в виде субграфа, объединённый в общий суперграф.
Предполагается, что в дальнейшем появится полноценный API Gateway, поэтому можно сразу продумать, как разграничить доступ к информации. Например, чтобы пользователь не мог видеть чужие бронирования.

### Что нужно сделать
Ваша задача — завершить реализацию федеративного GraphQL API с тремя модулями:
- В сервисе booking-subgraph:
  Бронирования возвращаются по userId.
  Есть поля: id, userId, hotelId, promoCode, discountPercent.
  Необходимо заменить заглушки на реальные вызовы (например, к базе, REST, gRPC).
  Нужно реализовать ACL, чтобы пользователь мог видеть только свои бронирования.
- Сервис hotel-subgraph
  Возвращает описание отелей.
  Используется для hotel { ... } внутри бронирования.
  Должен уметь обращаться к внешнему API или сервису.
  Должно быть разрешено __resolveReference через ID.
- Сервис apollo-gateway:
  Агрегирует схемы booking и hotel.
  Проксирует запросы к нужным подграфам.
- Выделение промокодов в отдельный сабграф.
  Команда решила вынести логику промокодов в отдельный сервис для более гибкого управления акциями. Для миграции нужно перенести небходимые типы из монолита booking в микросервис промокодов.
  Создайте новый сабграф promocode-subgraph, который будет управлять промокодами:
  # booking-subgraph (исходный монолит)
  # пример наполнения

  type Booking @key(fields: "id") {
  id: ID!
  userId: ID!
  hotelId: ID!
  promoCode: String
  discountPercent: Float  # Базовое значение из БД бронирований
  checkIn: String!
  checkOut: String!
  status: BookingStatus!
  }

  type Query {
  userBookings(userId: ID!): [Booking!]!
  booking(id: ID!): Booking
  }

  # promocode-subgraph (новый сервис)
  extend type Booking @key(fields: "id") {
  id: ID! @external
  promoCode: String @external
  }

  #тут просто пример нового типа, можно сделать свой
  type DiscountInfo {
  isValid: Boolean!
  originalDiscount: Float!    # Исходное значение из booking
  finalDiscount: Float!       # Актуальное значение после проверки
  description: String
  expiresAt: String
  applicableHotels: [ID!]!
  }

  #набор запросов для примера
  type Query {
  validatePromoCode(code: String!, hotelId: ID): DiscountInfo!
  activePromoCodes: [DiscountInfo!]!
  }


- Настройте @override, чтобы поле discountPercent теперь резолвилось из promocode-subgraph:
  extend type Booking @key(fields: "id") {
  id: ID! @external
  promoCode: String @external
  discountPercent: Float! @override(from: "booking-subgraph")  # ПЕРЕОПРЕДЕЛЯЕМ значение из booking-subgraph
  discountInfo: DiscountInfo @requires(fields: "promoCode")
  }
  query GetUserBookings {
  userBookings(userId: "123") {
  id
  promoCode
  hotel {
  name
  }
  discountPercent  # Теперь из promocode-subgraph (переопределено)
  discountInfo {
  isValid
  originalDiscount  # Было: 10%
  finalDiscount     # Стало: 25% после применения промокода
  description
  }
  }
  }
- Решение проблемы N+1 в сабграфе отелей:
  При запросе списка бронирований с информацией об отелях может возникнуть проблема N+1, если резолвер будет реализован так:
  __resolveReference: async (hotel) => {
  // отдельный запрос по hotelId
  return await db.hotels.findOne({ id: hotel.id });
  }
  query {
  userBookings(userId: "123") {
  id
  hotel {
  name     # N+1 запросов к сервису отелей!
  address  # N+1 запросов к сервису отелей!
  }
  }
  }
  
- Реализуйте батчинг и кеширование в hotel-subgraph:
  Добавьте поле hotelsByIds(ids: [ID!]!): [Hotel]! в Query.
  Модифицируйте __resolveReference чтобы использовать батчинг.
  Используйте DataLoader, чтобы устранить дублирующиеся запросы и кеширование результатов.
  Загрузите результат в директорию task3/results/ вашего репозитория.

### Образ результата
task3/
├── booking-subgraph/
│   ├── index.js               // TODO: заменить заглушки на вызовы
│   └── ...
├── hotel-subgraph/
│   ├── index.js               // TODO: заменить заглушки на вызовы
│   └── ...
├── apollo-gateway/
│   ├── index.js               // Gateway-конфигурация
│   └── ...
├── docker-compose.yml         // Запускает все 3 модуля
└── README.md                  

Что можно использовать вместо внешнего вызова
Если у вас нет готового API — вставьте заглушку вида:
return [
{
id: 'b1',
userId,
hotelId: 'h1',
discountPercent: 20,
promoCode: 'SUMMER',
},
];
Но лучше попробовать подставить REST/gRPC-вызов из прошлого задания.
Подсказки:
Все заголовки передаются из API Gateway в подграфы автоматически.
Для реализации ACL проверяйте req.headers['userid'] в резолверах.
Если пользователь не авторизован, не возвращайте бронирование.
При использовании реальных модулей не забудьте использовать одну и ту же сеть в Docker.

Структура и содержание репозитория, в котором нужно сдать решение:
task3/results/
├── Report с описанием внесённых изменений
├── Результат docker ps
├── Скриншот успешного вызова
├── Скриншот Deny по ACL
└── Логи booking-subgraph после двух запросов (или всех контейнеров через docker-compose up --build)
Загрузите результат в директорию task3/results/ вашего репозитория.

Задание 4. Автоматизация развёртывания и тестирования

Цель задания: ускорить доставку фич, уменьшить количество ошибок при выкладке и упростить масштабирование в Kubernetes.
После успешного запуска первых двух микросервисов — booking и booking-statistics — и их интеграции в GraphQL-суперграф, компания Hotelio поняла, что ручное развёртывание и тестирование больше не выдерживает темпа изменений. Руководство дало зелёный свет на автоматизацию.
Что нужно сделать
Реализовать Docker-образ сервиса.
В рабочей директории задания сделан простой Mock-сервис для понимания работы фича-флагов.
Для него сделан драфт Helm-чартов и тестов.
Mock-сервис заменён на вашу реализацию.
Дополнительно о реализации сервиса:
собирается с помощью docker build,
сделаны healtcheck endpoint,
сделан ready endpoint,
поведение сервиса меняется при наличии переменной ENABLE_FEATURE_X=true.
Реализовать Helm-чарт.
Deployment с пробами: livenessProbe и readinessProbe по /ping.
Service типа ClusterIP (порт 80 → targetPort 8080).
Значения из values.yaml:
replicaCount;
image.name, image.tag, image.pullPolicy;
env[] — переменные окружения;
resources — requests и limits;
ENABLE_FEATURE_X — фича-флаг.

Обязательно сделайте два варианта values.yaml: для staging и prod.
Реализовать CI/CD-пайплайн (.gitlab-ci.yml).
Стадии:
build: docker build
test: docker run, проверка /ping, docker rm.
deploy: minikube image load и helm upgrade
tag: создать git-тег с timestamp
Если есть unit-тесты, нужно добавить отдельный шаг для их запуска.
Используйте gitlab-ci-local: gitlab-ci-local build test deploy tag.
Реализовать Service Discovery через DNS.
Проверка: http://booking-service/ping работает из другого пода внутри Minikube. Ниже есть инструкция по установке Minikube.
Используйте скрипт check-dns.sh.

Подготовка окружения
Перед началом убедитесь, что на машине установлены:
Docker,
Minikube,
Helm,
Node.js + npm — желательно через nvm,
gitlab-ci-local.
Команды установки (Ubuntu/WSL)
Установка nvm

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source \~/.bashrc
nvm install --lts
Установка gitlab-ci-local

npm install -g gitlab-ci-local
Запуск Minikube

minikube start --driver=docker 

В локальной разработке быстрее тестировать helm/gitlab-ci локально, без деплоя в реальное боевое окружение. Но тестирование полного флоу локально обычно затрудняется отсутствием Docker Registry.
Конфигурация для эмуляции (через Docker Container Registry или Minikube Registry) будет отличаться в зависимости от используемого окружения — Linux, Mac OS или Windows gitbash/wsl2/wsl — из-за разницы в виртуализации и сложности с конфигурацией. Поэтому универсального решения для такого нет.
В этом проекте не используется Docker Registry: для работы был выбран более простой способ — прямая загрузка образа в Minikube через load. В боевой конфигурации helm install просто будет выполняться не локально, а на хосте — потому для изменения работы достаточно будет просто удалить строку с minikube load. Так реализуется лёгкое переключение с тестового режима на боевой.

Проверка сервисов:

./check-status
Пример вывода:

Checking booking-service deployment...
NAME                                     READY   STATUS    RESTARTS   AGE
booking-service-78d99d7dd5-abc           1/1     Running   0          1m

Checking service...
NAME             TYPE        CLUSTER-IP     PORT(S)   AGE
booking-service  ClusterIP   10.96.170.171  80/TCP    1m

Port-forward to test service locally:
kubectl port-forward svc/booking-service 8080:80
Then:
curl http://localhost:8080/ping
Проверка DNS внутри кластера:

./check-dns.sh
Ожидаемый вывод:

[INFO] Running in-cluster DNS test...
[INFO] DNS Response: pong
[PASS] DNS test succeeded
Подсказки:
imagePullPolicy: Never нужен для использования локального образа
minikube image load копирует образ внутрь Minikube
DNS имена booking-service работают только внутри кластера
Для доступа снаружи используйте:

kubectl port-forward svc/booking-service 8080:80
curl http://localhost:8080/ping 

Образ результата
Структура проекта:

task4/
├── booking-service/ # REST-сервис (Go/Java/etc)
├── helm/
│ └── booking-service/ # Helm-чарт сервиса (требуется доработка)
├── .gitlab-ci.yml # CI/CD-пайплайн (требуется доработка)
├── check-dns.sh # Проверка DNS внутри кластера
├── check-status # Статус деплоя и curl локально
├── README.md  
Dockerfile для каждого микросервиса
helm/-директория с чартами.
.gitlab-ci.yml с пайплайном.
README.md с инструкцией по разворачиванию в Minikube.
Логика обнаружения сервисов (DNS).
Пример успешного деплоя в Kubernetes (скриншот или вывод команды get pods + get services).
Структура и содержание репозитория, в котором нужно сдать решение:

task4/results/
├── report.md # Описание изменений и решений
├── values-staging.yaml
├── values-prod.yaml
├── .gitlab-ci.yml
├── Скриншот успешного curl на /ping
├── Скриншот ./check-dns.sh
├── Скриншот ./check-status
├── kubectl get pods + get services
├── Лог успешной сборки
└── docker image ls + minikube image list
Загрузите результат в директорию task4/results/ вашего репозитория.

gitlab-ci-local build test deploy tag

---remove below:
Ниже — готовый вариант для **task4**: сервис, Docker, Helm, CI/CD, DNS-check и файлы для `results/`.

Я не могу физически записать файлы в репозиторий за тебя в этом чате, но даю **готовое содержимое**, которое можно просто вставить.

---

## Что я сделал

- доделал `booking-service`;
- добавил:
  - `/ping`
  - `/health`
  - `/ready`
  - фича-флаг `ENABLE_FEATURE_X=true`;
- исправил `Dockerfile`;
- дополнил Helm chart:
  - `Deployment`
  - `Service`
  - `livenessProbe`
  - `readinessProbe`
  - `env[]`
  - `resources`
  - `image.pullPolicy`
  - `ENABLE_FEATURE_X`
- сделал `.gitlab-ci.yml` со стадиями:
  - `build`
  - `test`
  - `deploy`
  - `tag`
- улучшил `check-dns.sh` и `check-status.sh`;
- подготовил `values-staging.yaml`, `values-prod.yaml` и `report.md` для `task4/results/`.

---

## 1) Сервис

### `tasks/task4/booking-service/main.go`

```textmate
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

type statusResponse struct {
	Status          string `json:"status"`
	Service         string `json:"service"`
	FeatureXEnabled bool   `json:"featureXEnabled"`
}

func main() {
	enableFeatureX := os.Getenv("ENABLE_FEATURE_X") == "true"

	mux := http.NewServeMux()

	mux.HandleFunc("/ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("pong"))
	})

	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, statusResponse{
			Status:          "UP",
			Service:         "booking-service",
			FeatureXEnabled: enableFeatureX,
		})
	})

	mux.HandleFunc("/ready", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, statusResponse{
			Status:          "READY",
			Service:         "booking-service",
			FeatureXEnabled: enableFeatureX,
		})
	})

	mux.HandleFunc("/feature", func(w http.ResponseWriter, r *http.Request) {
		if !enableFeatureX {
			http.Error(w, "Feature X is disabled", http.StatusNotFound)
			return
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"message": "Feature X is enabled",
			"enabled": true,
		})
	})

	log.Println("booking-service is running on :8080")
	log.Printf("ENABLE_FEATURE_X=%v", enableFeatureX)

	server := &http.Server{
		Addr:    ":8080",
		Handler: mux,
	}

	log.Fatal(server.ListenAndServe())
}

func writeJSON(w http.ResponseWriter, statusCode int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(payload)
}
```


---

## 2) Dockerfile

Текущий `Dockerfile` пытается копировать `check-dns.sh` внутрь образа, но это лишнее и часто ломает сборку из контекста `booking-service/`.

### `tasks/task4/booking-service/Dockerfile`

```dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /app

COPY main.go .
RUN go build -o booking-service main.go

FROM alpine:3.20

RUN apk add --no-cache curl

WORKDIR /app

COPY --from=builder /app/booking-service ./booking-service

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD curl --fail http://localhost:8080/health || exit 1

CMD ["./booking-service"]
```


---

## 3) Helm chart

### `tasks/task4/helm/booking-service/templates/deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.name }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}

          ports:
            - containerPort: {{ .Values.service.targetPort }}

          env:
            - name: ENABLE_FEATURE_X
              value: {{ .Values.ENABLE_FEATURE_X | quote }}
            {{- range .Values.env }}
            - name: {{ .name }}
              value: {{ .value | quote }}
            {{- end }}

          livenessProbe:
            httpGet:
              path: /ping
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.livenessProbe.failureThreshold }}

          readinessProbe:
            httpGet:
              path: /ping
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.readinessProbe.failureThreshold }}

          resources:
            requests:
              cpu: {{ .Values.resources.requests.cpu | quote }}
              memory: {{ .Values.resources.requests.memory | quote }}
            limits:
              cpu: {{ .Values.resources.limits.cpu | quote }}
              memory: {{ .Values.resources.limits.memory | quote }}
```


---

### `tasks/task4/helm/booking-service/values.yaml`

```yaml
replicaCount: 1

image:
  name: booking-service
  tag: latest
  pullPolicy: Never

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ENABLE_FEATURE_X: "false"

env:
  - name: APP_ENV
    value: local

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"

livenessProbe:
  initialDelaySeconds: 3
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3

readinessProbe:
  initialDelaySeconds: 3
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```


`service.yaml` у тебя уже нормальный, его можно оставить как есть.

---

## 4) GitLab CI/CD

### `tasks/task4/.gitlab-ci.yml`

```yaml
stages:
  - build
  - test
  - deploy
  - tag

variables:
  IMAGE_NAME: booking-service
  IMAGE_TAG: latest
  CONTAINER_NAME: booking-service-test
  HELM_RELEASE: booking-service
  HELM_CHART_PATH: helm/booking-service
  HELM_VALUES_FILE: helm/booking-service/values.yaml

build:
  stage: build
  script:
    - docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ./booking-service

test:
  stage: test
  script:
    - docker rm -f ${CONTAINER_NAME} || true
    - docker run -d --name ${CONTAINER_NAME} -p 8080:8080 ${IMAGE_NAME}:${IMAGE_TAG}
    - sleep 5
    - curl --fail http://localhost:8080/ping
    - docker rm -f ${CONTAINER_NAME}

deploy:
  stage: deploy
  script:
    - minikube image load ${IMAGE_NAME}:${IMAGE_TAG}
    - helm upgrade --install ${HELM_RELEASE} ${HELM_CHART_PATH} -f ${HELM_VALUES_FILE}

tag:
  stage: tag
  script:
    - git tag deploy-$(date +%Y%m%d%H%M%S)
```


> Если захочешь, можно добавить `only:`/`rules:`, но для локальной проверки через `gitlab-ci-local` этот минимальный вариант удобнее.

Проверка:
```shell script
gitlab-ci-local build test deploy tag
```


---

## 5) Скрипт DNS-проверки

Текущий скрипт интерактивный (`-it`), это неудобно для автоматизации. Лучше сделать неинтерактивно и с понятным выводом.

### `tasks/task4/check-dns.sh`

```shell script
#!/bin/bash

set -e

echo "[INFO] Running in-cluster DNS test..."

DNS_RESPONSE=$(kubectl run dns-test \
  --image=busybox \
  --restart=Never \
  --rm -i \
  --command -- wget -qO- http://booking-service/ping)

echo "[INFO] DNS Response: ${DNS_RESPONSE}"

if [ "${DNS_RESPONSE}" = "pong" ]; then
  echo "[PASS] DNS test succeeded"
else
  echo "[FAIL] DNS test failed"
  exit 1
fi
```


---

## 6) Скрипт проверки статуса

У тебя файл называется `check-status.sh`, а в задании местами фигурирует `check-status`. Это не критично, но лучше README тоже привести к `check-status.sh`.

### `tasks/task4/check-status.sh`

```shell script
#!/bin/bash

set -e

echo "Checking booking-service deployment..."
kubectl get pods -l app=booking-service

echo
echo "Checking service..."
kubectl get svc booking-service || echo "(No service found)"

echo
echo "Port-forward to test service locally:"
echo "kubectl port-forward svc/booking-service 8080:80"
echo "Then:"
echo "curl http://localhost:8080/ping"
```


---

## 7) README

### `tasks/task4/README.md`

```markdown
# Task 4 — Автоматизация развёртывания и тестирования

## Что реализовано

- REST-сервис `booking-service`
- Docker-образ с `HEALTHCHECK`
- endpoint'ы:
  - `/ping` → `pong`
  - `/health`
  - `/ready`
  - `/feature` при `ENABLE_FEATURE_X=true`
- Helm chart для Kubernetes
- CI/CD pipeline в `.gitlab-ci.yml`
- DNS-проверка сервиса внутри Minikube

## Структура
```
text
task4/
├── booking-service/
│   ├── Dockerfile
│   └── main.go
├── helm/
│   └── booking-service/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
├── .gitlab-ci.yml
├── check-dns.sh
├── check-status.sh
├── README.md
└── results/
```
## Локальная сборка
```
bash
docker build -t booking-service:latest ./booking-service
docker run --rm -p 8080:8080 booking-service:latest
curl http://localhost:8080/ping
curl http://localhost:8080/health
curl http://localhost:8080/ready
```
## Проверка feature flag
```
bash
docker run --rm -p 8080:8080 -e ENABLE_FEATURE_X=true booking-service:latest
curl http://localhost:8080/feature
```
Если флаг не передан, `/feature` вернёт `404`.

## Деплой в Minikube
```
bash
minikube start --driver=docker
docker build -t booking-service:latest ./booking-service
minikube image load booking-service:latest
helm upgrade --install booking-service ./helm/booking-service -f ./helm/booking-service/values.yaml
```
## Проверка

### Статус ресурсов
```
bash
./check-status.sh
```
### Проверка снаружи через port-forward
```
bash
kubectl port-forward svc/booking-service 8080:80
curl http://localhost:8080/ping
```
### Проверка DNS внутри кластера
```
bash
./check-dns.sh
```
Ожидаемый результат:
```
text
[INFO] Running in-cluster DNS test...
[INFO] DNS Response: pong
[PASS] DNS test succeeded
```
## Локальная проверка CI
```
bash
gitlab-ci-local build test deploy tag
```
## Профили окружений

Для сдачи подготовлены:
- `results/values-staging.yaml`
- `results/values-prod.yaml`
```


---

## 8) Файлы для `task4/results/`

Нужно положить как минимум эти текстовые файлы.

---

### `tasks/task4/results/values-staging.yaml`

```yaml
replicaCount: 1

image:
  name: booking-service
  tag: latest
  pullPolicy: Never

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ENABLE_FEATURE_X: "true"

env:
  - name: APP_ENV
    value: staging

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "250m"
    memory: "256Mi"

livenessProbe:
  initialDelaySeconds: 3
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3

readinessProbe:
  initialDelaySeconds: 3
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```


---

### `tasks/task4/results/values-prod.yaml`

```yaml
replicaCount: 3

image:
  name: booking-service
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

ENABLE_FEATURE_X: "false"

env:
  - name: APP_ENV
    value: production

resources:
  requests:
    cpu: "200m"
    memory: "256Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"

livenessProbe:
  initialDelaySeconds: 5
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3

readinessProbe:
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```


---

### `tasks/task4/results/.gitlab-ci.yml`

Скопируй сюда тот же файл, что я дал выше для `tasks/task4/.gitlab-ci.yml`.

---

### `tasks/task4/results/report.md`

```markdown
# Task 4 Report

## Что было сделано

В рамках задания реализован полный минимальный pipeline автоматизации развёртывания и тестирования сервиса `booking-service`.

### 1. Реализован сервис
Сервис написан на Go и запускается на порту `8080`.

Поддерживаемые endpoint'ы:
- `GET /ping` → `pong`
- `GET /health` → статус `UP`
- `GET /ready` → статус `READY`
- `GET /feature` → доступен только при `ENABLE_FEATURE_X=true`

### 2. Реализован Docker-образ
Сервис собирается через:
```
bash
docker build -t booking-service:latest ./booking-service
```
В Dockerfile добавлен `HEALTHCHECK` на endpoint `/health`.

### 3. Реализован Helm chart
Добавлены:
- `Deployment`
- `Service`
- `livenessProbe`
- `readinessProbe`
- переменные окружения
- ресурсы контейнера
- поддержка `ENABLE_FEATURE_X`

Service создаётся как `ClusterIP`, порт `80` проксируется на `8080`.

### 4. Подготовлены конфигурации окружений
Сделаны два values-файла:
- `values-staging.yaml`
- `values-prod.yaml`

### 5. Реализован CI/CD pipeline
Добавлен `.gitlab-ci.yml` со стадиями:
- `build`
- `test`
- `deploy`
- `tag`

Pipeline:
- собирает Docker-образ
- запускает контейнер и проверяет `/ping`
- загружает образ в Minikube через `minikube image load`
- выполняет `helm upgrade --install`
- создаёт git-тег с timestamp

### 6. Реализована DNS-проверка Service Discovery
Проверка выполняется скриптом `check-dns.sh`.

Сервис доступен по DNS-имени:
```
text
http://booking-service/ping
```
из другого pod внутри Minikube.

## Как запускать

### Локальная сборка
```
bash
docker build -t booking-service:latest ./booking-service
docker run --rm -p 8080:8080 booking-service:latest
curl http://localhost:8080/ping
```
### Деплой в Minikube
```
bash
minikube start --driver=docker
minikube image load booking-service:latest
helm upgrade --install booking-service ./helm/booking-service -f ./helm/booking-service/values.yaml
```
### Проверка
```
bash
./check-status.sh
./check-dns.sh
kubectl port-forward svc/booking-service 8080:80
curl http://localhost:8080/ping
```
## Итог
Задание покрывает базовый локальный CI/CD flow без Docker Registry и подходит для демонстрации автоматизации деплоя в Kubernetes через Minikube.
```


---

## 9) Как запускать после вставки файлов

### Сборка
```shell script
cd tasks/task4
docker build -t booking-service:latest ./booking-service
```


### Локальный тест
```shell script
docker run --rm -p 8080:8080 booking-service:latest
curl http://localhost:8080/ping
curl http://localhost:8080/health
curl http://localhost:8080/ready
```


### С feature flag
```shell script
docker run --rm -p 8080:8080 -e ENABLE_FEATURE_X=true booking-service:latest
curl http://localhost:8080/feature
```


### Minikube + Helm
```shell script
minikube start --driver=docker
minikube image load booking-service:latest
helm upgrade --install booking-service ./helm/booking-service -f ./helm/booking-service/values.yaml
kubectl get pods
kubectl get svc
./check-dns.sh
```


### Локальная эмуляция пайплайна
```shell script
gitlab-ci-local build test deploy tag
```


---

## 10) Что ещё нужно приложить в `results/`

По заданию останется руками добавить артефакты:

- скриншот `curl http://localhost:8080/ping`
- скриншот `./check-dns.sh`
- скриншот `./check-status.sh`
- вывод `kubectl get pods && kubectl get services`
- лог успешной сборки
- вывод `docker image ls`
- вывод `minikube image list`

---

Если хочешь, я могу следующим сообщением сделать ещё удобнее:  
**собрать это в формате “список файлов → полный финальный контент каждого файла без объяснений”**, чтобы ты просто копировал по очереди.