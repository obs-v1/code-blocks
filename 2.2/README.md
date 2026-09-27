# 2.2.10 — Lab: Promtail → Loki, with LogQL drills

Builds a complete **Promtail → Loki** pipeline against the live bankobs fleet, then
runs LogQL — and makes the two assertions most courses skip: that **healthchecks
were dropped** and that a **planted password never reached the store**. Proving what
is *absent* from your logs is a real skill, and an empty query result is sometimes
the success condition.

```
  bankobs pods ─┐
                ├─► Promtail ──(parse · drop · scrub · timestamp · promote)──► Loki
  leaky-app ────┘        the four pipeline stages, visible in the config          │
                                                                          LogQL ◄──┘
```

## What's here

| File | Purpose |
|------|---------|
| `loki-values.yaml` | single-binary Loki store (filesystem, no auth) |
| `promtail-values.yaml` | the shipper — **the four pipeline stages are the lesson** |
| `leaky-app.yaml` | a demo app that logs a healthcheck **and** a password on a loop |
| `verify.sh` / `Makefile` | drills + the two absence assertions |

## The pipeline (in `promtail-values.yaml`)

```yaml
pipeline_stages:
  - cri: {}                       # 1 PARSE — unwrap the container format
  - json: { expressions: {...} }  #          then parse the app JSON
  - drop:                         # 2 DROP  — healthcheck noise, fleet-wide
      expression: ".*(/healthz|healthcheck|readiness|liveness).*"
  - replace:                      # 3 SCRUB — mask leaked password/token...
      expression: '(?i)(password|token|secret)["\s:=]+([^\s",}]+)'
      replace: '${1}=***REDACTED***'
  - timestamp: { source: ts, ... }# 4 TIMESTAMP — trust the app clock
  - labels: { level:, service: }  #   PROMOTE — enumerable fields only (never trace_id)
```

## Run

```bash
make setup      # Loki + Promtail + the leaky demo (Prometheus/fleet already running)
# give logs ~30s to land
make verify     # LogQL drills + the two assertions
```

## Verify

```
  bankobs fleet lines (10m):  1979   (should be > 0)
  leaky-app lines (10m):      274    (should be > 0)
  healthz lines in store:     0      (should be 0 — DROPPED)
  'Sup3rSecret' in store:     0      (should be 0 — SCRUBBED)
  'REDACTED' marker present:  99     (should be > 0 — line kept, secret gone)
PASS — logs aggregate to Loki; healthchecks dropped and the password never reached the store.
```

The last three lines are the point: the healthcheck and the raw password are
**absent** by design, while the `REDACTED` marker proves the login line is still
there — just with the secret removed. That is redaction working as a *second layer*
(2.1.8), and drop working as the fleet-wide net (2.1.9).

## Explore LogQL by hand

```bash
make logql      # port-forwards Loki to http://localhost:3100
# then, e.g. (cheapest filters first — 2.2.5):
#   {service="upi-service"} |= "COMPLETED" | json | amount > 10000
#   sum(rate({namespace="bankobs", level="ERROR"}[5m]))     # a metric from logs (2.2.7)
```

## Tear down

```bash
make destroy
```

---

**Verified 2026-08-08** on the live bankobs fleet (kind): Promtail shipped fleet +
demo logs to Loki; a fresh-window check showed **0** healthcheck lines and **0**
occurrences of the planted password, with the `REDACTED` marker present.
