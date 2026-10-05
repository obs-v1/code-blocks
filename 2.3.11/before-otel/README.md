# Before OpenTelemetry — the same trace, the old ways

OpenTelemetry wasn't first. It's the **unification** of the two libraries that came before
it. This folder shows the *same* two-service flow as the OTel lab one level up
(`code-blocks/2.3.11`), built the pre-OTel ways — so students see the evolution, and *why* OTel
exists, with their own eyes.

## The timeline

| Year | What | Why it matters |
|------|------|----------------|
| 2010 | Google **Dapper** paper | the concept of distributed tracing |
| 2012 | **Zipkin** (Twitter) | first popular OSS tracer; introduced the **B3** headers |
| 2016 | **OpenTracing** (CNCF) | a vendor-neutral **API only** — you brought your own tracer (Jaeger/Zipkin) |
| 2018 | **OpenCensus** (Google) | a library: **API + SDK + exporters**, traces *and* metrics |
| **2019** | **OpenTelemetry** | **OpenTracing + OpenCensus merged** into one standard |

Two competing standards (an API-only one and an all-in-one one) joined forces. That merger is
*why* OTel has an explicit **API-vs-SDK split** (2.4.1) and **pluggable propagators** (2.3.5) —
it inherited both worlds.

## The three apps (same flow, different library)

| Folder | Library | Era | Propagation header | Status |
|--------|---------|-----|--------------------|--------|
| [`opentracing/`](opentracing/) | OpenTracing API + **jaeger-client** | API standard + vendor tracer | **`uber-trace-id`** | archived |
| [`opencensus/`](opencensus/) | **OpenCensus** (+ Jaeger exporter) | Google's all-in-one | `traceparent` (W3C) | archived |
| `../` (parent) | **OpenTelemetry** | the merger, today | `traceparent` (W3C) | current |

Each is the identical `frontend -> backend` request, producing **one trace that spans both
services** — just with a different library doing the work. The headers are the tell:
jaeger-client still speaks the **legacy `uber-trace-id`** (connect this to the B3/legacy-format
lesson in 2.3.5); OpenCensus already speaks **W3C `traceparent`** (it helped shape that spec).

## Run

Both apps report to **one shared legacy Jaeger** (Thrift over HTTP on `:14268`, UI on NodePort
`31687`), so you see **both in a single UI**. Easiest — bring up both at once from *this*
folder:

```bash
make          # legacy Jaeger + BOTH apps, one clean wipe, then a burst of traffic
make verify   # PASS for both
make ui       # the shared Jaeger (http://<box-ip>:31687)
make traffic  # re-send a burst any time (there is no standing driver pod)
```

> Lightweight by design: the apps have **no standing driver pod** — `make` sends a burst of
> requests once (via a port-forward), and `make traffic` re-sends on demand. That keeps the
> footprint to 4 app pods + 1 Jaeger, which matters on a packed single-node cluster.

The Service dropdown then lists `ot-frontend` / `ot-backend` **and** `oc-frontend` /
`oc-backend`; the **System Architecture** tab shows both `frontend -> backend` pairs. Open an
`ot-*` span (header `uber-trace-id`) next to an `oc-*` span (header `traceparent`) for the
legacy-vs-modern contrast.

Or run just one era from its subfolder (`opentracing/` or `opencensus/`): `make` /
`make watch` / `make verify` / `make ui`. Then open the OTel lab in `../` for the "…and now we
have OpenTelemetry" version — same shape, one standard, any backend.

## Honest note: these libraries are EOL

`jaeger-client`, `opentracing`, and the `opencensus-ext-*` packages are **archived**. They are
pinned to known-good versions on `python:3.9-slim`, and use the Thrift **HTTP** collector
(`:14268`, not UDP) for reliability in kind. If a transitive dependency shifts and a build
fails, the **source code is still the lesson** — adjust the pin in that folder's `Dockerfile`.
In production you would not reach for these today; you'd use OpenTelemetry. That's the point.
