#!/bin/bash

set -e

echo "========================================="
echo " Fallback Route Test"
echo "========================================="
echo ""

SERVICE_URL="${SERVICE_URL:-http://booking-service}"

# Для fallback-теста всегда используем v2-под (т.к. v1 будет остановлен)
FALLBACK_POD=$(kubectl get pods -l app=booking-service,version=v2 -o jsonpath='{.items[0].metadata.name}')

mesh_curl() {
  kubectl exec "$FALLBACK_POD" -c booking-service -- curl -s "$@" 2>/dev/null || echo "ERROR"
}

echo "▶️  Текущие поды booking-service:"
kubectl get pods -l app=booking-service -o wide
echo ""

echo "▶️  Проверка ответа сервиса перед остановкой v1..."
RESPONSE_BEFORE=$(mesh_curl "$SERVICE_URL/ping")
echo "  Response: $RESPONSE_BEFORE"
echo ""

# Масштабируем v1 до 0 реплик для имитации отказа
echo "▶️  Масштабируем v1 до 0 реплик (имитация отказа)..."
kubectl scale deployment booking-service-v1 --replicas=0 2>/dev/null || echo "  Deployment booking-service-v1 not found, skipping scale"

echo "  Ожидание завершения подов v1..."
kubectl wait --for=delete pod -l app=booking-service,version=v1 --timeout=30s 2>/dev/null || sleep 10

echo ""
echo "▶️  Поды после остановки v1:"
kubectl get pods -l app=booking-service -o wide
echo ""

echo "▶️  Отправка запросов (должны идти на v2 через fallback/circuit breaker)..."
SUCCESS=0
TOTAL=10

for i in $(seq 1 $TOTAL); do
  RESPONSE=$(mesh_curl --max-time 5 "$SERVICE_URL/ping")
  echo "  Request $i: $RESPONSE"
  if echo "$RESPONSE" | grep -q "pong"; then
    SUCCESS=$((SUCCESS + 1))
  fi
done

echo ""
echo "========================================="
echo " Results:"
echo "  Successful responses: $SUCCESS / $TOTAL"
echo "========================================="

if [ $SUCCESS -ge 8 ]; then
  echo "✅ Fallback works — traffic routed to v2"
else
  echo "❌ Fallback not working"
fi

echo ""
echo "▶️  Восстанавливаем v1 (1 реплика)..."
kubectl scale deployment booking-service-v1 --replicas=1 2>/dev/null || echo "  Could not restore v1"

echo "  Ожидание запуска v1..."
kubectl rollout status deployment/booking-service-v1 --timeout=60s 2>/dev/null || true

echo ""
echo "========================================="
echo " Fallback Test Complete"
echo "========================================="