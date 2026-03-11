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
PORT_LOCAL=8080
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
}

trap 'on_error $LINENO' ERR

# ─────────────────────────────────────────
# HEADER
# ─────────────────────────────────────────

echo ""
echo "======================================"
echo " Booking Service — Build & Test"
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
# 3. DEPLOY WITH HELM
# ─────────────────────────────────────────

log "Deploying Helm chart..."

helm upgrade --install $SERVICE_NAME ./helm/booking-service \
  -f ./helm/booking-service/values.yaml

success "Helm deployment applied"


# ─────────────────────────────────────────
# 4. WAIT FOR POD READY
# ─────────────────────────────────────────

log "Waiting for pod readiness..."

kubectl rollout status deployment/$SERVICE_NAME --timeout=120s

success "Deployment is ready"


# ─────────────────────────────────────────
# 5. SAVE KUBECTL INFO
# ─────────────────────────────────────────

log "Saving kubectl info..."

{
echo "=== KUBECTL GET PODS ==="
echo "Timestamp: $(date)"
echo ""

kubectl get pods -o wide

echo ""
echo "=== KUBECTL GET SERVICES ==="
echo ""

kubectl get svc

} > "$RESULTS_DIR/kubectl.txt"

success "kubectl logs saved"


# ─────────────────────────────────────────
# 6. RUN CHECK-STATUS
# ─────────────────────────────────────────

log "Running check-status.sh..."

{
echo "=== CHECK STATUS ==="
echo "Timestamp: $(date)"
echo ""

./check-status.sh

} > "$RESULTS_DIR/check-status.txt" 2>&1 || warn "check-status returned non-zero"

success "check-status executed"


# ─────────────────────────────────────────
# 7. RUN CHECK-DNS
# ─────────────────────────────────────────

log "Running check-dns.sh..."

{
echo "=== CHECK DNS ==="
echo "Timestamp: $(date)"
echo ""

./check-dns.sh

} > "$RESULTS_DIR/check-dns.txt" 2>&1 || warn "check-dns returned non-zero"

success "DNS check executed"


# ─────────────────────────────────────────
# 8. PORT FORWARD
# ─────────────────────────────────────────

log "Starting port-forward..."

kubectl port-forward svc/$SERVICE_NAME $PORT_LOCAL:$PORT_SERVICE \
> /dev/null 2>&1 &

PF_PID=$!

sleep 5


# ─────────────────────────────────────────
# 9. HEALTHCHECK
# ─────────────────────────────────────────

log "Checking /health endpoint..."

HEALTH_URL="http://localhost:$PORT_LOCAL/health"

if curl -sf "$HEALTH_URL" > /dev/null; then
  success "Health endpoint OK"
else
  fail "Health endpoint failed"
fi


# ─────────────────────────────────────────
# 10. CURL /PING
# ─────────────────────────────────────────

log "Testing /ping endpoint..."

{
echo "=== CURL /PING ==="
echo "Timestamp: $(date)"
echo ""

curl -v http://localhost:$PORT_LOCAL/ping

} > "$RESULTS_DIR/curl-ping.txt" 2>&1

success "/ping request saved"


kill $PF_PID || true


# ─────────────────────────────────────────
# 11. IMAGE LISTS
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
# 12. SUMMARY
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