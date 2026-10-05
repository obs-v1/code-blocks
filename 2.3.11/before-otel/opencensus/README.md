# OpenCensus — Google's "all-in-one library" era

**OpenCensus** (2018, Google) was the other pre-OTel option. Unlike OpenTracing (an API
only), OpenCensus bundled the **API + SDK + exporters** in one library, for **traces and
metrics**. Its auto-instrumentation for frameworks is the ancestor of OTel's. Here it exports
traces to the shared legacy Jaeger.

```
frontend (oc-frontend)  --HTTP + traceparent-->  backend (oc-backend)
   FlaskMiddleware (span)                            FlaskMiddleware (extract -> child)
   requests integration (inject)
          └──────────── both report to legacy Jaeger (:14268) ───────────┘
                         one trace_id, two services
```

## What to show students

- **`app.py`** — almost no manual tracing code: `FlaskMiddleware(...)` auto-instruments
  incoming requests, `config_integration.trace_integrations(["requests"])` auto-instruments
  outgoing ones, and `JaegerExporter(...)` ships the spans. This "batteries-included" style is
  what OTel's auto-instrumentation inherited.
- **The header.** OpenCensus propagates **W3C `traceparent`** (via `TraceContextPropagator`) —
  OpenCensus helped shape that spec, so unlike the jaeger-client sibling, the header already
  looks modern. A nice contrast to show next to `../opentracing` (`uber-trace-id`).
- **It's archived.** The `opencensus-ext-*` packages are EOL (pinned here on Python 3.9). The
  project folded into OpenTelemetry.

## Run

```bash
make            # build trace-oc:1.0, deploy legacy Jaeger + oc-frontend/oc-backend, wipe
make watch      # context leaves the frontend, arrives at the backend
make verify     # PASS: one trace spans oc-frontend AND oc-backend
make ui         # legacy Jaeger (search Service=oc-frontend)
make destroy    # remove this app (shared legacy Jaeger stays)
```

See `../README.md` for the full evolution and the OpenTracing sibling.
