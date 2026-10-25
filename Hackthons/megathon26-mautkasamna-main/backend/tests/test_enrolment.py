"""Codes, registration idempotency, tokens, unlinking."""

import secrets

from app.config import Settings
from app.main import create_app
from fastapi.testclient import TestClient

from .conftest import bearer, register


def test_valid_code_identifies_ngo_and_centre(client):
    res = client.post("/api/v1/enrolment/validate", json={"code": " ngo-hyd-001 "})
    assert res.status_code == 200
    body = res.json()
    assert body["ngo"] == {"id": "ngo_green_futures", "name": "Green Futures Foundation"}
    assert body["centre"]["name"] == "Ameerpet Learning Centre"
    assert body["code"] == "NGO-HYD-001"


def test_unknown_code_is_404_with_structured_error(client):
    res = client.post("/api/v1/enrolment/validate", json={"code": "NGO-XXX-999"})
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "code_not_found"


def test_revoked_code_is_410(client):
    res = client.post("/api/v1/enrolment/validate", json={"code": "NGO-HYD-000"})
    assert res.status_code == 410
    assert res.json()["error"]["code"] == "code_revoked"
    reg = client.post("/api/v1/students/register",
                      json={"code": "NGO-HYD-000", "registration_key": secrets.token_hex(16)})
    assert reg.status_code == 410


def test_registration_returns_random_id_and_separate_token(client):
    body = register(client)
    assert body["student_id"].startswith("STU-")
    assert body["token"].startswith("gst_")
    assert body["student_id"] not in body["token"]
    assert body["ngo"]["id"] == "ngo_green_futures"
    assert body["centre"]["id"] == "ctr_gff_ameerpet"
    assert body["replayed"] is False


def test_retried_registration_returns_same_student_and_rotates_token(client):
    key = secrets.token_hex(16)
    first = client.post("/api/v1/students/register", json={"code": "NGO-HYD-001", "registration_key": key})
    again = client.post("/api/v1/students/register", json={"code": "NGO-HYD-001", "registration_key": key})
    assert first.status_code == 201 and again.status_code == 200
    assert again.json()["replayed"] is True
    assert first.json()["student_id"] == again.json()["student_id"]
    # Only one student exists; the lost first token no longer works.
    assert client.get("/api/v1/diagnostics").json()["counts"]["student"] == 1
    assert client.get("/api/v1/students/me", headers=bearer(first.json()["token"])).status_code == 401
    assert client.get("/api/v1/students/me", headers=bearer(again.json()["token"])).status_code == 200


def test_registration_key_cannot_switch_ngo(client):
    key = secrets.token_hex(16)
    register(client, "NGO-HYD-001", key)
    res = client.post("/api/v1/students/register", json={"code": "NGO-VJA-001", "registration_key": key})
    assert res.status_code == 409


def test_students_in_different_ngos(client):
    a = register(client, "NGO-HYD-001")
    b = register(client, "NGO-WGL-001")
    c = register(client, "NGO-VJA-001")
    assert {a["ngo"]["id"], b["ngo"]["id"], c["ngo"]["id"]} == {"ngo_green_futures", "ngo_udaan", "ngo_youth_finance"}
    assert len({a["student_id"], b["student_id"], c["student_id"]}) == 3
    me = client.get("/api/v1/students/me", headers=bearer(b["token"])).json()
    assert me["ngo"]["name"] == "Udaan Learning Trust"


def test_missing_bad_and_revoked_tokens_are_401(client, settings):
    assert client.get("/api/v1/students/me").json()["error"]["code"] == "token_missing"
    assert client.get("/api/v1/students/me", headers=bearer("gst_nope")).json()["error"]["code"] == "token_invalid"
    s = register(client)
    from app.admin import main as admin
    import os
    os.environ["GULLAK_DB_PATH"] = settings.db_path
    os.environ["DATABASE_URL"] = settings.database_url
    os.environ["GULLAK_ENV"] = "test"
    try:
        assert admin(["revoke-student", s["student_id"]]) == 0
    finally:
        for k in ("GULLAK_DB_PATH", "DATABASE_URL", "GULLAK_ENV"):
            os.environ.pop(k)
    res = client.get("/api/v1/students/me", headers=bearer(s["token"]))
    assert res.status_code == 401
    assert res.json()["error"]["code"] == "token_revoked"


def test_unlink_deletes_server_data(client):
    s = register(client)
    res = client.delete("/api/v1/students/me", headers=bearer(s["token"]))
    assert res.status_code == 200
    assert client.get("/api/v1/students/me", headers=bearer(s["token"])).status_code == 401
    assert client.get("/api/v1/diagnostics").json()["counts"]["student"] == 0


def test_unknown_fields_and_bad_keys_rejected(client):
    res = client.post("/api/v1/students/register",
                      json={"code": "NGO-HYD-001", "registration_key": secrets.token_hex(16), "name": "Asha"})
    assert res.status_code == 422
    assert res.json()["error"]["code"] == "invalid_request"
    res = client.post("/api/v1/students/register", json={"code": "NGO-HYD-001", "registration_key": "short"})
    assert res.status_code == 422


def test_rate_limit_on_code_checks(tmp_path):
    app = create_app(Settings(env="test", db_path=str(tmp_path / "r.db"), enrol_rate_per_minute=3))
    with TestClient(app) as c:
        codes = [c.post("/api/v1/enrolment/validate", json={"code": "NGO-XXX-00" + str(i)}).status_code
                 for i in range(4)]
    assert codes == [404, 404, 404, 429]


def test_body_size_limit(client):
    res = client.post("/api/v1/enrolment/validate", content=b'{"code":"' + b"A" * 20000 + b'"}',
                      headers={"Content-Type": "application/json"})
    assert res.status_code == 413
    assert res.json()["error"]["code"] == "payload_too_large"


def test_health(client):
    body = client.get("/api/v1/health").json()
    assert body["status"] == "ok" and body["schema_version"] == 1
