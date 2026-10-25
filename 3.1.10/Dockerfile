FROM python:3.11-slim
WORKDIR /app
RUN pip install --no-cache-dir flask==3.0.3 prometheus_client==0.20.0
COPY app.py .
EXPOSE 8080
CMD ["python", "app.py"]
