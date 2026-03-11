#!/bin/bash
set -Eeuo pipefail

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

RESULTS_DIR="./results"
SERVICE_NAME="booking-service"
IMAGE_NAME="booking-service:latest"
PORT_LOCAL=9090
PORT_SERVICE=80

mkdir -p "$RESULTS_DIR"

# ─────────────────────────────────────────
# COLORS
# ─────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "${BLUE}[$(date +"%H:%M:%S")]${NC} $1"
}

success() {
  echo -e "${GREEN}✔ $1${NC}"
}

warn() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

fail() {
  echo -e "${RED}✖ $1${NC}"
}

# ─────────────────────────────────────────
# ERROR HANDLER
# ─────────────────────────────────────────

on_error() {
  fail "Script failed on line $1"
  echo "Check logs in $RESULTS_DIR"
  [ -n "${PF_PID:-}" ] && kill "$PF_PID" 2>/dev/null || true
}

trap 'on_error $LINENO' ERR

# ─────────────────────────────────────────
# HEADER
# ─────────────────────────────────────────

echo ""
echo "======================================"
echo " Booking Service — Istio Build & Test"
echo " $(date)"
echo "======================================"
echo ""

# ─────────────────────────────────────────
# 1. BUILD DOCKER IMAGE
# ─────────────────────────────────────────

log "Building Docker image..."

{
echo "=== DOCKER BUILD ==="
echo "Timestamp: $(date)"
echo ""

docker build -t $IMAGE_NAME ./booking-service

} 2>&1 | tee "$RESULTS_DIR/build.log"

success "Docker build finished"

# ─────────────────────────────────────────
# 2. LOAD IMAGE INTO MINIKUBE
# ─────────────────────────────────────────

log "Loading image into Minikube..."

{
echo ""
echo "=== MINIKUBE IMAGE LOAD ==="
echo "Timestamp: $(date)"
echo ""

minikube image load $IMAGE_NAME

} >> "$RESULTS_DIR/build.log" 2>&1

success "Image loaded into Minikube"

# ─────────────────────────────────────────
# 3. ENSURE ISTIO INJECTION
# ─────────────────────────────────────────

log "Ensuring Istio injection is enabled..."

kubectl label namespace default istio-injection=enabled --overwrite 2>/dev/null || true

success "Istio injection label applied"

# ─────────────────────────────────────────
# 4. DEPLOY v1 AND v2 WITH HELM
# ─────────────────────────────────────────

log "Deploying v1 with Helm..."

helm upgrade --install booking-service-v1 ./helm/booking-service \
  -f ./helm/booking-service/values-v1.yaml

success "v1 Helm deployment applied"

log "Deploying v2 with Helm..."

helm upgrade --install booking-service-v2 ./helm/booking-service \
  -f ./helm/booking-service/values-v2.yaml

success "v2 Helm deployment applied"

# ─────────────────────────────────────────
# 5. APPLY ISTIO CONFIGS
# ─────────────────────────────────────────

log "Applying Istio configurations..."

kubectl apply -f ./istio/destination-rule.yaml
kubectl apply -f ./istio/virtual-service.yaml
kubectl apply -f ./istio/envoy-filter.yaml

success "Istio configs applied"

# ─────────────────────────────────────────
# 6. WAIT FOR PODS READY
# ─────────────────────────────────────────

log "Waiting for v1 pod readiness..."
kubectl rollout status deployment/booking-service-v1 --timeout=120s

log "Waiting for v2 pod readiness..."
kubectl rollout status deployment/booking-service-v2 --timeout=120s

success "All deployments are ready"

# ─────────────────────────────────────────
# 7. SAVE KUBECTL INFO
# ─────────────────────────────────────────

log "Saving kubectl info..."

{
echo "=== KUBECTL GET PODS ==="
echo "Timestamp: $(date)"
echo ""

kubectl get pods -l app=booking-service -o wide

echo ""
echo "=== KUBECTL GET SERVICES ==="
echo ""

kubectl get svc booking-service

echo ""
echo "=== KUBECTL GET VIRTUALSERVICES ==="
echo ""

kubectl get virtualservices

echo ""
echo "=== KUBECTL GET DESTINATIONRULES ==="
echo ""

kubectl get destinationrules

echo ""
echo "=== KUBECTL GET ENVOYFILTERS ==="
echo ""

kubectl get envoyfilters

} > "$RESULTS_DIR/kubectl.txt"

success "kubectl info saved"

# ─────────────────────────────────────────
# 8. PORT FORWARD
# ─────────────────────────────────────────

log "Starting port-forward..."

kubectl port-forward svc/booking-service $PORT_LOCAL:$PORT_SERVICE \
> /dev/null 2>&1 &

PF_PID=$!

sleep 5

if ! kill -0 "$PF_PID" 2>/dev/null; then
  fail "port-forward process died unexpectedly"
  exit 1
fi

success "Port-forward started (PID=$PF_PID, localhost:$PORT_LOCAL → svc:$PORT_SERVICE)"

export SERVICE_URL="http://localhost:$PORT_LOCAL"

# ─────────────────────────────────────────
# 9. RUN CHECK-ISTIO
# ─────────────────────────────────────────

log "Running check-istio.sh..."

{
echo "=== CHECK ISTIO ==="
echo "Timestamp: $(date)"
echo ""

bash ./check-istio.sh

} > "$RESULTS_DIR/check-istio.txt" 2>&1 || warn "check-istio returned non-zero"

success "check-istio executed"

# ─────────────────────────────────────────
# 10. RUN CHECK-CANARY
# ─────────────────────────────────────────

log "Running check-canary.sh..."

{
echo "=== CHECK CANARY ==="
echo "Timestamp: $(date)"
echo ""

bash ./check-canary.sh

} > "$RESULTS_DIR/check-canary.txt" 2>&1 || warn "check-canary returned non-zero"

success "check-canary executed"

# ─────────────────────────────────────────
# 11. RUN CHECK-FEATURE-FLAG
# ─────────────────────────────────────────

log "Running check-feature-flag.sh..."

{
echo "=== CHECK FEATURE FLAG ==="
echo "Timestamp: $(date)"
echo ""

bash ./check-feature-flag.sh

} > "$RESULTS_DIR/check-feature-flag.txt" 2>&1 || warn "check-feature-flag returned non-zero"

success "check-feature-flag executed"

# ─────────────────────────────────────────
# 12. RUN CHECK-FALLBACK
# ─────────────────────────────────────────

log "Running check-fallback.sh..."

{
echo "=== CHECK FALLBACK ==="
echo "Timestamp: $(date)"
echo ""

bash ./check-fallback.sh

} > "$RESULTS_DIR/check-fallback.txt" 2>&1 || warn "check-fallback returned non-zero"

success "check-fallback executed"

# ─────────────────────────────────────────
# 13. STOP PORT-FORWARD
# ─────────────────────────────────────────

log "Stopping port-forward..."
kill $PF_PID 2>/dev/null || true

# ─────────────────────────────────────────
# 14. COPY ISTIO CONFIGS TO RESULTS
# ─────────────────────────────────────────

log "Copying Istio configs and values to results..."

cp ./istio/virtual-service.yaml "$RESULTS_DIR/"
cp ./istio/destination-rule.yaml "$RESULTS_DIR/"
cp ./istio/envoy-filter.yaml "$RESULTS_DIR/"
cp ./helm/booking-service/values-v1.yaml "$RESULTS_DIR/"
cp ./helm/booking-service/values-v2.yaml "$RESULTS_DIR/"

success "Configs copied to results"

# ─────────────────────────────────────────
# 15. IMAGE LISTS
# ─────────────────────────────────────────

log "Saving image lists..."

{
echo "=== DOCKER IMAGE LS ==="
echo "Timestamp: $(date)"
echo ""

docker image ls | grep booking-service || true

echo ""
echo "=== MINIKUBE IMAGE LIST ==="
echo ""

minikube image list | grep booking-service || true

} > "$RESULTS_DIR/images.txt"

success "Image lists saved"

# ─────────────────────────────────────────
# 16. GENERATE REPORT
# ─────────────────────────────────────────

log "Generating report..."

cat > "$RESULTS_DIR/report.md" << 'REPORT_EOF'
# Task 5 — Istio Service Mesh: Report

## Описание изменений

### 1. Две версии сервиса
- **v1** — основная версия (`ENABLE_FEATURE_X=false`, `SERVICE_VERSION=v1`)
- **v2** — версия с фича-флагами (`ENABLE_FEATURE_X=true`, `SERVICE_VERSION=v2`)

Обе версии деплоятся через Helm с разными `values-v1.yaml` и `values-v2.yaml`.
Deployment-ы имеют label `version: v1` / `version: v2` для маршрутизации Istio.

### 2. Istio-маршрутизация (VirtualService)
- **Канареечный Release**: 90% трафика → v1, 10% → v2
- **Feature-flag routing**: при заголовке `X-Feature-Enabled: true` → 100% на v2
- **Retries**: 3 попытки с timeout 2s на каждую, retry при 5xx/reset/connect-failure

### 3. DestinationRule (Retry + Circuit Breaking)
- **Subsets**: v1 и v2, определённые по label `version`
- **Circuit Breaker (Outlier Detection)**:
  - 3 consecutive 5xx errors → eject хост на 30s
  - Проверка каждые 10s
- **Connection Pool**: ограничения на TCP и HTTP соединения

### 4. EnvoyFilter (Feature Flag)
- Lua-фильтр на sidecar-прокси
- При наличии заголовка `X-Feature-Enabled: true` добавляет `x-route-to: v2`
- Добавляет response header `x-envoy-feature-flag-processed: true`

### 5. Fallback
- При отказе v1 (scale to 0), Circuit Breaker выводит хост из пула
- Istio retries перенаправляют трафик на оставшийся subset (v2)

## Проверочные скрипты
- `check-istio.sh` — проверка установки Istio, injection, конфигов
- `check-canary.sh` — 100 запросов, подсчёт распределения v1/v2
- `check-fallback.sh` — масштабирование v1→0, проверка что v2 отвечает
- `check-feature-flag.sh` — проверка маршрутизации по заголовку

REPORT_EOF

success "Report generated"

# ─────────────────────────────────────────
# 17. SUMMARY
# ─────────────────────────────────────────

echo ""
echo "======================================"
echo " BUILD & TEST COMPLETED"
echo "======================================"
echo ""

ls -lah "$RESULTS_DIR"

echo ""
success "All artifacts saved in $RESULTS_DIR"
echo ""