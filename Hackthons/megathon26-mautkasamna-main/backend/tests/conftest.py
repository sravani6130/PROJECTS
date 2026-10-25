"""Fixtures: a fresh API on a temporary SQLite file per test, seeded with
the fictional demo NGOs. No student exists until a test registers one."""

from __future__ import annotations

import os
import secrets
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.db import connect
from app.main import create_app

GREEN = ("green.coordinator", "green-demo-2026")
UDAAN = ("udaan.coordinator", "udaan-demo-2026")
YFC = ("yfc.coordinator", "yfc-demo-2026")


# Set GULLAK_TEST_DATABASE_URL=postgresql://… to run every test on
# PostgreSQL instead of a temporary SQLite file (the schema is reset per test).
PG_URL = os.environ.get("GULLAK_TEST_DATABASE_URL", "")


@pytest.fixture()
def settings(tmp_path) -> Settings:
    if PG_URL:
        conn = connect(PG_URL)
        conn.execute("DROP SCHEMA public CASCADE")
        conn.execute("CREATE SCHEMA public")
        conn.close()
    return Settings(env="test", db_path=str(tmp_path / "test.db"), database_url=PG_URL,
                    enrol_rate_per_minute=0, seed_demo=True)


@pytest.fixture()
def client(settings) -> TestClient:
    with TestClient(create_app(settings)) as c:
        yield c


def register(client: TestClient, code: str = "NGO-HYD-001", key: str | None = None) -> dict:
    res = client.post(
        "/api/v1/students/register",
        json={"code": code, "registration_key": key or secrets.token_hex(16), "app_version": "1.0.0"},
    )
    assert res.status_code in (200, 201), res.text
    return res.json()


def bearer(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def login(client: TestClient, creds: tuple[str, str]) -> dict:
    res = client.post("/api/v1/dashboard/login", json={"username": creds[0], "password": creds[1]})
    assert res.status_code == 200, res.text
    return bearer(res.json()["session_token"])


def report(
    student_id: str,
    revision: int,
    *,
    completed: dict[str, int] | None = None,
    current: int | None = None,
    badges: list[str] | None = None,
    indicators: dict | None = None,
    last_activity: str | None = None,
) -> dict:
    """A schema-v1 report. `completed` maps chapter id -> best stars."""
    completed = completed or {}
    current = current or min(len(completed) + 1, 8)
    return {
        "schema_version": 1,
        "student_id": student_id,
        "revision": revision,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "last_activity_at": last_activity or datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0).isoformat(),
        "app_version": "1.0.0",
        "story": {"current_chapter": current, "finished": current == 8},
        "chapters": [
            {"id": cid, "completed": True, "best_stars": stars, "plays": 1,
             "first_completed_at": "2026-10-01T10:00:00Z"}
            for cid, stars in completed.items()
        ],
        "badges": badges or [],
        "indicators": indicators or {},
    }
