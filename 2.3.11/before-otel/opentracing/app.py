#!/usr/bin/env python3
"""before-otel / OpenTracing + jaeger-client — the pre-OTel "API standard + vendor tracer".
One tiny app plays FRONTEND or BACKEND by $ROLE, same flow as the OTel lab one level up:
the FRONTEND injects context into the outbound call, the BACKEND extracts it, and one trace
spans both services. Note the header: OpenTracing's jaeger-client propagates `uber-trace-id`
(trace:span:parent:flags) — NOT W3C `traceparent` (2.3.5 legacy formats, live)."""
import os, logging
from flask import Flask, request
import requests
import opentracing
from opentracing.propagation import Format
from jaeger_client import Config

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("svc")
ROLE = os.environ.get("ROLE", "backend")
SERVICE = os.environ.get("SERVICE_NAME", "ot-" + ("frontend" if ROLE == "frontend" else "backend"))
BACKEND_URL = os.environ.get("BACKEND_URL", "http://backend:8080/work")
# jaeger-client (4.8.0) exports only via the UDP AGENT (compact thrift, :6831) — it has no
# HTTP-collector support. The all-in-one Jaeger runs that agent; we point at it here.
AGENT_HOST = os.environ.get("JAEGER_AGENT_HOST", "jaeger-collector.tracing.svc")
AGENT_PORT = int(os.environ.get("JAEGER_AGENT_PORT", "6831"))


def init_tracer(service):
    # const sampler = keep everything; report over UDP to the Jaeger agent at :6831.
    config = Config(
        config={"sampler": {"type": "const", "param": 1},
                "local_agent": {"reporting_host": AGENT_HOST, "reporting_port": AGENT_PORT},
                "reporter_batch_size": 1, "logging": True},
        service_name=service, validate=True,
    )
    return config.initialize_tracer()


tracer = init_tracer(SERVICE)
app = Flask(__name__)


@app.get("/work")
def work():
    # BACKEND: EXTRACT the OpenTracing context the caller injected into the headers
    parent = tracer.extract(Format.HTTP_HEADERS, dict(request.headers))
    log.info(f"backend  RECEIVED uber-trace-id={request.headers.get('uber-trace-id', '<none>')}")
    with tracer.start_active_span("do-backend-work", child_of=parent) as scope:
        tid = f"{scope.span.context.trace_id:032x}"
        return {"ok": True, "service": SERVICE, "trace_id": tid}


@app.get("/call")
def call():
    # FRONTEND: make a child call and INJECT the context into the outgoing request
    with tracer.start_active_span("frontend-handle") as scope:
        headers = {}
        tracer.inject(scope.span.context, Format.HTTP_HEADERS, headers)   # writes uber-trace-id
        log.info(f"frontend SENDING  uber-trace-id={headers.get('uber-trace-id')}")
        r = requests.get(BACKEND_URL, headers=headers, timeout=5)
        tid = f"{scope.span.context.trace_id:032x}"
        return {"ok": True, "service": SERVICE, "trace_id": tid, "backend": r.json()}


@app.get("/healthz")
def healthz():
    return {"ok": True}


if __name__ == "__main__":
    log.info(f"starting role={ROLE} service={SERVICE}  (OpenTracing API + jaeger-client)")
    app.run(host="0.0.0.0", port=8080)
