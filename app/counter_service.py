#!flask/bin/python
import os
import redis
from flask import Flask, request
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST

REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))

r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)

app = Flask(__name__)

http_requests_total = COUNTER("http_requests_total", "Total number of HTTP requests received", ["status", "path", "method"])

@app.after_request
def after_request(response):
    """Increment counter after each request"""
    http_requests_total.labels(
        status=str(response.status_code), path=request.path, method=request.method
    ).inc()
    return response

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

@app.route('/healthz')
def healthz():
    """Liveness check: Is the web server responding?"""
    return "OK", 200

@app.get("/readyz")
def readyz():
    try:
        r.ping()
        return "ready", 200
    except redis.ConnectionError:
        return "not ready", 503

@app.route('/', methods=["POST", "GET"])
def index():
    try:
        if request.method == "POST":
            count = r.incr("counter")
            return "Hmm, Plus 1 please "

        current_count = r.get("counter") or 0
        return str(f"Our counter is: {current_count}")

    except Exception as e:
        return f"Internal server error: {e}\n", 500

if __name__ == '__main__':
    app.run(debug=True,port=8000,host='0.0.0.0')
