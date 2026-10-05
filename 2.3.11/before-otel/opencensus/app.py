#!/usr/bin/env python3
"""before-otel / OpenCensus — Google's pre-OTel "all-in-one library" (API + SDK + exporters).
Same frontend->backend flow. OpenCensus auto-instruments Flask (incoming) and requests
(outgoing) and propagates W3C `traceparent` via TraceContextPropagator — OpenCensus is part
of why that header exists. Spans export to the the lab Jaeger over Thrift/HTTP :14268."""
import os, logging
from flask import Flask, request
import requests
from opencensus.ext.flask.flask_middleware import FlaskMiddleware
from opencensus.ext.jaeger.trace_exporter import JaegerExporter
from opencensus.trace import config_integration
from opencensus.trace.samplers import AlwaysOnSampler
from opencensus.trace.propagation.trace_context_http_header_format import TraceContextPropagator

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("svc")
ROLE = os.environ.get("ROLE", "backend")
SERVICE = os.environ.get("SERVICE_NAME", "oc-" + ("frontend" if ROLE == "frontend" else "backend"))
BACKEND_URL = os.environ.get("BACKEND_URL", "http://backend:8080/work")
JAEGER_HOST = os.environ.get("JAEGER_COLLECTOR_HOST", "jaeger-collector.tracing.svc")
JAEGER_PORT = int(os.environ.get("JAEGER_COLLECTOR_PORT", "14268"))

# the exporter posts Thrift batches to http://<host>:<port>/api/traces (the legacy collector)
exporter = JaegerExporter(service_name=SERVICE, collector_host_name=JAEGER_HOST,
                          collector_port=JAEGER_PORT, collector_endpoint="/api/traces")
# auto-instrument outgoing HTTP so the context rides to the backend
config_integration.trace_integrations(["requests"])

app = Flask(__name__)
# auto-instrument incoming HTTP; extract/propagate context as W3C traceparent
FlaskMiddleware(app, exporter=exporter, sampler=AlwaysOnSampler(), propagator=TraceContextPropagator())


@app.get("/work")
def work():
    # BACKEND: the middleware already extracted the context; show the header that carried it
    log.info(f"backend  RECEIVED traceparent={request.headers.get('traceparent', '<none>')}")
    return {"ok": True, "service": SERVICE}


@app.get("/call")
def call():
    # FRONTEND: the requests integration injects the context into this outgoing call
    r = requests.get(BACKEND_URL, timeout=5)
    log.info("frontend SENDING  (traceparent injected by the requests integration)")
    return {"ok": True, "service": SERVICE, "backend": r.json()}


@app.get("/healthz")
def healthz():
    return {"ok": True}


if __name__ == "__main__":
    log.info(f"starting role={ROLE} service={SERVICE}  (OpenCensus)")
    app.run(host="0.0.0.0", port=8080)
