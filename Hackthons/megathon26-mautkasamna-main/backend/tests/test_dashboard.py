"""Dashboard auth, tenant isolation, automatic appearance and aggregates."""

from datetime import datetime, timedelta, timezone

from .conftest import GREEN, UDAAN, YFC, bearer, login, register, report


def students(client, headers, **params):
    return client.get("/api/v1/dashboard/students", headers=headers, params=params).json()


def test_requires_sign_in(client):
    assert client.get("/api/v1/dashboard/overview").status_code == 401
    assert client.get("/api/v1/dashboard/overview", headers=bearer("gds_forged")).status_code == 401
    bad = client.post("/api/v1/dashboard/login", json={"username": GREEN[0], "password": "wrong"})
    assert bad.status_code == 401 and bad.json()["error"]["code"] == "invalid_credentials"


def test_logout_ends_session(client):
    h = login(client, GREEN)
    assert client.post("/api/v1/dashboard/logout", headers=h).status_code == 200
    assert client.get("/api/v1/dashboard/me", headers=h).status_code == 401


def test_empty_dashboard(client):
    h = login(client, YFC)
    o = client.get("/api/v1/dashboard/overview", headers=h).json()
    assert o["ngo"]["name"] == "Youth Finance Collective"
    assert o["totals"]["enrolled"] == 0
    assert o["totals"]["overall_completion_pct"] == 0.0
    assert o["totals"]["avg_stars_per_completed_chapter"] is None
    assert all(c["completed"] == 0 for c in o["chapters"])
    assert o["struggles"] == [] and o["recent_activity"] == []
    assert students(client, h)["total"] == 0


def test_new_student_appears_automatically_on_correct_dashboard(client):
    green, udaan = login(client, GREEN), login(client, UDAAN)
    assert students(client, green)["total"] == 0
    s = register(client, "NGO-HYD-001")
    listed = students(client, green)
    assert listed["total"] == 1
    assert listed["students"][0]["student_id"] == s["student_id"]
    assert listed["students"][0]["status"] == "awaiting_first_sync"
    client.post("/api/v1/progress", json=report(s["student_id"], 1, completed={"C1": 3}), headers=bearer(s["token"]))
    row = students(client, green)["students"][0]
    assert row["status"] == "in_progress" and row["chapters_completed"] == 1 and row["total_stars"] == 3
    assert row["centre"]["name"] == "Ameerpet Learning Centre"
    # Never on another NGO's dashboard.
    assert students(client, udaan)["total"] == 0
    assert client.get("/api/v1/dashboard/overview", headers=udaan).json()["totals"]["enrolled"] == 0


def test_cross_ngo_student_detail_is_not_found(client):
    s = register(client, "NGO-WGL-001")
    green, udaan = login(client, GREEN), login(client, UDAAN)
    assert client.get(f"/api/v1/dashboard/students/{s['student_id']}", headers=udaan).status_code == 200
    res = client.get(f"/api/v1/dashboard/students/{s['student_id']}", headers=green)
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "student_not_found"
    # Search and centre filters cannot reach across tenants either.
    assert students(client, green, search=s["student_id"])["total"] == 0
    assert students(client, green, centre="ctr_udaan_warangal")["total"] == 0
    acts = client.get("/api/v1/dashboard/activity", headers=green).json()["activity"]
    assert acts == []


def test_aggregates_are_correct(client):
    h = login(client, GREEN)
    a = register(client, "NGO-HYD-001")
    b = register(client, "NGO-HYD-002")
    register(client, "NGO-HYD-001")  # enrolled, never synced
    client.post("/api/v1/progress", headers=bearer(a["token"]), json=report(
        a["student_id"], 3, completed={"C1": 3, "C2": 2, "C3": 1, "C4": 2},
        badges=["budget_planner"],
        indicators={"c4_scams_followed": 1, "c4_scams_handled_safely": 3, "c2_weeks_saved": 4,
                    "c3_pending_payment": "verified"}))
    client.post("/api/v1/progress", headers=bearer(b["token"]), json=report(
        b["student_id"], 1, completed={"C1": 1, "C2": 1},
        indicators={"c2_weeks_saved": 1}))
    o = client.get("/api/v1/dashboard/overview", headers=h).json()
    t = o["totals"]
    assert t["enrolled"] == 3 and t["synced"] == 2 and t["active_recently"] == 2
    assert t["avg_chapters_completed"] == 2.0  # (4 + 2 + 0) / 3
    assert t["overall_completion_pct"] == round(100 * 6 / 21, 1)
    assert t["avg_stars_per_completed_chapter"] == round((3 + 2 + 1 + 2 + 1 + 1) / 6, 2)
    assert t["badges_awarded"] == 1
    ch = {c["id"]: c for c in o["chapters"]}
    assert ch["C1"]["completed"] == 2 and ch["C1"]["avg_stars"] == 2.0
    assert ch["C1"]["completion_pct"] == round(100 * 2 / 3, 1)
    assert ch["C4"]["completed"] == 1 and ch["C5"]["completed"] == 0
    struggles = {s["key"]: s for s in o["struggles"]}
    assert struggles["c4_followed_scam"]["count"] == 1 and struggles["c4_followed_scam"]["of"] == 1
    assert struggles["c2_irregular_saving"]["count"] == 1 and struggles["c2_irregular_saving"]["of"] == 2
    assert "c3_paid_twice" not in struggles
    assert o["status_counts"] == {"in_progress": 2, "awaiting_first_sync": 1}
    centres = {c["id"]: c for c in client.get("/api/v1/dashboard/centres", headers=h).json()["centres"]}
    assert centres["ctr_gff_ameerpet"]["enrolled"] == 2
    assert centres["ctr_gff_secunderabad"]["enrolled"] == 1
    assert centres["ctr_gff_secunderabad"]["chapters"][1]["completed"] == 1


def test_inactive_status_and_filters(client):
    h = login(client, UDAAN)
    old = (datetime.now(timezone.utc) - timedelta(days=30)).replace(microsecond=0).isoformat()
    a = register(client, "NGO-WGL-001")
    b = register(client, "NGO-KRM-001")
    client.post("/api/v1/progress", headers=bearer(a["token"]),
                json=report(a["student_id"], 1, completed={"C1": 2}, last_activity=old))
    all_c = {f"C{i}": 3 for i in range(1, 8)}
    client.post("/api/v1/progress", headers=bearer(b["token"]), json=report(b["student_id"], 1, completed=all_c))
    assert students(client, h, status="inactive")["students"][0]["student_id"] == a["student_id"]
    assert students(client, h, status="completed")["students"][0]["student_id"] == b["student_id"]
    assert students(client, h, centre="ctr_udaan_karimnagar")["total"] == 1
    ordered = students(client, h, sort="chapters_completed", order="asc")["students"]
    assert [s["chapters_completed"] for s in ordered] == [1, 7]
    page = students(client, h, page_size=1, page=2)
    assert page["total"] == 2 and len(page["students"]) == 1
    assert client.get("/api/v1/dashboard/students", headers=h, params={"sort": "drop table"}).status_code == 400
    o = client.get("/api/v1/dashboard/overview", headers=h).json()
    assert o["totals"]["active_recently"] == 1 and o["totals"]["story_completed"] == 1


def test_student_detail_and_history(client):
    h = login(client, GREEN)
    s = register(client)
    for rev, done in [(1, {}), (2, {"C1": 2}), (3, {"C1": 3, "C2": 1})]:
        client.post("/api/v1/progress", headers=bearer(s["token"]), json=report(
            s["student_id"], rev, completed=done, indicators={"c2_goal": "laptop"} if "C2" in done else {}))
    d = client.get(f"/api/v1/dashboard/students/{s['student_id'].lower()}", headers=h).json()
    assert d["chapters"][1]["state"] == "completed" and d["chapters"][2]["state"] == "current"
    assert d["chapters"][3]["state"] == "locked"
    assert [x["revision"] for x in d["history"]] == [3, 2, 1]
    assert d["indicators"] == {"c2_goal": "laptop"} or d["indicators"]["c2_goal"] == "laptop"
    kinds = [a["kind"] for a in client.get("/api/v1/dashboard/activity", headers=h).json()["activity"]]
    assert kinds.count("progress") == 3 and kinds.count("enrolled") == 1
