import pytest
import fakeredis
from unittest.mock import patch
from app.counter_service import app


@pytest.fixture
def client():
    redis_server = fakeredis.FakeServer()
    fake_redis = fakeredis.FakeStrictRedis(server=redis_server, decode_responses=True)

    with patch('app.counter_service.r', fake_redis):
        app.config["TESTING"] = True
        with app.test_client() as client:
            yield client

def test_initial_counter_is_zero(client):
    resp = client.get("/")
    assert resp.status_code == 200
    assert "0" in resp.data.decode()

def test_post_increments_counter(client):
    client.post("/")
    resp = client.get("/")
    assert "1" in resp.data.decode()

def test_readyz_healthy(client):
    resp = client.get("/readyz")
    assert resp.status_code == 200
    assert "ready" in resp.data.decode()
