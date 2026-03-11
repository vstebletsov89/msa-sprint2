# Task 4 Report

## Что было сделано

В рамках задания реализован полный минимальный pipeline автоматизации развёртывания и тестирования сервиса booking-service.

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
kubectl get pods
kubectl get svc
```
### Проверка
```
bash
./check-status.sh
./check-dns.sh
kubectl port-forward svc/booking-service 8080:80
curl http://localhost:8080/ping
```

### Локальная эмуляция пайплайна
```shell script
gitlab-ci-local build test deploy tag
```

## Итог
Задание покрывает базовый локальный CI/CD flow без Docker Registry и подходит для демонстрации автоматизации деплоя в Kubernetes через Minikube.
```