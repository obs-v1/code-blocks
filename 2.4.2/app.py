#!/usr/bin/env python3
"""2.4 series — a tiny two-role app that emits ALL THREE signals, so one image
   can demo traces (2.4.5), metrics (2.4.3) and logs (2.4.4) through the Collector.

   service-a (ROLE=frontend)  GET /call   -> starts a span, calls service-b
   service-b (ROLE=backend)   GET /work    -> does "work" in a child span
   /call?fail=1 marks the span ERROR + returns 500 (a visible failure to find).

   Traces + metrics come from AUTO-instrumentation (the image runs under
   `opentelemetry-instrument`, configured entirely by OTEL_* env). Logs are plain
   stdout JSON lines — the Collector's filelog receiver tails them in 2.4.4.
"""
import os, json, logging, sys, time
from flask import Flask, request
import requests
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from opentelemetry.propagate import inject

ROLE = os.environ.get("ROLE", "backend")
BACKEND_URL = os.environ.get("BACKEND_URL", "http://service-b:8080/work")

# one-line JSON logs on stdout, with the active trace_id stamped in (so the
# log line can be correlated to its trace — the point of 2.4.4 + 2.4.6).
def log(msg, **kv):
    span = trace.get_current_span().get_span_context()
    rec = {"ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "service": os.environ.get("OTEL_SERVICE_NAME", ROLE), "msg": msg}
    if span.is_valid:
        rec["trace_id"] = f"{span.trace_id:032x}"
        rec["span_id"] = f"{span.span_id:016x}"
    rec.update(kv)
    print(json.dumps(rec), flush=True)

app = Flask(__name__)
tracer = trace.get_tracer("lab")


@app.get("/work")
def work():
    tp = request.headers.get("traceparent", "<none>")
    with tracer.start_as_current_span("do-backend-work"):
        log("backend received request", traceparent=tp)
        return {"ok": True, "service": "service-b"}


@app.get("/call")
def call():
    with tracer.start_as_current_span("frontend-handle"):
        headers = {}
        inject(headers)                      # write W3C traceparent into the outbound call
        log("frontend calling backend", traceparent=headers.get("traceparent"))
        r = requests.get(BACKEND_URL, headers=headers, timeout=5)
        if request.args.get("fail") == "1":
            span = trace.get_current_span()
            span.set_status(Status(StatusCode.ERROR))
            span.record_exception(RuntimeError("injected failure"))
            log("frontend FAILED (injected)", level="error")
            return {"ok": False, "service": "service-a"}, 500
        return {"ok": True, "service": "service-a", "backend": r.json()}


@app.get("/healthz")
def healthz():
    return {"ok": True}


if __name__ == "__main__":
    logging.getLogger("werkzeug").setLevel(logging.ERROR)   # quiet the access log
    log(f"starting role={ROLE}")
    app.run(host="0.0.0.0", port=8080)
