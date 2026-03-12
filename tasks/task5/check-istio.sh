#!/bin/bash

set -e

echo "========================================="
echo " Istio Installation Check"
echo "========================================="

echo ""
echo "▶️  Проверка установки Istio (istio-system pods)..."
kubectl get pods -n istio-system
echo ""

echo "▶️  Проверка Istio инъекции в default namespace..."
INJECTION=$(kubectl get namespace default -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "not set")
echo "istio-injection: $INJECTION"

if [ "$INJECTION" == "enabled" ]; then
  echo "✅ Istio injection is ENABLED in default namespace"
else
  echo "❌ Istio injection is NOT enabled. Run: kubectl label namespace default istio-injection=enabled --overwrite"
fi
echo ""

echo "▶️  Проверка подов booking-service (sidecar-proxy)..."
kubectl get pods -l app=booking-service -o wide
echo ""

echo "▶️  Проверка VirtualService..."
kubectl get virtualservices
echo ""

echo "▶️  Проверка DestinationRule..."
kubectl get destinationrules
echo ""

echo "▶️  Проверка EnvoyFilter..."
kubectl get envoyfilters
echo ""

echo "========================================="
echo " Istio Check Complete"
echo "========================================="