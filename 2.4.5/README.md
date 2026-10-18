# 2.4.5 — Traces → Jaeger

The apps push **OTLP spans** to the Collector; the Collector forwards them to **Jaeger**. Note what
changed from the earlier tracing labs: the apps no longer talk to Jaeger directly — they only know the
Collector. Jaeger lives behind it. Swapping Jaeger for Tempo (or adding a second backend) is now a
one-line change in the Collector config, with **no app change** — that indirection is the whole point
of a Collector.

```
  service-a ─┐   OTLP spans   ┌──────────────┐   OTLP   ┌────────┐
             ├───────────────▶│  Collector   │─────────▶│ Jaeger │
  service-b ─┘    :4317       │ (DaemonSet)  │  :4317   └────────┘
                              └──────────────┘
```

The driver mixes ~90% routine calls with ~10% failures (`/call?fail=1`), so there are **error
traces** (red spans) to find in the UI alongside the routine ones.

## What's here

| File | Purpose |
|---|---|
| `app.py` + `Dockerfile` | the shared auto-instrumented Flask app (here: `OTEL_TRACES_EXPORTER=otlp`) |
| `services.yaml` | the two services + a driver (routine + error mix), exporting OTLP traces to the Collector |
| `collector.yaml` | Collector DaemonSet: `otlp` in → `otlp/jaeger` out |
| `jaeger.yaml` | Jaeger all-in-one (in-memory), OTLP enabled, ClusterIP (coexists with 2.3's `:16686`) |
| `Makefile` / `verify.sh` | `make` · `verify` · `ui` · `destroy` |

## Run

```bash
make            # build + deploy Jaeger + Collector + services
make verify     # prove one trace spans both services (retries on cold start)
make ui         # Jaeger at http://localhost:16686 — open a /call trace, see the service-b child span
```

## Verify

`verify.sh` pulls `service-a` traces from Jaeger and checks at least one also contains a `service-b`
span — proof that context propagated end-to-end and the trace reached Jaeger through the Collector.

## Tear down

```bash
make destroy
```

**Verified 2026-10-19 on kind:** Collector reported `accepted_spans=95, sent_spans{otlp/jaeger}=95,
refused=0`; Jaeger held **50 service-a traces, all 50 spanning service-a → service-b** → PASS.
