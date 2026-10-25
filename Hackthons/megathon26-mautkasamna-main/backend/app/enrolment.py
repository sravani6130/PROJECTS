"""Enrolment codes, student registration, token checks and unlinking."""

from __future__ import annotations

from dataclasses import dataclass

from .db import Connection, now_iso, transaction
from .errors import ApiError
from .security import new_student_id, new_student_token, token_hash


@dataclass(frozen=True)
class CodeInfo:
    code: str
    ngo_id: str
    ngo_name: str
    centre_id: str
    centre_name: str
    city: str


@dataclass(frozen=True)
class Student:
    student_id: str
    ngo_id: str
    centre_id: str
    status: str


def lookup_code(conn: Connection, code: str) -> CodeInfo:
    """Raises 404 for unknown codes and 410 for revoked ones."""
    row = conn.execute(
        """
        SELECT ec.code, ec.status AS code_status, n.ngo_id, n.name AS ngo_name,
               n.status AS ngo_status, c.centre_id, c.name AS centre_name, c.city
        FROM enrolment_code ec
        JOIN ngo n ON n.ngo_id = ec.ngo_id
        JOIN centre c ON c.centre_id = ec.centre_id AND c.ngo_id = ec.ngo_id
        WHERE ec.code = ?
        """,
        (code,),
    ).fetchone()
    if row is None:
        raise ApiError(404, "code_not_found", "This enrolment code does not exist. Check it with your NGO.")
    if row["code_status"] != "active" or row["ngo_status"] != "active":
        raise ApiError(410, "code_revoked", "This enrolment code is no longer active. Ask your NGO for a new one.")
    return CodeInfo(
        code=row["code"],
        ngo_id=row["ngo_id"],
        ngo_name=row["ngo_name"],
        centre_id=row["centre_id"],
        centre_name=row["centre_name"],
        city=row["city"],
    )


def register(
    conn: Connection, *, code: str, registration_key: str, app_version: str
) -> tuple[dict, bool]:
    """Creates a student for a valid code, or returns the student already
    created with the same `registration_key` (a retried request).

    Returns (response, created). A replay issues a fresh token and revokes
    earlier ones: the original response was evidently lost, so no device
    holds the earlier token.
    """
    with transaction(conn):
        existing = conn.execute(
            "SELECT student_id, ngo_id, centre_id, enrolment_code, status FROM student WHERE registration_key = ?",
            (registration_key,),
        ).fetchone()
        if existing is not None:
            if existing["enrolment_code"] != code:
                raise ApiError(409, "registration_key_conflict", "This registration key was used with another code.")
            if existing["status"] != "active":
                raise ApiError(401, "token_revoked", "This enrolment was turned off by the NGO.")
            info = lookup_code(conn, code)
            student_id = existing["student_id"]
            now = now_iso()
            conn.execute(
                "UPDATE student_token SET revoked_at = ? WHERE student_id = ? AND revoked_at IS NULL",
                (now, student_id),
            )
            created = False
        else:
            info = lookup_code(conn, code)
            now = now_iso()
            student_id = _insert_student(conn, info, registration_key, app_version, now)
            created = True
        token = new_student_token()
        conn.execute(
            "INSERT INTO student_token (token_hash, student_id, created_at) VALUES (?, ?, ?)",
            (token_hash(token), student_id, now),
        )
    return (
        {
            "student_id": student_id,
            "token": token,
            "token_scope": "progress:write",
            "ngo": {"id": info.ngo_id, "name": info.ngo_name},
            "centre": {"id": info.centre_id, "name": info.centre_name, "city": info.city},
            "enrolled": True,
        },
        created,
    )


def _insert_student(
    conn: Connection, info: CodeInfo, registration_key: str, app_version: str, now: str
) -> str:
    # Check before inserting: a failed INSERT would abort a PostgreSQL
    # transaction. 40 random bits make a collision vanishingly rare anyway.
    for _ in range(10):
        student_id = new_student_id()
        if conn.execute("SELECT 1 FROM student WHERE student_id = ?", (student_id,)).fetchone() is None:
            conn.execute(
                """
                INSERT INTO student (student_id, ngo_id, centre_id, enrolment_code,
                                     registration_key, app_version, enrolled_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (student_id, info.ngo_id, info.centre_id, info.code, registration_key, app_version or None, now),
            )
            return student_id
    raise ApiError(503, "id_exhausted", "Could not allocate a student ID. Try again.")


def authenticate_student(conn: Connection, authorization: str | None) -> Student:
    """Resolves a `Bearer gst_…` header to an active student. The student's
    NGO comes from this row, never from the request."""
    if not authorization or not authorization.startswith("Bearer "):
        raise ApiError(401, "token_missing", "A student token is required.")
    token = authorization.removeprefix("Bearer ").strip()
    row = conn.execute(
        """
        SELECT t.revoked_at, t.scope, s.student_id, s.ngo_id, s.centre_id, s.status
        FROM student_token t JOIN student s ON s.student_id = t.student_id
        WHERE t.token_hash = ?
        """,
        (token_hash(token),),
    ).fetchone()
    if row is None:
        raise ApiError(401, "token_invalid", "This student token is not recognised.")
    if row["revoked_at"] is not None or row["status"] != "active":
        raise ApiError(401, "token_revoked", "This enrolment was turned off. Enter a new NGO code to link again.")
    if row["scope"] != "progress:write":
        raise ApiError(403, "scope_denied", "This token cannot upload progress.")
    return Student(row["student_id"], row["ngo_id"], row["centre_id"], row["status"])


def touch_token(conn: Connection, authorization: str) -> None:
    conn.execute(
        "UPDATE student_token SET last_used_at = ? WHERE token_hash = ?",
        (now_iso(), token_hash(authorization.removeprefix("Bearer ").strip())),
    )


def student_profile(conn: Connection, student: Student) -> dict:
    row = conn.execute(
        """
        SELECT s.student_id, s.status, s.enrolled_at, s.last_sync_at, n.ngo_id, n.name AS ngo_name,
               c.centre_id, c.name AS centre_name, c.city, p.revision
        FROM student s
        JOIN ngo n ON n.ngo_id = s.ngo_id
        JOIN centre c ON c.centre_id = s.centre_id
        LEFT JOIN progress_current p ON p.student_id = s.student_id
        WHERE s.student_id = ?
        """,
        (student.student_id,),
    ).fetchone()
    return {
        "student_id": row["student_id"],
        "status": row["status"],
        "enrolled_at": row["enrolled_at"],
        "last_sync_at": row["last_sync_at"],
        "server_revision": row["revision"] or 0,
        "ngo": {"id": row["ngo_id"], "name": row["ngo_name"]},
        "centre": {"id": row["centre_id"], "name": row["centre_name"], "city": row["city"]},
    }


def unlink(conn: Connection, student: Student) -> None:
    """The student opted out: the server keeps nothing about them. Progress,
    history and tokens cascade with the student row."""
    with transaction(conn):
        conn.execute("DELETE FROM student WHERE student_id = ?", (student.student_id,))
