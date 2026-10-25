"""Accepting progress reports idempotently.

Per student, revisions only move forward:
- newer revision  → stored as current, appended to history ("accepted")
- same revision, same content → nothing written ("duplicate")
- same revision, different content → 409, the app re-sends with a higher one
- older revision  → ignored ("stale"); the server keeps the newer data

Counts on the dashboard are computed from `progress_current` (one row per
student), so no number of retries can inflate them.
"""

from __future__ import annotations

import json
from datetime import timedelta

from .db import Connection, iso, now_iso, transaction, utcnow
from .enrolment import Student
from .errors import ApiError
from .schemas import ProgressReport


def _canonical(report: ProgressReport) -> str:
    # exclude_none: unplayed indicators are absent, not stored as null.
    data = report.model_dump(mode="json", exclude={"generated_at"}, exclude_none=True)
    return json.dumps(data, sort_keys=True, separators=(",", ":"))


def accept(conn: Connection, student: Student, report: ProgressReport) -> dict:
    if report.student_id != student.student_id:
        # A token may only report for its own student.
        raise ApiError(403, "student_mismatch", "This token belongs to a different student.")
    stored_json = _canonical(report)
    completed = report.completed_chapters
    now = now_iso()
    with transaction(conn):
        current = conn.execute(
            "SELECT revision, report_json FROM progress_current WHERE student_id = ?",
            (student.student_id,),
        ).fetchone()
        if current is not None:
            if report.revision == current["revision"]:
                if current["report_json"] == stored_json:
                    conn.execute(
                        "UPDATE student SET last_sync_at = ? WHERE student_id = ?", (now, student.student_id)
                    )
                    return {"status": "duplicate", "server_revision": current["revision"]}
                raise ApiError(
                    409,
                    "revision_conflict",
                    "A different report with this revision was already accepted.",
                    server_revision=current["revision"],
                )
            if report.revision < current["revision"]:
                return {"status": "stale", "server_revision": current["revision"]}

        values = (
            report.revision,
            report.schema_version,
            report.story.current_chapter,
            int(report.story.finished),
            len(completed),
            sum(c.best_stars for c in completed),
            len(report.badges),
            iso(report.last_activity_at) if report.last_activity_at else None,
            now,
            stored_json,
        )
        conn.execute(
            """
            INSERT INTO progress_current (student_id, ngo_id, revision, schema_version, current_chapter,
                story_finished, chapters_completed, total_stars, badge_count, last_activity_at,
                received_at, report_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT (student_id) DO UPDATE SET
                revision = excluded.revision, schema_version = excluded.schema_version,
                current_chapter = excluded.current_chapter, story_finished = excluded.story_finished,
                chapters_completed = excluded.chapters_completed, total_stars = excluded.total_stars,
                badge_count = excluded.badge_count, last_activity_at = excluded.last_activity_at,
                received_at = excluded.received_at, report_json = excluded.report_json
            """,
            (student.student_id, student.ngo_id, *values),
        )
        conn.execute(
            """
            INSERT INTO progress_history (student_id, ngo_id, revision, chapters_completed,
                total_stars, current_chapter, received_at, report_json)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT DO NOTHING
            """,
            (
                student.student_id,
                student.ngo_id,
                report.revision,
                len(completed),
                sum(c.best_stars for c in completed),
                report.story.current_chapter,
                now,
                stored_json,
            ),
        )
        conn.execute("UPDATE student SET last_sync_at = ? WHERE student_id = ?", (now, student.student_id))
    return {"status": "accepted", "server_revision": report.revision}


def purge_old_history(conn: Connection, retention_days: int) -> int:
    """Deletes history older than the retention period. The current snapshot
    of each student is in `progress_current` and is never purged here."""
    cutoff = iso(utcnow() - timedelta(days=retention_days))
    with transaction(conn):
        cur = conn.execute("DELETE FROM progress_history WHERE received_at < ?", (cutoff,))
    return cur.rowcount
