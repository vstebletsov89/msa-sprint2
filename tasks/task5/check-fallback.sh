#!/bin/bash

set -e

echo "========================================="
echo " Fallback Route Test"
echo "========================================="
echo ""

SERVICE_URL="${SERVICE_URL:-http://booking-service}"

# используем v2 pod для генерации трафика
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

# -------------------------------------------------------------------
# Step 1: Simulate v1 failure
# -------------------------------------------------------------------

echo "▶️  Масштабируем v1 до 0 реплик (имитация отказа)..."
kubectl scale deployment booking-service-v1 --replicas=0 2>/dev/null || echo "Deployment booking-service-v1 not found"

echo "  Ожидание завершения подов v1..."
kubectl wait --for=delete pod -l app=booking-service,version=v1 --timeout=30s 2>/dev/null || sleep 10

echo ""
echo "▶️  Поды после остановки v1:"
kubectl get pods -l app=booking-service -o wide
echo ""

echo "Waiting 10s for Istio EDS update..."
sleep 10

# -------------------------------------------------------------------
# Step 2: Apply fallback VirtualService
# -------------------------------------------------------------------

echo ""
echo "▶️  Активируем fallback VirtualService (100% traffic → v2)..."

cat <<'VSEOF' | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: booking-service
  namespace: default
spec:
  hosts:
    - booking-service
  http:

    - name: feature-flag-route
      match:
        - headers:
            X-Feature-Enabled:
              exact: "true"
      route:
        - destination:
            host: booking-service
            subset: v2
            port:
              number: 80

    - name: fallback-to-v2
      route:
        - destination:
            host: booking-service
            subset: v2
            port:
              number: 80
          weight: 100
      retries:
        attempts: 3
        perTryTimeout: 5s
        retryOn: "5xx,connect-failure,reset"
VSEOF

echo "Waiting 5s for VirtualService propagation..."
sleep 5

# -------------------------------------------------------------------
# Step 3: Send requests
# -------------------------------------------------------------------

echo ""
echo "▶️  Отправка запросов (ожидаем только pong-v2)..."

SUCCESS=0
TOTAL=10

for i in $(seq 1 $TOTAL); do
  RESPONSE=$(mesh_curl --max-time 5 "$SERVICE_URL/ping")
  echo "  Request $i: $RESPONSE"

  if echo "$RESPONSE" | grep -q "pong from v2"; then
    SUCCESS=$((SUCCESS + 1))
  fi
done

echo ""
echo "========================================="
echo " Results:"
echo "  Successful responses: $SUCCESS / $TOTAL"
echo "========================================="

if [ "$SUCCESS" -eq "$TOTAL" ]; then
  echo "✅ Fallback works — all traffic routed to v2"
else
  echo "❌ Fallback not working"
fi

# -------------------------------------------------------------------
# Step 4: Restore system
# -------------------------------------------------------------------

echo ""
echo "▶️  Восстанавливаем систему..."

echo "Scaling v1 back to 1 replica..."
kubectl scale deployment booking-service-v1 --replicas=1

echo "Waiting for v1 rollout..."
kubectl rollout status deployment/booking-service-v1 --timeout=60s

echo ""
echo "▶️  Восстанавливаем Canary VirtualService (90/10)..."

cat <<'VSEOF' | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: booking-service
  namespace: default
spec:
  hosts:
    - booking-service
  http:

    - name: feature-flag-route
      match:
        - headers:
            X-Feature-Enabled:
              exact: "true"
      route:
        - destination:
            host: booking-service
            subset: v2
            port:
              number: 80

    - name: canary-route
      route:
        - destination:
            host: booking-service
            subset: v1
            port:
              number: 80
          weight: 90
        - destination:
            host: booking-service
            subset: v2
            port:
              number: 80
          weight: 10
      retries:
        attempts: 3
        perTryTimeout: 5s
        retryOn: "5xx,connect-failure,retriable-4xx"
      timeout: 15s
VSEOF

echo ""
echo "========================================="
echo " Fallback Test Complete"
echo "========================================="