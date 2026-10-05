# OpenTracing + jaeger-client — the "API standard + vendor tracer" era

**OpenTracing** (2016, CNCF) was a vendor-neutral **API specification** — it defined how you
*wrote* instrumentation (`tracer.inject`, `tracer.extract`, `start_active_span`), but shipped
**no tracer of its own**. You paired it with an implementation; here that's Uber's
**jaeger-client**. This is the direct ancestor of the OTel lab in `../`.

```
frontend (ot-frontend)  --HTTP + uber-trace-id-->  backend (ot-backend)
   start_active_span                                   extract(HTTP_HEADERS)
   inject(HTTP_HEADERS)                                start_active_span(child_of=...)
          └──────────── both report to the lab Jaeger agent (:6831) ───────────┘
                         one trace_id, two services
```

## What to show students

- **`app.py`** — the OpenTracing API, by hand: `init_tracer()` builds a jaeger-client tracer;
  `/call` does `tracer.inject(..., Format.HTTP_HEADERS, headers)`; `/work` does
  `tracer.extract(...)` and starts a child span. Compare to the OTel app in `../app.py`: the
  shapes are similar, but the API is a *different library*.
- **The header.** `make watch` shows **`uber-trace-id=<trace>:<span>:<parent>:<flags>`** — the
  **legacy format**, not W3C `traceparent`. This is exactly the kind of mismatch the 2.3.5
  demo is about.
- **It's archived.** `jaeger-client` and `opentracing` are EOL (pinned here on Python 3.9).
  Nobody starts here today — they start with OpenTelemetry, which absorbed OpenTracing's API.

## Run

```bash
make            # build trace-ot:1.0, deploy to the lab Jaeger + ot-frontend/ot-backend
make watch      # same uber-trace-id leaves the frontend, arrives at the backend
make verify     # PASS: one trace spans ot-frontend AND ot-backend
make ui         # the shared Jaeger :16686 (search Service=ot-frontend)
make destroy    # remove this app (shared Jaeger stays)
```

See `../README.md` for the full evolution and the OpenCensus sibling.
