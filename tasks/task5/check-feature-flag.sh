
#!/bin/bash

set -e

echo "========================================="
echo " Feature Flag Routing Test"
echo "========================================="
echo ""

SERVICE_URL="${SERVICE_URL:-http://booking-service}"
CURL_POD="${CURL_POD:-}"

mesh_curl() {
  if [ -n "$CURL_POD" ]; then
    kubectl exec "$CURL_POD" -c booking-service -- curl -s "$@" 2>/dev/null || echo "ERROR"
  else
    curl -s "$@" 2>/dev/null || echo "ERROR"
  fi
}

echo "▶️  Запрос БЕЗ заголовка X-Feature-Enabled (должен идти на v1):"
RESPONSE_NO_FLAG=$(mesh_curl "$SERVICE_URL/ping")
echo "  Response: $RESPONSE_NO_FLAG"
echo ""

echo "▶️  Запрос С заголовком X-Feature-Enabled: true (должен идти на v2):"
RESPONSE_WITH_FLAG=$(mesh_curl -H "X-Feature-Enabled: true" "$SERVICE_URL/ping")
echo "  Response: $RESPONSE_WITH_FLAG"
echo ""

echo "▶️  Запрос /feature БЕЗ заголовка (v1, feature disabled):"
FEATURE_NO_FLAG=$(mesh_curl "$SERVICE_URL/feature")
echo "  Response: $FEATURE_NO_FLAG"
echo ""

echo "▶️  Запрос /feature С заголовком X-Feature-Enabled: true (v2, feature enabled):"
FEATURE_WITH_FLAG=$(mesh_curl -H "X-Feature-Enabled: true" "$SERVICE_URL/feature")
echo "  Response: $FEATURE_WITH_FLAG"
echo ""

echo "▶️  Запрос /version С заголовком X-Feature-Enabled: true:"
VERSION_RESPONSE=$(mesh_curl -H "X-Feature-Enabled: true" "$SERVICE_URL/version")
echo "  Response: $VERSION_RESPONSE"
echo ""

echo "========================================="
echo " Validation:"
echo "========================================="

PASS=true

if echo "$RESPONSE_NO_FLAG" | grep -q "v1"; then
  echo "✅ Without header → v1 (correct)"
else
  echo "⚠️  Without header → unexpected: $RESPONSE_NO_FLAG"
  PASS=false
fi

if echo "$RESPONSE_WITH_FLAG" | grep -q "v2"; then
  echo "✅ With X-Feature-Enabled: true → v2 (correct)"
else
  echo "⚠️  With header → unexpected: $RESPONSE_WITH_FLAG"
  PASS=false
fi

if echo "$FEATURE_WITH_FLAG" | grep -q "enabled"; then
  echo "✅ Feature endpoint with flag → Feature X enabled (correct)"
else
  echo "⚠️  Feature endpoint with flag → unexpected: $FEATURE_WITH_FLAG"
  PASS=false
fi

echo ""
if [ "$PASS" = true ]; then
  echo "✅ Feature flag routing is working correctly"
else
  echo "⚠️  Some feature flag checks did not pass as expected"
fi

echo ""
echo "========================================="
echo " Feature Flag Test Complete"
echo "========================================="