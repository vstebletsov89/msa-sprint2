
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
touch "$RESULTS_DIR/build.log"

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
# CLEAN PREVIOUS HELM RELEASES
# ─────────────────────────────────────────

log "Cleaning previous Helm releases..."

helm uninstall booking-service-v1 2>/dev/null || true
helm uninstall booking-service-v2 2>/dev/null || true
helm uninstall booking-service 2>/dev/null || true

kubectl delete deployment booking-service 2>/dev/null || true
kubectl delete svc booking-service 2>/dev/null || true

sleep 3

success "Previous Helm releases removed"

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
# 2. REMOVE OLD IMAGE FROM MINIKUBE
# ─────────────────────────────────────────

log "Removing old image from Minikube..."

minikube ssh "docker rmi -f $IMAGE_NAME" \
  >> "$RESULTS_DIR/build.log" 2>&1 || true

success "Old image removed (if existed)"

# ─────────────────────────────────────────
# 3. LOAD IMAGE INTO MINIKUBE
# ─────────────────────────────────────────

log "Loading image into Minikube..."

{
echo ""
echo "=== MINIKUBE IMAGE LOAD ==="
echo "Timestamp: $(date)"
echo ""

minikube image load $IMAGE_NAME

} 2>&1 | tee -a "$RESULTS_DIR/build.log"

success "Image loaded into Minikube"

# ─────────────────────────────────────────
# 4. ENSURE ISTIO INJECTION
# ─────────────────────────────────────────

log "Ensuring Istio injection is enabled..."

kubectl label namespace default istio-injection=enabled --overwrite \
  2>/dev/null || true

success "Istio injection label applied"

# ─────────────────────────────────────────
# 5. DEPLOY v1 AND v2 WITH HELM
# ─────────────────────────────────────────

log "Deploying v1 with Helm..."

helm upgrade --install booking-service-v1 ./helm/booking-service \
  -f ./helm/booking-service/values-v1.yaml \
  --wait --timeout 120s

success "v1 Helm deployment applied"

log "Deploying v2 with Helm..."

helm upgrade --install booking-service-v2 ./helm/booking-service \
  -f ./helm/booking-service/values-v2.yaml \
  --wait --timeout 120s

success "v2 Helm deployment applied"

# ─────────────────────────────────────────
# 6. APPLY ISTIO CONFIGS
# ─────────────────────────────────────────

log "Applying Istio configurations..."

kubectl apply -f ./istio/destination-rule.yaml
kubectl apply -f ./istio/virtual-service.yaml
kubectl apply -f ./istio/envoy-filter.yaml

success "Istio configs applied"

# ─────────────────────────────────────────
# 7. WAIT FOR PODS READY
# ─────────────────────────────────────────

log "Waiting for v1 pod readiness..."
kubectl rollout status deployment/booking-service-v1 --timeout=120s

log "Waiting for v2 pod readiness..."
kubectl rollout status deployment/booking-service-v2 --timeout=120s

success "All deployments are ready"

# ─────────────────────────────────────────
# 8. SAVE KUBECTL INFO
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
# 9. PREPARE IN-MESH CURL POD
# ─────────────────────────────────────────

log "Determining curl pod for in-mesh requests..."

# Тесты должны выполняться ИЗНУТРИ mesh, чтобы трафик шёл через Istio sidecar.
# kubectl port-forward обходит Envoy proxy и VirtualService/DestinationRule не работают.
# Поэтому используем kubectl exec в под с sidecar.

CURL_POD=$(kubectl get pods -l app=booking-service,version=v1 -o jsonpath='{.items[0].metadata.name}')
export CURL_POD
export SERVICE_URL="http://booking-service"

success "Will use pod $CURL_POD for in-mesh curl requests"

# Также поднимаем port-forward для check-istio (он не делает curl к сервису)
kubectl port-forward svc/booking-service $PORT_LOCAL:$PORT_SERVICE \
> /dev/null 2>&1 &

PF_PID=$!
sleep 3

# ─────────────────────────────────────────
# 10. RUN CHECKS
# ─────────────────────────────────────────

run_check() {

SCRIPT=$1
OUTFILE=$2

log "Running $SCRIPT..."

{
echo "=== $SCRIPT ==="
echo "Timestamp: $(date)"
echo ""

bash ./$SCRIPT

} > "$RESULTS_DIR/$OUTFILE" 2>&1 || warn "$SCRIPT returned non-zero"

success "$SCRIPT executed"

}

run_check check-istio.sh check-istio.txt
run_check check-canary.sh check-canary.txt
run_check check-feature-flag.sh check-feature-flag.txt
run_check check-fallback.sh check-fallback.txt

# ─────────────────────────────────────────
# 11. STOP PORT-FORWARD
# ─────────────────────────────────────────

log "Stopping port-forward..."
kill $PF_PID 2>/dev/null || true

# ─────────────────────────────────────────
# 12. COPY CONFIGS
# ─────────────────────────────────────────

log "Copying configs..."

cp ./istio/*.yaml "$RESULTS_DIR/" 2>/dev/null || true
cp ./helm/booking-service/values-*.yaml "$RESULTS_DIR/" 2>/dev/null || true

success "Configs copied"

# ─────────────────────────────────────────
# 13. IMAGE LIST
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
# 14. SUMMARY
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