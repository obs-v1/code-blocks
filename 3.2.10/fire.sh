#!/usr/bin/env bash
# Post ONE firing alert to Alertmanager. Usage: fire.sh <alertname> key=val key=val ...
AM="${AM:-http://localhost:9093}"
NAME="$1"; shift
labels="\"alertname\":\"$NAME\""
for kv in "$@"; do labels="$labels,\"${kv%%=*}\":\"${kv#*=}\""; done
now=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
end=$(date -u -d "+2 hours" +%Y-%m-%dT%H:%M:%S.000Z 2>/dev/null || date -u -v+2H +%Y-%m-%dT%H:%M:%S.000Z)
curl -s -XPOST "$AM/api/v2/alerts" -H 'Content-Type: application/json' \
  -d "[{\"labels\":{$labels},\"annotations\":{\"summary\":\"$NAME (lab)\"},\"startsAt\":\"$now\",\"endsAt\":\"$end\"}]" >/dev/null
echo "  fired: $NAME  ($*)"
