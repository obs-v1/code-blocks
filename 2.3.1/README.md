# 2.3.1 — Set up Jaeger, then take your first look at a real trace

The bankobs fleet is **already instrumented** — every service emits spans and tries to
export them over OTLP. What has been missing is the **backend** that collects and shows
them. This folder stands up **Jaeger all-in-one** in the `observability` namespace — the
exact address the fleet exports to and the Grafana datasource (`1.5.1`) already points at
(`jaeger-query.observability.svc:16686`) — so the spans finally have somewhere to land.

To make the first look **instant** (no waiting on the fleet, no bankobs wiring to debug),
`make` also **seeds a few sample payment traces** straight into Jaeger. They model exactly
the waterfall the section describes, so the UI has something to show the moment it opens;
the live fleet's own traces land right alongside them.

```
  seed-traces.sh ─OTLP 4318─┐
                            ├─► jaeger-collector ─► Jaeger (all-in-one) ─► jaeger-query :16686 (UI)
  bankobs fleet  ─OTLP 4317─┘      observability ns                        NodePort 31686 -> host :16686
   (already instrumented)
```

## What's here

| File | Purpose |
|------|---------|
| `jaeger.yaml` | Jaeger all-in-one: OTLP in (4317/4318), UI + query API out (NodePort 31686 → `:16686`) |
| `seed-traces.sh` | posts sample traces over OTLP/HTTP: one UPI payment across 5 services, last one an error |
| `Makefile` | `all` (default) / `setup` / `seed` / `verify` / `trace` / `ui` / `clean` |
| `verify.sh` | asks Jaeger's query API which services have reported spans, and checks they're there |

## The sample trace

Each seeded trace is one `POST /api/upi/pay` fanning out across five services — the exact
shape 2.3.1 asks you to read:

```
  gateway-service  SERVER   POST /api/upi/pay        ───────────────────────────  230ms
   └ gateway-service CLIENT  -> upi-service           ──────────────────────────  215ms
      └ upi-service  SERVER  POST /pay                ─────────────────────────   205ms
         ├ upi-service CLIENT -> account-service      ───                          45ms
         │  └ account-service SERVER /debit           ──                           38ms
         │     └ account-service CLIENT -> ledger     ─                            20ms
         │        └ ledger-service SERVER /post       ·                            15ms
         ├ upi-service CLIENT -> payment-gateway            ──────────            150ms  <- the slow bar
         │  └ payment-gateway SERVER /settle                ─────────            142ms
         └ upi-service INTERNAL compute-fee                            ·            6ms
```

The last trace in the batch errors (payment-gateway returns 500) so you also see a red
trace in the list — useful again when sampling comes up in 2.3.9.

## Prereqs

- A Kubernetes cluster (validated on single-node **kind**).
- `kubectl`, plus `jq` + `openssl` for seeding and `make verify`.
- bankobs is **optional** for 2.3.1 — the sample traces stand alone. (It's required once
  you want to see the *live* fleet, and for later sections.)

## Run

```bash
make            # deploy Jaeger into observability AND seed sample traces
make verify     # confirm traces are landing
make ui         # print the Jaeger URL  ->  Service = upi-service  ->  Find Traces
```

Re-seed any time with `make seed` (or `make seed SEED_N=20` for more). To deploy Jaeger
with **no** sample data, use `make setup` on its own.

### `make verify` (what success looks like)

```
== services Jaeger has seen (5) ==
  account-service
  gateway-service
  ledger-service
  payment-gateway
  upi-service
== payment-flow services present: upi-service account-service gateway-service payment-gateway ==

PASS — traces are landing in Jaeger (seeded samples and/or the live bankobs fleet).
```

(With bankobs exporting too, you'll see its other services in the list as well.)

Then `make ui`, open the URL, choose **Service = upi-service → Find Traces → open the
newest row**, and read the waterfall. That picture — one bar per piece of work, stacked
by cause, sized by duration — is the whole of section 2.3.1.

## Seeing the LIVE fleet (not just the samples)

The sample traces always work. To also see bankobs's **own** traces, the fleet must export
to **`jaeger-collector.observability.svc:4317`**. If `make verify` shows only the five
sample services, point the fleet there by setting the standard OTLP env (adjust to how
bankobs is deployed):

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
