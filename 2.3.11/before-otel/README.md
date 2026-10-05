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

Both apps report to the **same Jaeger as the OTel lab** one level up — a Jaeger backend speaks
modern **OTLP** *and* the legacy **UDP agent** (`:6831`), so `service-a`/`service-b` (OTLP) and
`ot-*`/`oc-*` (Thrift) all land in **one UI on `:16686`**. Bring up both at once from *this*
folder:

```bash
make          # ensure the lab Jaeger (with the legacy agent :6831) is up, deploy both apps, send traffic
make verify   # PASS for both
make ui       # the shared Jaeger (http://<box-ip>:16686)
make traffic  # re-send a burst any time (no standing driver pod)
```

> Lightweight by design: **no second Jaeger and no standing driver pod**. `make` applies the
> OTel lab's `../jaeger.yaml` (which now also exposes the legacy agent `:6831`), deploys the
> four app pods, and sends one burst of traffic via a port-forward. Reusing the one Jaeger is
> also why everything is viewable at the single reachable `:16686`.

The Service dropdown then lists `service-a`/`service-b`, `ot-frontend`/`ot-backend` **and**
`oc-frontend`/`oc-backend`; the **System Architecture** tab shows all the `frontend -> backend`
pairs. Open an `ot-*` span (header `uber-trace-id`) next to an `oc-*` span (header `traceparent`)
for the
legacy-vs-modern contrast.

Or run just one era from its subfolder (`opentracing/` or `opencensus/`): `make` /
`make watch` / `make verify` / `make ui`. Then open the OTel lab in `../` for the "…and now we
have OpenTelemetry" version — same shape, one standard, any backend.

## Honest note: these libraries are EOL

`jaeger-client`, `opentracing`, and the `opencensus-ext-*` packages are **archived**. They are
pinned to known-good versions on `python:3.9-slim`, and export over the native **UDP agent**
(`:6831`) these EOL clients default to (jaeger-client 4.8.0 has no HTTP-collector support at
all). If a transitive dependency shifts and a build fails, the **source code is still the
lesson** — adjust the pin in that folder's `Dockerfile`.
In production you would not reach for these today; you'd use OpenTelemetry. That's the point.
