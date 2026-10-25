"""Operator tasks: onboarding a new NGO without an app release; retention."""

import os
import pytest

from app.admin import main as admin
from app.db import connect, migrate, schema_version
from app.progress import purge_old_history

from .conftest import bearer, register, report


@pytest.fixture()
def cli_env(settings):
    os.environ["GULLAK_DB_PATH"] = settings.db_path
    os.environ["DATABASE_URL"] = settings.database_url
    os.environ["GULLAK_ENV"] = "test"
    yield
    for k in ("GULLAK_DB_PATH", "DATABASE_URL", "GULLAK_ENV"):
        os.environ.pop(k)


def test_new_ngo_needs_only_backend_rows(client, cli_env, monkeypatch):
    assert admin(["add-ngo", "ngo_new_horizons", "New Horizons Trust"]) == 0
    assert admin(["add-centre", "ngo_new_horizons", "ctr_nh_khammam", "Khammam Centre", "Khammam"]) == 0
    assert admin(["add-code", "ngo_new_horizons", "ctr_nh_khammam", "ngo-khm-001"]) == 0
    monkeypatch.setattr("getpass.getpass", lambda _: "a-long-demo-password")
    assert admin(["add-user", "ngo_new_horizons", "nh.coordinator", "NH coordinator"]) == 0
    s = register(client, "NGO-KHM-001")
    assert s["ngo"]["name"] == "New Horizons Trust"
    login = client.post("/api/v1/dashboard/login",
                        json={"username": "nh.coordinator", "password": "a-long-demo-password"})
    h = bearer(login.json()["session_token"])
    assert client.get("/api/v1/dashboard/students", headers=h).json()["total"] == 1
    # A code for another NGO's centre is refused.
    assert admin(["add-code", "ngo_new_horizons", "ctr_gff_ameerpet", "NGO-BAD-001"]) == 2
    # Revoking the code stops new enrolments but not existing students.
    assert admin(["revoke-code", "NGO-KHM-001"]) == 0
    assert client.post("/api/v1/enrolment/validate", json={"code": "NGO-KHM-001"}).status_code == 410
    assert client.get("/api/v1/students/me", headers=bearer(s["token"])).status_code == 200


def test_history_retention_keeps_current(client, settings):
    s = register(client)
    for rev in (1, 2):
        client.post("/api/v1/progress", json=report(s["student_id"], rev), headers=bearer(s["token"]))
    conn = connect(settings.database)
    conn.execute("UPDATE progress_history SET received_at = '2020-01-01T00:00:00Z'")
    assert purge_old_history(conn, 180) == 2
    assert conn.execute("SELECT revision FROM progress_current").fetchone()[0] == 2
    conn.close()


def test_migrations_are_versioned(settings, client):
    conn = connect(settings.database)
    assert schema_version(conn) == 1
    assert migrate(conn) == 1  # re-running is a no-op
    conn.close()
