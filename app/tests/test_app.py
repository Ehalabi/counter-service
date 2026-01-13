import pytest
import tempfile
import os

@pytest.fixture
def client():
    with tempfile.NamedTemporaryFile() as f:
        os.environ["COUNTER_FILE"] = f.name

        from app.counter_service import app

        app.config["TESTING"] = True

        with app.test_client() as client:
            yield client

def test_initial_counter_is_zero(client):
    resp = client.get("/")
    assert resp.status_code == 200
    print(resp.data.decode())
    assert "0" in resp.data.decode()

def test_post_increments_counter(client):
    client.post("/")
    resp = client.get("/")
    print(resp.data.decode())
    assert "1" in resp.data.decode()
