from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health() -> None:
    assert client.get("/health").json() == {"status": "ok"}


def test_meta_exposes_lineage() -> None:
    body = client.get("/meta").json()
    assert body["version"] == "0.2.0"
    assert body["lineage"][0] == "source"
    assert body["lineage"][-1] == "insight"
