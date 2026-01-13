#!flask/bin/python
import os
from flask import Flask, request, request_started

COUNTER_FILE = os.getenv("COUNTER_FILE", "data/counter.txt")

def load_counter():
    try:
        with open(COUNTER_FILE, 'r') as f:
            content = f.read()
            return int(content) if content else 0
    except Exception as e:
        print(f"Failed to load counter: {e}")
        return 0

def save_counter(value):
    try:
        with open(COUNTER_FILE, 'w') as f:
            f.write(str(value))
    except Exception as e:
        print(f"Failed to save counter: {e}")
        raise


app = Flask(__name__)

counter = load_counter()

@app.route("/metrics")
def metrics():
    return f"request_counter_total {counter}\n", 200, {'Content-Type': 'text/plain'}

@app.route('/healthz')
def healthz():
    """Liveness check: Is the web server responding?"""
    return "OK", 200

@app.get("/readyz")
def readyz():
    try:
        dir_name = os.path.dirname(os.path.abspath(COUNTER_FILE))
        if not os.path.exists(dir_name):
            return "NOT READY: Directory does not exist\n", 503
        if not os.access(dir_name, os.W_OK):
            return "NOT READY: Directory not writable\n", 503

        return "READY\n", 200
    except Exception as e:
        return f"NOT READY: {str(e)}\n", 503 

@app.route('/', methods=["POST", "GET"])
def index():

    global counter

    try:
        if request.method == "POST":
            counter+=1
            save_counter(counter)
            return "Hmm, Plus 1 please "

        else:
            return str(f"Our counter is: {counter} ")

    except Exception as e:
        return f"Internal server error: {e}\n", 500

if __name__ == '__main__':
    app.run(debug=True,port=8000,host='0.0.0.0')
