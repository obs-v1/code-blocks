# 2.2.19 — Metrics say WHAT, logs say WHY (a full drilldown)

The capstone of the logging chapter: stand up the whole observability stack over
the live bankobs fleet, break a dependency on purpose, and walk the real incident
path — **see the errors in the metrics, then read the reason in the logs.**

## What `make` does

```bash
make        # 1 Prometheus  2 Grafana  3 Loki  4 Promtail  → then break a dependency
make reset  # heal the fault
make clean  # uninstall the stack (bankobs is left untouched)
```

1. **Prometheus** ([`prometheus-values.yaml`](prometheus-values.yaml)) — like
   1.4.14; scrapes the bankobs pods.
2. **Grafana** ([`grafana-values.yaml`](grafana-values.yaml)) — like 1.5.x; both
   **Prometheus and Loki** datasources wired, plus the dashboard.
3. **Loki** ([`loki-values.yaml`](loki-values.yaml)) — single-binary, like 2.2.
4. **Promtail** ([`promtail-values.yaml`](promtail-values.yaml)) — a **per-pod
   parser** keyed on the bankobs `log_format` label: `{log_format="json"}` gets
   one JSON stage (49 services), `{log_format="raw"}` gets a regex branch (12
   legacy loggers). No per-line guessing.
5. **Break a dependency** — stops `account-service` (via the fault-injector's k8s
   API). Everything that calls it now fails, and those callers log *why*.

## The demo you run

1. `make` → wait for the stack, then `account-service` is stopped.
2. **Grafana → `Errors: metric → log`** (`make ui` prints the URL, admin/admin).
   Top row (Prometheus) lights up: **5xx rate jumps**, and the *by-service* panel
   names the **callers** — `gateway-service`, `payment-gateway`, `upi-service`.
3. **Scroll to the logs panel** (Loki). The failing payment lines are right there:
   ```
   event: upi-payment-failed
   fail_reason: "debit: Post http://account-service… connection failed"
   amount, correlation_id, debit_account…
   ```
   `fail_reason` names the service that's down. That's the whole lesson: the
   metric pointed at the symptom; the log explained the cause.
4. `make reset` to heal (account-service scales back up).

## Why stop a dependency instead of "injecting a 503"?

A subtle, important point you can teach from this: an app-plane **error** fault
shows up in **metrics and traces but not logs** — the agent returns the 503
without the app logging it, and it only works on Go services anyway. The honest
metric→log story is a **dependency outage**: the broken service can't log
(it's gone), so you diagnose it from its **callers'** error logs. That's how real
incidents are read.

## Requirements & customization

- A cluster **already running bankobs + the dormant fault-injector** Deployment
  (the lab boxes do). This folder deploys only the observability stack, and
  drives the fault straight through the injector's REST API — **no bankobs repo
  needed on the box.**
- Break something else: `make fault FAULT_SVC=fraud-detection` or
  `make fault FAULT_SVC=ledger-service FAULT_DUR=600`.
- Traffic: the lab's loadrunner is already running, so the fleet has live
  requests to fail.

## Validated

Run end-to-end on a live bankobs cluster (2026-10-01): stack came up, Promtail
produced both `log_format=json|raw`, stopping `account-service` spiked 5xx on
`gateway-service` / `payment-gateway` / `upi-service`, and Loki showed
`upi-payment-failed` with `fail_reason` pointing back at account-service. Healed
cleanly with `make reset`.

> Note: the raw-branch regex is generic — it extracts `level` well for Spring /
> log4j lines but mislabels the exotic raw formats (CLF, pipe-delimited, syslog).
> That's expected; add one regex per format as you build the raw-parsing labs.
