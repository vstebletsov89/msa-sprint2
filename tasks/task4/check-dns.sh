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