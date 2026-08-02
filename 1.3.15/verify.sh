#!/usr/bin/env bash
# Cross-check the opt-in annotation demo:
#   the annotated pod IS scraped, the plain pod is NOT.
# Usage: ./verify.sh [PROMETHEUS_URL]   (default http://localhost:9090)
set -euo pipefail
PROM="${1:-http://localhost:9090}"
echo "Prometheus: $PROM"
echo

echo "== active targets from the demo namespace (annotation job) =="
curl -sf "$PROM/api/v1/targets?state=active" \
 | jq -r '.data.activeTargets[]
          | select(.labels.namespace=="demo")
          | "  \(.labels.pod)\t\(.health)\t\(.scrapeUrl)"'
echo

echo "== example-plain among DROPPED targets (discovered, then relabeled away) =="
curl -sf "$PROM/api/v1/targets?state=dropped" \
 | jq -r '[.data.droppedTargets[]?
           | select(.discoveredLabels.__meta_kubernetes_pod_label_app=="example-plain")]
          | "  dropped example-plain endpoints: \(length)"'
echo

echo "== up{namespace=\"demo\"} =="
curl -sf "$PROM/api/v1/query" --data-urlencode 'query=up{namespace="demo"}' \
 | jq -r '.data.result[] | "  \(.metric.pod) = \(.value[1])"'
echo

ann=$(curl -sf "$PROM/api/v1/query" \
      --data-urlencode 'query=up{namespace="demo",pod=~"example-annotated.*"}' \
      | jq -r '.data.result | length')
plain=$(curl -sf "$PROM/api/v1/query" \
      --data-urlencode 'query=up{namespace="demo",pod=~"example-plain.*"}' \
      | jq -r '.data.result | length')

echo "annotated targets scraped: $ann   |   plain targets scraped: $plain"
if [ "$ann" -ge 1 ] && [ "$plain" -eq 0 ]; then
  echo "PASS — only the opted-in pod is scraped."
else
  echo "FAIL — expected annotated>=1 and plain==0."
  exit 1
fi
