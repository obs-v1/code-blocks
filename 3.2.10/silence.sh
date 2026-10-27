#!/usr/bin/env bash
# Create a 10-minute silence matching an alertname. Usage: silence.sh <alertname>
AM="${AM:-http://localhost:9093}"
NAME="$1"
start=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
end=$(date -u -d "+10 minutes" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -v+10M +%Y-%m-%dT%H:%M:%S.000Z)
curl -s -XPOST "$AM/api/v2/silences" -H 'Content-Type: application/json' \
  -d "{\"matchers\":[{\"name\":\"alertname\",\"value\":\"$NAME\",\"isRegex\":false,\"isEqual\":true}],\"startsAt\":\"$start\",\"endsAt\":\"$end\",\"createdBy\":\"lab\",\"comment\":\"3.2.7 lab silence\"}" >/dev/null
echo "  silence created for alertname=$NAME (10m, via /api/v2/silences)"
