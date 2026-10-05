# before-otel / OpenCensus. Archived (EOL) libraries, pinned on an older Python.
FROM python:3.9-slim
RUN pip install --no-cache-dir \
    flask==2.2.5 requests==2.31.0 \
    opencensus==0.11.4 opencensus-ext-jaeger==0.7.1 \
    opencensus-ext-flask==0.8.2 opencensus-ext-requests==0.8.0
COPY app.py /app/app.py
WORKDIR /app
ENTRYPOINT ["python", "app.py"]
