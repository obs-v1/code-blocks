# 2.3.10 lab — tiny Flask + OpenTelemetry image, run under the OTel auto-agent
# so the Flask server + outbound requests are instrumented and propagate context.
FROM python:3.11-slim
RUN pip install --no-cache-dir \
    flask==3.0.3 requests==2.32.3 \
    opentelemetry-distro==0.48b0 \
    opentelemetry-exporter-otlp==1.27.0 \
 && opentelemetry-bootstrap -a install
COPY app.py /app/app.py
WORKDIR /app
# opentelemetry-instrument wires the SDK from OTEL_* env at start
ENTRYPOINT ["opentelemetry-instrument", "python", "app.py"]
