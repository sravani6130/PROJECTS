"""Progress uploads: ownership, idempotency, ordering, validation."""

from .conftest import bearer, login, register, report, GREEN


def upload(client, s, body):
    return client.post("/api/v1/progress", json=body, headers=bearer(s["token"]))


def test_accepts_newer_revision_and_updates_current(client):
    s = register(client)
    assert upload(client, s, report(s["student_id"], 1)).json()["status"] == "accepted"
    res = upload(client, s, report(s["student_id"], 2, completed={"C1": 3}))
    assert res.json() == {"status": "accepted", "server_revision": 2}
    me = client.get("/api/v1/students/me", headers=bearer(s["token"])).json()
    assert me["server_revision"] == 2


def test_duplicate_revision_creates_no_second_record(client):
    s = register(client)
    body = report(s["student_id"], 1, completed={"C1": 2})
    assert upload(client, s, body).json()["status"] == "accepted"
    for _ in range(3):
        again = upload(client, s, {**body, "generated_at": "2026-10-11T00:00:00Z"})
        assert again.status_code == 200
        assert again.json()["status"] == "duplicate"
    diag = client.get("/api/v1/diagnostics").json()["counts"]
    assert diag["progress_history"] == 1
    overview = client.get("/api/v1/dashboard/overview", headers=login(client, GREEN)).json()
    assert overview["totals"]["enrolled"] == 1
    assert overview["chapters"][0]["completed"] == 1


def test_older_revision_is_ignored(client):
    s = register(client)
    upload(client, s, report(s["student_id"], 5, completed={"C1": 3, "C2": 3}))
    res = upload(client, s, report(s["student_id"], 4, completed={"C1": 3}))
    assert res.json() == {"status": "stale", "server_revision": 5}
    detail = client.get(f"/api/v1/dashboard/students/{s['student_id']}", headers=login(client, GREEN)).json()
    assert detail["revision"] == 5
    assert [c["state"] for c in detail["chapters"][:3]] == ["completed", "completed", "current"]


def test_same_revision_different_content_is_conflict(client):
    s = register(client)
    upload(client, s, report(s["student_id"], 3))
    res = upload(client, s, report(s["student_id"], 3, completed={"C1": 1}))
    assert res.status_code == 409
    assert res.json()["error"]["server_revision"] == 3


def test_token_cannot_report_for_another_student(client):
    a = register(client)
    b = register(client, "NGO-WGL-001")
    res = upload(client, a, report(b["student_id"], 1))
    assert res.status_code == 403
    assert res.json()["error"]["code"] == "student_mismatch"


def test_ngo_comes_from_server_record_not_payload(client):
    s = register(client, "NGO-VJA-001")
    body = report(s["student_id"], 1)
    body["ngo_id"] = "ngo_green_futures"  # unknown field → rejected outright
    assert upload(client, s, body).status_code == 422


def test_report_validation(client):
    s = register(client)
    bad = report(s["student_id"], 1, completed={"C1": 3})
    bad["chapters"].append(dict(bad["chapters"][0]))
    assert upload(client, s, bad).status_code == 422
    bad = report(s["student_id"], 1, completed={"C1": 4})
    assert upload(client, s, bad).status_code == 422
    bad = report(s["student_id"], 1, indicators={"c4_scams_followed": 9})
    assert upload(client, s, bad).status_code == 422
    bad = report(s["student_id"], 1, indicators={"wallet_balance": 900})
    assert upload(client, s, bad).status_code == 422


def test_revoked_token_cannot_upload(client):
    s = register(client)
    client.delete("/api/v1/students/me", headers=bearer(s["token"]))
    assert upload(client, s, report(s["student_id"], 1)).status_code == 401
