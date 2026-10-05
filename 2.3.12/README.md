# 2.3.12 — Jaeger's production architecture (Helm + Elasticsearch)

The 2.3.1 "first look" used Jaeger **all-in-one** — collector, query, UI and storage fused into
one in-memory binary. That hides the very thing this section is about. Here you deploy the
**real topology** with Helm: a separate **collector**, a separate **query** service, and
durable **Elasticsearch** storage — so you can *see* the pieces, and which one owns which
symptom.

```
  bankobs fleet ─OTLP 4317─► jaeger-collector ─► Elasticsearch ◄─ jaeger-query ─► UI (:16686)
                              (ingest)            (storage)        (read)
```

Map it to the section:
- **collector** ingests spans (`jaeger-collector` pod). *Spans missing? → look here.*
- **Elasticsearch** holds them (`elasticsearch` pod). *Queries slow, or retention? → storage.*
- **query** reads them back + renders the UI (`jaeger-query` pod).

This **replaces the 2.3.1 all-in-one** (same `monitoring` namespace, same `:16686`). Tear that
down first (`cd ../2.3.1 && make clean`) if it's running.

## Prereqs

- A Kubernetes cluster (validated on single-node **kind**), `kubectl`, `helm`, `jq`.
- **bankobs deployed** (you deploy it separately). Note the fleet ships **dark** and exports to
  an `otel-collector`, not here — see **Getting bankobs's traces in here** below for the two
  steps to make your project's traces appear.

## Run

```bash
make            # single-node Elasticsearch, then the Jaeger Helm chart pointed at it
make verify     # the component pods (collector / query / ES) + services the fleet has sent
make ui         # the query UI  ->  http://<box-ip>:16686
```

Open the UI and pick a bankobs service (e.g. `upi-service` / `gateway-service`) → **Find Traces**
→ your payment journey across the fleet, now served by a production collector→ES→query pipeline.

## Why this shape

- **Jaeger via Helm, ES as a small manifest.** The Jaeger chart *can* provision Elasticsearch,
  but its bundled ES is the **Bitnami** subchart, whose free images stopped being reliably
  pullable in 2025. So `es.yaml` runs a controlled **single-node** ES (official image) and the
  chart (`provisionDataStore.elasticsearch: false`, `storage.type: elasticsearch`) points at it.
- **Jaeger v1 chart (`3.4.1`)** to match the classic collector/query architecture this section
  teaches (and the 1.x all-in-one used elsewhere). The v2 chart (app 2.x) is an OTel-Collector
  rewrite — a different shape.
- **Agent disabled** — the fleet sends OTLP straight to the collector, so the per-node agent
  isn't needed.

## Lab sizing vs production

This is **lab** sizing: one ES node, `-Xms512m -Xmx512m` heap, no replication, security off.
Production is the opposite and is the section's budget point: **3+ ES data nodes**, large heaps,
`replication_factor`, index lifecycle / retention, and TLS + auth. Bump `ES_JAVA_OPTS` and add
nodes in `es.yaml` (or switch to a managed ES / the ECK operator) for anything real.

## Clean up

```bash
make clean      # helm uninstall jaeger + remove Elasticsearch
```

## Getting bankobs's traces in here

The fleet does **not** export to this Jaeger directly. Each bankobs service exports OTLP to an
**OTel Collector** in the `bankobs` namespace (the 2.4 material), and that Collector forwards
traces to a service it knows only as **`jaeger`** (`jaeger.bankobs.svc:4317`). The whole fleet
also ships **"dark"** by default (`OTEL_SDK_DISABLED=true`, `OBSERVABILITY_MODE=dark`). So two
things have to happen for your project to appear — and one command does both:

```bash
make connect-bankobs
```

It does:
1. **Re-points the backend with one line of DNS.** `alias.yaml` makes `jaeger` in the `bankobs`
   namespace an **ExternalName** alias for *this* section's `jaeger-collector.monitoring.svc`.
   The Collector's unchanged `jaeger:4317` export now lands in the Helm+Elasticsearch Jaeger —
   no Collector reconfig, no re-pointing the 62 services. (If the obs stack's all-in-one Jaeger
   still owns the name, the target steps it aside first — it also clashes on NodePort `31686`.)
2. **Lights the fleet** (dark → full) so the services actually emit spans
   (`kubectl set env deployment -l domain OBSERVABILITY_MODE=full OTEL_SDK_DISABLED=false …`).

With the bankobs load generator running, `make verify` then lists your services within ~1-2 min.
Until `connect-bankobs` is run, `make verify` correctly shows **no services** — the backend is
healthy and waiting.

> **Prereq:** the bankobs OTel Collector must be deployed (it is, once you've run the course's
> obs stack / `make obs-on`). This section replaces the all-in-one *Jaeger* behind it; it does
> not replace the Collector.

## Status

> **Validated end-to-end on kind (2026-10-06).** `make` brings up Elasticsearch + the Jaeger
> collector and query pods (all Running), the collector exposes OTLP on 4317/4318, and the query
> UI serves at `:16686`. `make connect-bankobs` then routes the lit bankobs fleet in: **37
> services registered** in this Jaeger, and a real UPI journey showed as a **27-span trace**
> across `gateway-service → payment-gateway → upi-service → fraud-detection →
> notification-orchestrator` — served by the production collector→ES→query pipeline.
> Fixes applied during validation: the chart already sets `COLLECTOR_OTLP_ENABLED`
> (don't duplicate it in `extraEnv`), and the query **service port is `80`** (port-forward
> `16686:80`).
