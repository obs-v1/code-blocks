# 2.4.3 — Metrics → Prometheus

The apps push **OTLP metrics** to the Collector; the Collector forwards them to **Prometheus**.
The twist: Prometheus normally **pulls** (it scrapes `/metrics` endpoints), but here the Collector
**pushes** via remote-write. So the one non-default thing is a flag on Prometheus:
`--web.enable-remote-write-receiver`. The apps never expose a `/metrics` page and Prometheus never
scrapes them — the Collector is the single point that collects and forwards.

```
  service-a ─┐  OTLP metrics   ┌──────────────┐  remote-write   ┌────────────┐
             ├────────────────▶│  Collector   │────────────────▶│ Prometheus │
  service-b ─┘   :4317         │ (DaemonSet)  │  /api/v1/write  └────────────┘
                               └──────────────┘
```

**What you'll see:** `http_server_duration_milliseconds_*`, `http_client_duration_*` and
`http_server_active_requests`, each carrying a `service_name="service-a"` label — added by the
Collector's `resource_to_telemetry_conversion` so you can query per service.

## What's here

| File | Purpose |
|---|---|
| `app.py` + `Dockerfile` | the shared auto-instrumented Flask app (here: `OTEL_METRICS_EXPORTER=otlp`) |
| `services.yaml` | the two services + a driver, pushing OTLP metrics to the Collector |
| `collector.yaml` | Collector DaemonSet: `otlp` in → `prometheusremotewrite` out |
| `prometheus.yaml` | a minimal Prometheus started with `--web.enable-remote-write-receiver` |
| `Makefile` / `verify.sh` | `make` · `verify` · `ui` · `destroy` |

## Run

```bash
make            # build + deploy Prometheus + Collector + services
make verify     # prove the metrics reached Prometheus (retries ~40s while they populate)
make ui         # Prometheus at http://localhost:9090 — try  {service_name="service-a"}
```

## Verify

`verify.sh` asks Prometheus how many series carry `service_name="service-a"` and `"service-b"`.
Both > 0 means metrics flowed app → Collector → Prometheus with no app-side scrape.

## Tear down

```bash
make destroy
```

**Verified 2026-10-19 on kind:** Collector reported `sent_metric_points=15, send_failed=0`; Prometheus
held **58 series** (service-a 37, service-b 19) including `http_server_duration_milliseconds` → PASS.
