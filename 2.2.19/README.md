# 2.2.19 — Metrics say WHAT, logs say WHY (a full drilldown)

The capstone of the logging chapter: stand up the whole observability stack over
the live bankobs fleet, break something on purpose, and walk the real incident
path — **see the error in the metrics, then read the error in the logs.**

## What `make` does

```bash
make        # 1 Prometheus  2 Grafana  3 Loki  4 Promtail  → then inject errors
make reset  # heal the faults
make clean  # uninstall the stack (bankobs is left untouched)
```

1. **Prometheus** ([`prometheus-values.yaml`](prometheus-values.yaml)) — like
   1.4.14; scrapes the bankobs pods.
2. **Grafana** ([`grafana-values.yaml`](grafana-values.yaml)) — like 1.5.x; both
   **Prometheus and Loki** datasources wired, plus the dashboard.
3. **Loki** ([`loki-values.yaml`](loki-values.yaml)) — single-binary, like 2.2.
4. **Promtail** ([`promtail-values.yaml`](promtail-values.yaml)) — a **per-pod
   parser**: it reads the bankobs `log_format` label and branches —
   `{log_format="json"}` gets one JSON stage (49 services), `{log_format="raw"}`
   gets a regex branch (12 legacy loggers). No per-line guessing.
5. **Inject errors** — brings the fault-injector up and fires an error burst at
   `payment-gateway` (Go + JSON, so the error shows in metrics **and** arrives as
   a clean structured log).

## The demo you run

1. `make` → wait for the stack, then the error burst starts.
2. **Grafana → `Errors: metric → log`** (`make ui` prints the URL, admin/admin).
   The top row (Prometheus) lights up: **5xx rate jumps**, and the *by-service*
   panel names `payment-gateway`.
3. **Scroll to the logs panel** (Loki) — the bottom row shows the fleet's
   error lines. Narrow it to `{service="payment-gateway"}` and read the message:
   the injected 503, the trace_id, the correlation_id — the *why* behind the
   spike. That's the whole lesson: the metric pointed, the log explained.
4. `make reset` to heal.

## Requirements & wiring (read before you run)

- A cluster **already running bankobs + the dormant fault-injector** (the lab
  boxes do). This folder deploys only the observability stack.
- The fault/load steps reuse the **bankobs repo's own tooling**. Point
  `BANKOBS_DIR` at it (default `~/claude/observability/bankobserve360`). If the
  repo isn't on the box, run the fault from there by hand — `make` prints the
  exact command (`make eks-fault-up` → `make fault-error S=payment-gateway
  CODE=503 PCT=30`).
- Fault something else: `make fault FAULT_SVC=upi-service FAULT_CODE=500 FAULT_PCT=50`.
- Traffic: the lab's loadrunner is usually already running. If not, `make load`.

> **Not yet live-validated.** The four stack configs follow the proven 1.4.14 /
> 1.5.x / 2.2 patterns and the bankobs `log_format` doc, but the end-to-end wiring
> (Prometheus scraping bankobs, the json/raw branch, the fault trigger on k8s)
> needs one run on a live bankobs box to confirm — names like the
> `fault-injector` Service and the exact error metric may need a small tweak once
> we see the real cluster.
