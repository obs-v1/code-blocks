# before-otel / OpenTracing + jaeger-client. These libraries are ARCHIVED (EOL), so we pin
# known-good versions on an older Python. No auto-agent: the app wires the tracer itself.
FROM python:3.9-slim
RUN pip install --no-cache-dir \
    flask==2.2.5 requests==2.31.0 \
    opentracing==2.4.0 jaeger-client==4.8.0 six==1.16.0
COPY app.py /app/app.py
WORKDIR /app
ENTRYPOINT ["python", "app.py"]
