#!/usr/bin/env python3
"""2.4.8 lab — same two-role app as 2.3, plus a failure path so we can watch
   tail sampling keep the errors. /call?fail=1 marks the trace's span ERROR and
   returns 500; the Collector's tail_sampling policy keeps every such trace."""
import os, logging
from flask import Flask, request
import requests
from opentelemetry import trace
from opentelemetry.trace import Status, StatusCode
from opentelemetry.propagate import inject

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("svc")
ROLE = os.environ.get("ROLE", "backend")
BACKEND_URL = os.environ.get("BACKEND_URL", "http://service-b:8080/work")
app = Flask(__name__)
tracer = trace.get_tracer("lab")

@app.get("/work")
def work():
    # BACKEND: show the traceparent that arrived on the request
    tp = request.headers.get("traceparent", "<none>")
    ctx = trace.get_current_span().get_span_context()
    log.info(f'backend  RECEIVED traceparent={tp}  trace_id={ctx.trace_id:032x}')
    with tracer.start_as_current_span("do-backend-work"):
        return {"ok": True, "service": "service-b", "trace_id": f"{ctx.trace_id:032x}"}

@app.get("/call")
def call():
    # FRONTEND: make a child call and show the traceparent we INJECT into it
    with tracer.start_as_current_span("frontend-handle"):
        headers = {}
        inject(headers)                      # <-- write W3C traceparent into the outgoing request
        ctx = trace.get_current_span().get_span_context()
        log.info(f'frontend SENDING  traceparent={headers.get("traceparent")}  trace_id={ctx.trace_id:032x}')
        r = requests.get(BACKEND_URL, headers=headers, timeout=5)
        if request.args.get("fail") == "1":
            span = trace.get_current_span()
            span.set_status(Status(StatusCode.ERROR))            # trace status -> ERROR
            span.record_exception(RuntimeError("injected failure"))
            return {"ok": False, "service": "service-a", "trace_id": f"{ctx.trace_id:032x}"}, 500
        return {"ok": True, "service": "service-a", "trace_id": f"{ctx.trace_id:032x}",
                "backend": r.json()}

@app.get("/healthz")
def healthz():
    return {"ok": True}

if __name__ == "__main__":
    log.info(f"starting role={ROLE}")
    app.run(host="0.0.0.0", port=8080)
