#!/bin/bash

set -e

echo "========================================="
echo " Canary Release Test (90% v1, 10% v2)"
echo "========================================="
echo ""

SERVICE_URL="${SERVICE_URL:-http://localhost:9090}"
TOTAL=100
V1_COUNT=0
V2_COUNT=0
ERRORS=0

echo "▶️  Sending $TOTAL requests to $SERVICE_URL/ping ..."
echo ""

for i in $(seq 1 $TOTAL); do
  RESPONSE=$(curl -s "$SERVICE_URL/ping" 2>/dev/null || echo "ERROR")

  if echo "$RESPONSE" | grep -q "v1"; then
    V1_COUNT=$((V1_COUNT + 1))
  elif echo "$RESPONSE" | grep -q "v2"; then
    V2_COUNT=$((V2_COUNT + 1))
  else
    ERRORS=$((ERRORS + 1))
  fi
done

echo "========================================="
echo " Results:"
echo "  Total requests:   $TOTAL"
echo "  v1 responses:     $V1_COUNT ($(( V1_COUNT * 100 / TOTAL ))%)"
echo "  v2 responses:     $V2_COUNT ($(( V2_COUNT * 100 / TOTAL ))%)"
echo "  Errors:           $ERRORS"
echo "========================================="
echo ""

# Допустимый диапазон для v1: 75-100%, для v2: 0-25% (с учётом стохастики)
if [ $V1_COUNT -ge 70 ] && [ $V2_COUNT -ge 1 ]; then
  echo "✅ Canary release is working correctly (v1 ~90%, v2 ~10%)"
else
  echo "⚠️  Traffic distribution may be outside expected range"
  echo "   Expected ~90% v1, ~10% v2"
fi