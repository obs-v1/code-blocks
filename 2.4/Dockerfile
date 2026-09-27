# 2.4.8 lab — same image as 2.3 (Flask + OpenTelemetry) with the failure path.
FROM python:3.11-slim
RUN pip install --no-cache-dir \
    flask==3.0.3 requests==2.32.3 \
    opentelemetry-distro==0.48b0 \
    opentelemetry-exporter-otlp==1.27.0 \
 && opentelemetry-bootstrap -a install
COPY app.py /app/app.py
WORKDIR /app
ENTRYPOINT ["opentelemetry-instrument", "python", "app.py"]
