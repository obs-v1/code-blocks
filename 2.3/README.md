# 2.3.10 — Lab: two services, one trace

Two tiny services — `service-a` (frontend) calls `service-b` (backend) — and you
**watch the `traceparent` header cross the wire** between them, then confirm in
Jaeger that both services land in **one** trace. After you have seen the header
move with your own eyes, auto-instrumentation stops being magic you must trust and
becomes a convenience you can debug.

```
  driver ─► service-a ──HTTP (traceparent injected)──► service-b
             │  span                                     │  span
             └──────────── OTLP ──► Jaeger ◄── OTLP ──────┘
                         one trace_id, both services
```

## What's here

| File | Purpose |
|------|---------|
| `app.py` | one app, `ROLE=frontend|backend`; logs the traceparent it **sends** / **receives** |
| `Dockerfile` | Flask + OpenTelemetry, run under `opentelemetry-instrument` |
| `jaeger.yaml` | Jaeger all-in-one (OTLP enabled, UI on NodePort 31686 → host `:16686`) |
| `services.yaml` | service-a, service-b, and a driver that calls the frontend on a loop |
| `verify.sh` / `Makefile` | run + prove propagation |

## Run

```bash
make setup      # build the image, kind-load it, deploy Jaeger + both services
# give it ~30s
make watch      # the payoff — same traceparent on both sides
make verify     # one trace spans BOTH services
```

`make setup` runs on the box (it builds an image and `kind load`s it).

## The payoff (`make watch`)

```
-- frontend SENDING --
frontend SENDING  traceparent=00-334de2ec1972af423106a6dac91eb178-f105199c6da241fc-01
-- backend RECEIVED --
backend  RECEIVED traceparent=00-334de2ec1972af423106a6dac91eb178-bb780144437226c3-01
```

Same **trace id** (`334de2ec…`), different **span id** — the frontend's span is the
parent, the backend starts a child. That one line pair *is* distributed tracing:
identity travelling in a header (2.3.4). Break it — strip the header at the
frontend — and the two halves become two unrelated traces.

## Verify

```
== services Jaeger has seen ==
  service-a
  service-b
== newest service-a trace: which services does it span? ==
  spans:    5
  services: service-a, service-b
PASS — one trace spans service-a AND service-b: traceparent propagated across the wire.
```

Open the waterfall yourself with `make ui` → http://localhost:16686 → search
`service-a`.

## Tear down

```bash
make destroy
```

---

**Verified 2026-08-08** on kind: the frontend's outgoing `traceparent` matched the
backend's incoming one (shared trace id), and Jaeger showed a single 5-span trace
spanning both service-a and service-b.
