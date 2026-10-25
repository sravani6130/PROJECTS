"""NGO dashboard: sign-in and tenant-scoped read models.

Every query here takes the `ngo_id` of the signed-in session and filters by
it. A student from another NGO is reported as "not found", the same as a
student that does not exist, so IDs cannot be probed across tenants.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import timedelta

from .db import Connection, Row, iso, now_iso, transaction, utcnow
from .errors import ApiError
from .schemas import CHAPTER_IDS
from .security import DUMMY_PASSWORD_HASH, new_session_token, token_hash, verify_password


@dataclass(frozen=True)
class Session:
    user_id: int
    ngo_id: str
    username: str
    display_name: str


# ---- Authentication ---------------------------------------------------------


def login(conn: Connection, username: str, password: str, ttl_minutes: int) -> dict:
    row = conn.execute(
        """
        SELECT u.user_id, u.ngo_id, u.username, u.display_name, u.password_hash, u.is_demo,
               n.name AS ngo_name, n.status AS ngo_status
        FROM dashboard_user u JOIN ngo n ON n.ngo_id = u.ngo_id
        WHERE lower(u.username) = lower(?)
        """,
        (username.strip(),),
    ).fetchone()
    ok = verify_password(password, row["password_hash"] if row else DUMMY_PASSWORD_HASH)
    if row is None or not ok:
        raise ApiError(401, "invalid_credentials", "Wrong username or password.")
    if row["ngo_status"] != "active":
        raise ApiError(403, "ngo_suspended", "This organisation's dashboard is suspended.")
    token = new_session_token()
    now = utcnow()
    expires = now + timedelta(minutes=ttl_minutes)
    with transaction(conn):
        conn.execute("DELETE FROM dashboard_session WHERE expires_at < ?", (iso(now),))
        conn.execute(
            "INSERT INTO dashboard_session (session_hash, user_id, ngo_id, created_at, expires_at) VALUES (?, ?, ?, ?, ?)",
            (token_hash(token), row["user_id"], row["ngo_id"], iso(now), iso(expires)),
        )
    return {
        "session_token": token,
        "expires_at": iso(expires),
        "user": {"username": row["username"], "display_name": row["display_name"], "is_demo": bool(row["is_demo"])},
        "ngo": {"id": row["ngo_id"], "name": row["ngo_name"]},
    }


def authenticate(conn: Connection, authorization: str | None) -> Session:
    if not authorization or not authorization.startswith("Bearer "):
        raise ApiError(401, "session_missing", "Sign in to view the dashboard.")
    token = authorization.removeprefix("Bearer ").strip()
    row = conn.execute(
        """
        SELECT s.user_id, s.ngo_id, s.expires_at, u.username, u.display_name
        FROM dashboard_session s JOIN dashboard_user u ON u.user_id = s.user_id
        WHERE s.session_hash = ? AND u.ngo_id = s.ngo_id
        """,
        (token_hash(token),),
    ).fetchone()
    if row is None:
        raise ApiError(401, "session_invalid", "Your session is not valid. Sign in again.")
    if row["expires_at"] < now_iso():
        raise ApiError(401, "session_expired", "Your session expired. Sign in again.")
    return Session(row["user_id"], row["ngo_id"], row["username"], row["display_name"])


def logout(conn: Connection, authorization: str) -> None:
    token = authorization.removeprefix("Bearer ").strip()
    with transaction(conn):
        conn.execute("DELETE FROM dashboard_session WHERE session_hash = ?", (token_hash(token),))


# ---- Read models -------------------------------------------------------------

STATUS_SQL = """
    CASE
      WHEN p.student_id IS NULL THEN 'awaiting_first_sync'
      WHEN p.story_finished = 1 THEN 'completed'
      WHEN COALESCE(p.last_activity_at, s.enrolled_at) < :inactive_cutoff THEN 'inactive'
      ELSE 'in_progress'
    END
"""


def _cutoffs(active_days: int) -> dict[str, str]:
    now = utcnow()
    return {
        "active_cutoff": iso(now - timedelta(days=active_days)),
        "inactive_cutoff": iso(now - timedelta(days=active_days * 2)),
    }


def _report(raw: str | None) -> dict:
    if not raw:
        return {}
    try:
        data = json.loads(raw)
        return data if isinstance(data, dict) else {}
    except ValueError:
        return {}


def ngo_info(conn: Connection, ngo_id: str) -> dict:
    ngo = conn.execute("SELECT ngo_id, name FROM ngo WHERE ngo_id = ?", (ngo_id,)).fetchone()
    centres = conn.execute(
        "SELECT centre_id, name, city FROM centre WHERE ngo_id = ? ORDER BY name", (ngo_id,)
    ).fetchall()
    codes = conn.execute(
        "SELECT code, centre_id, status FROM enrolment_code WHERE ngo_id = ? ORDER BY code", (ngo_id,)
    ).fetchall()
    return {
        "id": ngo["ngo_id"],
        "name": ngo["name"],
        "centres": [{"id": c["centre_id"], "name": c["name"], "city": c["city"]} for c in centres],
        "enrolment_codes": [{"code": c["code"], "centre_id": c["centre_id"], "status": c["status"]} for c in codes],
    }


def _student_rows(conn: Connection, ngo_id: str, active_days: int) -> list[Row]:
    return conn.execute(
        f"""
        SELECT s.student_id, s.centre_id, s.enrolled_at, s.last_sync_at, p.current_chapter,
               p.story_finished, p.chapters_completed, p.total_stars, p.badge_count,
               p.last_activity_at, p.report_json, ({STATUS_SQL}) AS status,
               (p.last_activity_at IS NOT NULL AND p.last_activity_at >= :active_cutoff) AS active
        FROM student s LEFT JOIN progress_current p ON p.student_id = s.student_id AND p.ngo_id = s.ngo_id
        WHERE s.ngo_id = :ngo_id AND s.status = 'active'
        """,
        {"ngo_id": ngo_id, **_cutoffs(active_days)},
    ).fetchall()


def _chapter_stats(rows: list[Row], enrolled: int) -> list[dict]:
    stats = []
    for cid in CHAPTER_IDS:
        stars, plays = [], []
        for r in rows:
            for ch in _report(r["report_json"]).get("chapters", []):
                if ch.get("id") == cid and ch.get("completed"):
                    stars.append(ch.get("best_stars", 0))
                    plays.append(ch.get("plays", 0))
        stats.append(
            {
                "id": cid,
                "completed": len(stars),
                "completion_pct": round(100 * len(stars) / enrolled, 1) if enrolled else 0.0,
                "avg_stars": round(sum(stars) / len(stars), 2) if stars else None,
                "avg_plays": round(sum(plays) / len(plays), 2) if plays else None,
            }
        )
    return stats


# (key, chapter, predicate on indicators, description). Each signal counts
# students who finished that chapter and made the risky choice.
_SIGNALS = [
    ("c4_followed_scam", "C4", lambda i: (i.get("c4_scams_followed") or 0) > 0,
     "followed at least one fake message (scholarship scam chapter)"),
    ("c3_paid_twice", "C3", lambda i: i.get("c3_pending_payment") in ("paid_twice", "paid_cash"),
     "paid again instead of checking a pending UPI payment"),
    ("c5_minimum_only", "C5", lambda i: i.get("c5_credit_repayment") == "minimum",
     "bought on store credit and paid only the minimum"),
    ("c6_borrowed", "C6", lambda i: i.get("c6_emergency_source") == "borrowed_family",
     "had to borrow from family for a surprise cost"),
    ("c7_excluded_claim", "C7", lambda i: i.get("c7_claimed_excluded_cost") is True,
     "tried to claim a cost the insurance policy excludes"),
    ("c2_irregular_saving", "C2", lambda i: i.get("c2_weeks_saved") is not None and i["c2_weeks_saved"] < 3,
     "saved in fewer than 3 of 4 weeks"),
]


def _struggles(rows: list[Row], chapters: list[dict]) -> list[dict]:
    out = []
    for key, cid, risky, text in _SIGNALS:
        finished = [
            _report(r["report_json"]).get("indicators", {})
            for r in rows
            if any(c.get("id") == cid and c.get("completed") for c in _report(r["report_json"]).get("chapters", []))
        ]
        count = sum(1 for ind in finished if risky(ind))
        if count:
            out.append(
                {"key": key, "chapter": cid, "count": count, "of": len(finished),
                 "pct": round(100 * count / len(finished), 1), "description": text}
            )
    for ch in chapters:
        if ch["avg_stars"] is not None and ch["avg_stars"] < 2:
            out.append(
                {"key": f"{ch['id'].lower()}_low_stars", "chapter": ch["id"], "count": ch["completed"],
                 "of": ch["completed"], "pct": 100.0,
                 "description": f"found this chapter hard (average {ch['avg_stars']} of 3 stars)"}
            )
    return sorted(out, key=lambda s: (-s["pct"], -s["count"]))


def overview(conn: Connection, ngo_id: str, active_days: int) -> dict:
    rows = _student_rows(conn, ngo_id, active_days)
    enrolled = len(rows)
    synced = [r for r in rows if r["report_json"]]
    chapters = _chapter_stats(rows, enrolled)
    total_completed = sum(r["chapters_completed"] or 0 for r in rows)
    star_total = sum(r["total_stars"] or 0 for r in rows)
    status_counts: dict[str, int] = {}
    for r in rows:
        status_counts[r["status"]] = status_counts.get(r["status"], 0) + 1
    return {
        "ngo": ngo_info(conn, ngo_id),
        "generated_at": now_iso(),
        "active_days": active_days,
        "totals": {
            "enrolled": enrolled,
            "synced": len(synced),
            "active_recently": sum(1 for r in rows if r["active"]),
            "story_completed": sum(1 for r in rows if r["story_finished"]),
            "avg_chapters_completed": round(total_completed / enrolled, 2) if enrolled else 0.0,
            "overall_completion_pct": round(100 * total_completed / (enrolled * 7), 1) if enrolled else 0.0,
            "avg_stars_per_completed_chapter": round(star_total / total_completed, 2) if total_completed else None,
            "badges_awarded": sum(r["badge_count"] or 0 for r in rows),
        },
        "status_counts": status_counts,
        "chapters": chapters,
        "struggles": _struggles(rows, chapters),
        "recent_activity": activity(conn, ngo_id, limit=8),
    }


SORTS = {
    "student_id": "s.student_id",
    "enrolled_at": "s.enrolled_at",
    "last_activity": "COALESCE(p.last_activity_at, '')",
    "last_sync": "COALESCE(s.last_sync_at, '')",
    "chapters_completed": "COALESCE(p.chapters_completed, -1)",
    "stars": "COALESCE(p.total_stars, -1)",
    "current_chapter": "COALESCE(p.current_chapter, 0)",
}
STATUSES = {"awaiting_first_sync", "in_progress", "completed", "inactive"}


def students(
    conn: Connection,
    ngo_id: str,
    *,
    active_days: int,
    search: str = "",
    centre_id: str = "",
    status: str = "",
    sort: str = "last_activity",
    order: str = "desc",
    page: int = 1,
    page_size: int = 25,
) -> dict:
    if sort not in SORTS:
        raise ApiError(400, "invalid_sort", f"sort must be one of {sorted(SORTS)}")
    if status and status not in STATUSES:
        raise ApiError(400, "invalid_status", f"status must be one of {sorted(STATUSES)}")
    direction = "ASC" if order.lower() == "asc" else "DESC"
    where = ["s.ngo_id = :ngo_id", "s.status = 'active'"]
    params: dict = {"ngo_id": ngo_id, **_cutoffs(active_days)}
    if search:
        where.append("s.student_id LIKE :search ESCAPE '\\'")
        escaped = search.upper().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
        params["search"] = f"%{escaped}%"
    if centre_id:
        where.append("s.centre_id = :centre_id")
        params["centre_id"] = centre_id
    if status:
        where.append(f"({STATUS_SQL}) = :status")
        params["status"] = status
    base = f"""
        FROM student s
        LEFT JOIN progress_current p ON p.student_id = s.student_id AND p.ngo_id = s.ngo_id
        JOIN centre c ON c.centre_id = s.centre_id AND c.ngo_id = s.ngo_id
        WHERE {' AND '.join(where)}
    """
    total = conn.execute(f"SELECT COUNT(*) {base}", params).fetchone()[0]
    page_size = max(1, min(page_size, 100))
    page = max(1, page)
    rows = conn.execute(
        f"""
        SELECT s.student_id, s.centre_id, c.name AS centre_name, s.enrolled_at, s.last_sync_at,
               p.current_chapter, p.story_finished, p.chapters_completed, p.total_stars, p.badge_count,
               p.last_activity_at, p.revision, ({STATUS_SQL}) AS status
        {base}
        ORDER BY {SORTS[sort]} {direction}, s.student_id ASC
        LIMIT :limit OFFSET :offset
        """,
        {**params, "limit": page_size, "offset": (page - 1) * page_size},
    ).fetchall()
    return {
        "page": page,
        "page_size": page_size,
        "total": total,
        "students": [
            {
                "student_id": r["student_id"],
                "centre": {"id": r["centre_id"], "name": r["centre_name"]},
                "status": r["status"],
                "current_chapter": r["current_chapter"],
                "story_finished": bool(r["story_finished"]),
                "chapters_completed": r["chapters_completed"] or 0,
                "total_stars": r["total_stars"] or 0,
                "badge_count": r["badge_count"] or 0,
                "enrolled_at": r["enrolled_at"],
                "last_activity_at": r["last_activity_at"],
                "last_sync_at": r["last_sync_at"],
                "revision": r["revision"],
            }
            for r in rows
        ],
    }


def student_detail(conn: Connection, ngo_id: str, student_id: str, active_days: int) -> dict:
    row = conn.execute(
        f"""
        SELECT s.student_id, s.centre_id, c.name AS centre_name, c.city, s.enrolled_at, s.last_sync_at,
               s.app_version, p.revision, p.report_json, p.received_at, p.last_activity_at,
               ({STATUS_SQL}) AS status
        FROM student s
        JOIN centre c ON c.centre_id = s.centre_id AND c.ngo_id = s.ngo_id
        LEFT JOIN progress_current p ON p.student_id = s.student_id AND p.ngo_id = s.ngo_id
        WHERE s.student_id = :student_id AND s.ngo_id = :ngo_id AND s.status = 'active'
        """,
        {"student_id": student_id, "ngo_id": ngo_id, **_cutoffs(active_days)},
    ).fetchone()
    if row is None:
        raise ApiError(404, "student_not_found", "No student with this ID in your organisation.")
    report = _report(row["report_json"])
    by_id = {c.get("id"): c for c in report.get("chapters", [])}
    current = (report.get("story") or {}).get("current_chapter")
    chapters = []
    for n, cid in enumerate(CHAPTER_IDS, start=1):
        ch = by_id.get(cid)
        if ch and ch.get("completed"):
            state = "completed"
        elif current == n:
            state = "current"
        else:
            state = "locked" if (current or 1) < n else "not_started"
        chapters.append(
            {
                "id": cid,
                "state": state,
                "best_stars": (ch or {}).get("best_stars", 0),
                "plays": (ch or {}).get("plays", 0),
                "first_completed_at": (ch or {}).get("first_completed_at"),
            }
        )
    history = conn.execute(
        """
        SELECT revision, received_at, chapters_completed, total_stars, current_chapter
        FROM progress_history WHERE student_id = ? AND ngo_id = ?
        ORDER BY revision DESC LIMIT 20
        """,
        (student_id, ngo_id),
    ).fetchall()
    return {
        "student_id": row["student_id"],
        "centre": {"id": row["centre_id"], "name": row["centre_name"], "city": row["city"]},
        "status": row["status"],
        "enrolled_at": row["enrolled_at"],
        "last_sync_at": row["last_sync_at"],
        "last_activity_at": row["last_activity_at"],
        "app_version": row["app_version"],
        "revision": row["revision"],
        "story": report.get("story"),
        "chapters": chapters,
        "badges": report.get("badges", []),
        "indicators": report.get("indicators", {}),
        "history": [dict(h) for h in history],
    }


def centres(conn: Connection, ngo_id: str, active_days: int) -> dict:
    rows = _student_rows(conn, ngo_id, active_days)
    out = []
    for c in conn.execute(
        "SELECT centre_id, name, city FROM centre WHERE ngo_id = ? ORDER BY name", (ngo_id,)
    ).fetchall():
        mine = [r for r in rows if r["centre_id"] == c["centre_id"]]
        completed = sum(r["chapters_completed"] or 0 for r in mine)
        out.append(
            {
                "id": c["centre_id"],
                "name": c["name"],
                "city": c["city"],
                "enrolled": len(mine),
                "synced": sum(1 for r in mine if r["report_json"]),
                "active_recently": sum(1 for r in mine if r["active"]),
                "story_completed": sum(1 for r in mine if r["story_finished"]),
                "avg_chapters_completed": round(completed / len(mine), 2) if mine else 0.0,
                "overall_completion_pct": round(100 * completed / (len(mine) * 7), 1) if mine else 0.0,
                "chapters": _chapter_stats(mine, len(mine)),
            }
        )
    return {"generated_at": now_iso(), "centres": out}


def activity(conn: Connection, ngo_id: str, limit: int = 25) -> list[dict]:
    limit = max(1, min(limit, 100))
    rows = conn.execute(
        """
        SELECT * FROM (
          SELECT 'enrolled' AS kind, s.student_id, s.enrolled_at AS at, NULL AS revision,
                 NULL AS chapters_completed, c.name AS centre_name
          FROM student s JOIN centre c ON c.centre_id = s.centre_id
          WHERE s.ngo_id = :ngo_id AND s.status = 'active'
          UNION ALL
          SELECT 'progress' AS kind, h.student_id, h.received_at AS at, h.revision,
                 h.chapters_completed, c.name AS centre_name
          FROM progress_history h
          JOIN student s ON s.student_id = h.student_id AND s.ngo_id = h.ngo_id
          JOIN centre c ON c.centre_id = s.centre_id
          WHERE h.ngo_id = :ngo_id AND s.status = 'active'
        ) AS events ORDER BY at DESC, revision DESC NULLS LAST LIMIT :limit
        """,
        {"ngo_id": ngo_id, "limit": limit},
    ).fetchall()
    return [dict(r) for r in rows]
