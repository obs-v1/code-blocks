# 2.4.2 — The OpenTelemetry Collector as a DaemonSet

The Collector is the one piece that sits **between your apps and your backends**. Instead of every
app knowing about Prometheus, Loki and Jaeger, every app sends **OTLP** (one protocol, all three
signals) to a nearby Collector, and the Collector decides where each signal goes. This lab stands up
that Collector as a **DaemonSet** — one agent per node — and proves it is receiving telemetry. The
next three labs (2.4.3 / 2.4.4 / 2.4.5) just swap its exporter to send each signal somewhere real.

```
  service-a ─┐                         ┌─ (2.4.3) metrics → Prometheus
             ├─ OTLP :4317 ─▶ Collector ┼─ (2.4.4) logs    → Loki
  service-b ─┘              (DaemonSet)  └─ (2.4.5) traces  → Jaeger
                                 │
                            here: debug  (just print what arrives)
```

**Why a DaemonSet, not a Deployment?** A node-agent lives next to the pods on its node — the shortest
hop — and it is the only shape that can read **node-local pod log files** (needed in 2.4.4). A
`Service` in front of the agents means apps always reach `otel-collector.otel24.svc:4317` no matter
which node they land on. (This kind cluster has one node, so that's one agent.)

## What's here

| File | Purpose |
|---|---|
| `app.py` + `Dockerfile` | tiny two-role Flask app, auto-instrumented by `opentelemetry-instrument` (emits traces + metrics + stdout logs) |
| `services.yaml` | `service-a` → `service-b`, both exporting OTLP to the Collector, plus a `driver` that loops calls |
| `collector.yaml` | the **Collector DaemonSet** + its config (OTLP in → `debug` out) + a `Service` fronting :4317/:4318 |
| `Makefile` | `make` (build+deploy) · `verify` · `logs` · `destroy` |
| `verify.sh` | reads the Collector's own `:8888` counters to prove telemetry is arriving |

## Run

```bash
make            # build the image, load into kind, deploy the DaemonSet + services
make verify     # prove the Collector received spans + metrics
make logs       # watch the `debug` exporter print each batch it receives
```

## Verify

`verify.sh` reads the Collector's self-telemetry on `:8888` — `otelcol_receiver_accepted_spans` and
`otelcol_receiver_accepted_metric_points`. Both > 0 means the DaemonSet agent is up and the apps
reached it.

## Tear down

```bash
make destroy
```

**Verified 2026-10-19 on kind:** DaemonSet rolled out; after ~20s the Collector reported **340 spans
and 42 metric points accepted** over OTLP → PASS.
