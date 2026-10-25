#!/usr/bin/env python3
"""
A tiny request-driven service for the SLO lab (3.1.10).

It does three things:
  • serves /work, which returns 200 normally and 500 at a tunable error rate,
  • exposes native Prometheus metrics at /metrics (http_requests_total{code,...}),
  • drives steady traffic against itself in a background thread, so there is a
    continuous stream of requests for Prometheus to scrape and Pyrra to turn into
    an error budget — no separate load generator to run.

`make fault` flips the error rate up by POSTing /admin/error-rate; that is the
whole incident. The SLI the SLO is built on is simply: non-5xx ÷ all requests.
"""
import os, time, random, threading, urllib.request
from flask import Flask, request, jsonify, Response
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

REQS = Counter("http_requests_total", "Total HTTP requests", ["method", "path", "code"])
DUR  = Histogram("http_request_duration_seconds", "Request latency", ["path"],
                 buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0))

# Mutable at runtime via /admin/error-rate (so `make fault` needs no restart).
_state = {"error_rate": float(os.getenv("ERROR_RATE", "0"))}

@app.route("/work")
def work():
    with DUR.labels("/work").time():
        time.sleep(random.uniform(0.005, 0.04))         # a little realistic latency
        failed = random.random() < _state["error_rate"]
        code = 500 if failed else 200
    REQS.labels("GET", "/work", str(code)).inc()
    return ("server_error\n" if failed else "ok\n"), code

@app.route("/admin/error-rate", methods=["GET", "POST"])
def error_rate():
    if request.method == "POST":
        _state["error_rate"] = max(0.0, min(1.0, float(request.args.get("rate", "0"))))
    return jsonify(error_rate=_state["error_rate"])

@app.route("/healthz")
def healthz():
    return "ok\n", 200

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

def _self_load():
    """~20 req/s against our own /work, so the SLI always has fresh data."""
    time.sleep(3)
    while True:
        try:
            urllib.request.urlopen("http://localhost:8080/work", timeout=2).read()
        except Exception:
            pass
        time.sleep(0.05)

if __name__ == "__main__":
    threading.Thread(target=_self_load, daemon=True).start()
    app.run(host="0.0.0.0", port=8080, threaded=True)
