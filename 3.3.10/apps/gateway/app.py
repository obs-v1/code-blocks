"""gateway — the Python entry service in the 3.3.10 four-signal lab.

A request comes in here, we call the Go `worker`, and we emit all four signals:

    traces + metrics + logs  →  OTLP  →  OTel Collector  →  Jaeger / Prometheus / Loki
    CPU profiles             →  pyroscope-io SDK  →  Pyroscope

PyroscopeSpanProcessor tags every span with the profile id, so a slow gateway
span links straight to its flame graph — the trace → code pivot, in Python too.
"""
import logging
import os

import httpx
import pyroscope
from fastapi import FastAPI, Response
from pyroscope.otel import PyroscopeSpanProcessor

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

SERVICE = "gateway"
VERSION = os.getenv("VERSION", "1.0.0")
OTLP = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")
WORKER = os.getenv("WORKER_URL", "http://worker:8080/process")

# One resource = the shared tags (service.name, namespace, version) across signals.
resource = Resource.create({
    "service.name": SERVICE,
    "service.version": VERSION,
    "service.namespace": "monitoring",
    "deployment.environment": "lab",
})

# ── traces (+ Pyroscope span processor for the trace→profile join) ───────────
tp = TracerProvider(resource=resource)
tp.add_span_processor(PyroscopeSpanProcessor())
tp.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=OTLP, insecure=True)))
trace.set_tracer_provider(tp)
tracer = trace.get_tracer(SERVICE)

# ── metrics ──────────────────────────────────────────────────────────────────
reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=OTLP, insecure=True), export_interval_millis=5000)
mp = MeterProvider(resource=resource, metric_readers=[reader])

# ── logs (OTel LoggingHandler stamps code.filepath/lineno → the log→code hop) ─
lp = LoggerProvider(resource=resource)
lp.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter(endpoint=OTLP, insecure=True)))
logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s %(pathname)s:%(lineno)d trace_id=%(otelTraceID)s %(message)s",
)
logging.getLogger().addHandler(LoggingHandler(level=logging.INFO, logger_provider=lp))
log = logging.getLogger(SERVICE)

# ── profiles ─────────────────────────────────────────────────────────────────
pyroscope.configure(
    application_name=SERVICE,
    server_address=os.getenv("PYROSCOPE_SERVER", "http://pyroscope:4040"),
    tags={"namespace": "monitoring", "version": VERSION},
)

app = FastAPI()
FastAPIInstrumentor.instrument_app(app, meter_provider=mp, tracer_provider=tp)
HTTPXClientInstrumentor().instrument()

client = httpx.Client(timeout=10.0)


@app.get("/checkout")
def checkout():
    """One checkout = one call down to the worker. The trace spans both services."""
    with tracer.start_as_current_span("checkout"):
        try:
            r = client.get(WORKER)
            if r.status_code >= 500:
                log.error("checkout failed: worker returned %s", r.status_code)
                return Response(r.text, status_code=502, media_type="application/json")
            log.info("checkout ok")
            return Response(r.text, media_type="application/json")
        except httpx.HTTPError as e:
            log.error("checkout failed: worker unreachable: %s", e)
            return Response('{"error":"worker unreachable"}', status_code=502,
                            media_type="application/json")


@app.get("/healthz")
def healthz():
    return {"status": "ok"}
