# 2.3.1 — Set up Jaeger, then take your first look at a real trace

The bankobs fleet is **already instrumented** — every service emits spans and tries to
export them over OTLP. What has been missing is the **backend** that collects and shows
them. This folder stands up **Jaeger all-in-one** in the `observability` namespace — the
exact address the fleet exports to and the Grafana datasource (`1.5.1`) already points at
(`jaeger-query.observability.svc:16686`) — so the spans finally have somewhere to land.

```
  bankobs fleet ──OTLP 4317──► jaeger-collector ─► Jaeger (all-in-one) ─► jaeger-query :16686 (UI)
   (already                       observability ns                         NodePort 31686 -> host :16686
    instrumented)
```

## What's here

| File | Purpose |
|------|---------|
| `jaeger.yaml` | Jaeger all-in-one: OTLP in (4317/4318), UI + query API out (NodePort 31686 → `:16686`) |
| `Makefile` | `setup` / `verify` / `trace` / `ui` / `clean` |
| `verify.sh` | asks Jaeger's query API which services have reported spans, and checks the fleet is there |

## Prereqs

- A Kubernetes cluster (validated on single-node **kind**) already running **bankobs**.
- `kubectl`, and `jq` for `make verify`.

## Run

```bash
make            # deploy Jaeger into the observability namespace
# give it ~30s for the first spans to arrive
make verify     # confirm the live fleet is landing traces
make ui         # print the Jaeger URL  ->  pick a Service  ->  Find Traces
```

### `make verify` (what success looks like)

```
== services Jaeger has seen (11) ==
  account-service
  gateway-service
  payment-gateway
  upi-service
  ...
== bankobs services present: upi-service account-service gateway-service payment-gateway ==

PASS — the live bankobs fleet is exporting traces into Jaeger. Open the UI and look.
```

Then `make ui`, open the URL, choose **Service = upi-service → Find Traces → open the
newest row**, and read the waterfall. That picture — one bar per piece of work, stacked
by cause, sized by duration — is the whole of section 2.3.1.

## Nothing showing up?

Jaeger is up but `make verify` finds no spans → the fleet isn't reaching this collector.
bankobs should export to **`jaeger-collector.observability.svc:4317`**. Point it there by
setting the standard OTLP env on the fleet (adjust to how bankobs is deployed):

```bash
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger-collector.observability.svc:4317
OTEL_EXPORTER_OTLP_PROTOCOL=grpc
```

`make trace` can force one request through the gateway if the fleet is otherwise idle,
but bankobs normally generates its own traffic.

## Notes

- All-in-one uses **in-memory** storage — fine for a first look, lost on restart. Durable
  storage and sampling come later (2.3.9, 2.4).
- NodePort **31686** → host `:16686`. The 2.3.11 lab runs its own Jaeger in the `tracing`
  namespace on the same host port, so run one at a time.

## Tear down

```bash
make clean      # removes Jaeger; bankobs is untouched
```
