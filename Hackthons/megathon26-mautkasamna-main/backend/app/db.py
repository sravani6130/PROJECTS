"""Database access (SQLite locally, PostgreSQL when `DATABASE_URL` is set)
and schema migrations.

Application code uses one small interface for both: `conn.execute(sql,
params)` with `?` / `:name` placeholders, rows readable by column name or
index, and `transaction(conn)`. SQL is written in the subset both engines
share (`INSERT ... ON CONFLICT`, TEXT timestamps in ISO-8601 UTC).

Every tenant-owned row carries `ngo_id`. Queries for the dashboard always
filter by the NGO of the signed-in session; queries for a student always
start from the student row found through their token, so the NGO is never
taken from the request body.

Migrations are append-only (same rule as the app's `migrations.dart`).
"""

from __future__ import annotations

import re
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator, Protocol

MIGRATIONS: list[tuple[int, str, list[str]]] = [
    (
        1,
        "Multi-NGO tenancy, students, tokens, progress, dashboard users",
        [
            """
            CREATE TABLE ngo (
              ngo_id     TEXT PRIMARY KEY,
              name       TEXT NOT NULL UNIQUE,
              status     TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
              created_at TEXT NOT NULL
            )""",
            """
            CREATE TABLE centre (
              centre_id  TEXT PRIMARY KEY,
              ngo_id     TEXT NOT NULL REFERENCES ngo(ngo_id) ON DELETE CASCADE,
              name       TEXT NOT NULL,
              city       TEXT NOT NULL,
              created_at TEXT NOT NULL,
              UNIQUE (ngo_id, name)
            )""",
            # A code identifies an organisation's centre, never a student.
            """
            CREATE TABLE enrolment_code (
              code       TEXT PRIMARY KEY CHECK (code = upper(code)),
              ngo_id     TEXT NOT NULL REFERENCES ngo(ngo_id) ON DELETE CASCADE,
              centre_id  TEXT NOT NULL REFERENCES centre(centre_id) ON DELETE CASCADE,
              status     TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
              created_at TEXT NOT NULL,
              revoked_at TEXT
            )""",
            # registration_key: random value the app generates once per
            # enrolment attempt and resends on retries, so a retry returns the
            # same student instead of creating another one.
            """
            CREATE TABLE student (
              student_id       TEXT PRIMARY KEY,
              ngo_id           TEXT NOT NULL REFERENCES ngo(ngo_id) ON DELETE CASCADE,
              centre_id        TEXT NOT NULL REFERENCES centre(centre_id),
              enrolment_code   TEXT NOT NULL,
              registration_key TEXT NOT NULL UNIQUE,
              status           TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
              app_version      TEXT,
              enrolled_at      TEXT NOT NULL,
              last_sync_at     TEXT,
              revoked_at       TEXT
            )""",
            "CREATE INDEX ix_student_ngo ON student(ngo_id, enrolled_at)",
            "CREATE INDEX ix_student_centre ON student(ngo_id, centre_id)",
            # Only a SHA-256 of each token is stored. Scope is fixed to what a
            # student device may do.
            """
            CREATE TABLE student_token (
              token_hash   TEXT PRIMARY KEY,
              student_id   TEXT NOT NULL REFERENCES student(student_id) ON DELETE CASCADE,
              scope        TEXT NOT NULL DEFAULT 'progress:write',
              created_at   TEXT NOT NULL,
              last_used_at TEXT,
              revoked_at   TEXT
            )""",
            "CREATE INDEX ix_token_student ON student_token(student_id)",
            # The latest accepted snapshot per student. Columns the dashboard
            # aggregates are broken out; the full (small) report is kept too.
            """
            CREATE TABLE progress_current (
              student_id         TEXT PRIMARY KEY REFERENCES student(student_id) ON DELETE CASCADE,
              ngo_id             TEXT NOT NULL REFERENCES ngo(ngo_id) ON DELETE CASCADE,
              revision           INTEGER NOT NULL CHECK (revision >= 1),
              schema_version     INTEGER NOT NULL,
              current_chapter    INTEGER NOT NULL CHECK (current_chapter BETWEEN 1 AND 8),
              story_finished     INTEGER NOT NULL CHECK (story_finished IN (0, 1)),
              chapters_completed INTEGER NOT NULL CHECK (chapters_completed BETWEEN 0 AND 7),
              total_stars        INTEGER NOT NULL CHECK (total_stars BETWEEN 0 AND 21),
              badge_count        INTEGER NOT NULL CHECK (badge_count >= 0),
              last_activity_at   TEXT,
              received_at        TEXT NOT NULL,
              report_json        TEXT NOT NULL
            )""",
            "CREATE INDEX ix_progress_ngo ON progress_current(ngo_id)",
            # One row per accepted revision. The unique key is what makes a
            # retried upload unable to create a second record.
            """
            CREATE TABLE progress_history (
              history_id  INTEGER PRIMARY KEY AUTOINCREMENT,
              student_id  TEXT NOT NULL REFERENCES student(student_id) ON DELETE CASCADE,
              ngo_id      TEXT NOT NULL REFERENCES ngo(ngo_id) ON DELETE CASCADE,
              revision    INTEGER NOT NULL,
              chapters_completed INTEGER NOT NULL,
              total_stars INTEGER NOT NULL,
              current_chapter INTEGER NOT NULL,
              received_at TEXT NOT NULL,
              report_json TEXT NOT NULL,
              UNIQUE (student_id, revision)
            )""",
            "CREATE INDEX ix_history_ngo_time ON progress_history(ngo_id, received_at)",
            """
            CREATE TABLE dashboard_user (
              user_id       INTEGER PRIMARY KEY AUTOINCREMENT,
              ngo_id        TEXT NOT NULL REFERENCES ngo(ngo_id) ON DELETE CASCADE,
              username      TEXT NOT NULL UNIQUE,
              display_name  TEXT NOT NULL,
              password_hash TEXT NOT NULL,
              is_demo       INTEGER NOT NULL DEFAULT 0 CHECK (is_demo IN (0, 1)),
              created_at    TEXT NOT NULL
            )""",
            """
            CREATE TABLE dashboard_session (
              session_hash TEXT PRIMARY KEY,
              user_id      INTEGER NOT NULL REFERENCES dashboard_user(user_id) ON DELETE CASCADE,
              ngo_id       TEXT NOT NULL REFERENCES ngo(ngo_id) ON DELETE CASCADE,
              created_at   TEXT NOT NULL,
              expires_at   TEXT NOT NULL
            )""",
            # Usernames are unique ignoring case (sign-in compares lower()).
            "CREATE UNIQUE INDEX ux_dashboard_user_lower ON dashboard_user (lower(username))",
        ],
    ),
]


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def now_iso() -> str:
    return iso(utcnow())


class Row(dict):
    """A result row: `row["col"]`, `row[0]` and `dict(row)` all work."""

    def __getitem__(self, key: Any) -> Any:
        if isinstance(key, int):
            return list(self.values())[key]
        return super().__getitem__(key)


class Cursor(Protocol):
    rowcount: int

    def fetchone(self) -> Any: ...
    def fetchall(self) -> list[Any]: ...


class Connection(Protocol):
    dialect: str

    def execute(self, sql: str, params: Any = ...) -> Cursor: ...
    def close(self) -> None: ...


class SqliteConnection:
    dialect = "sqlite"

    def __init__(self, path: str) -> None:
        if path != ":memory:":
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        # Autocommit; writes use `transaction()` (BEGIN IMMEDIATE) so
        # concurrent registrations and uploads serialise cleanly.
        self.raw = sqlite3.connect(path, isolation_level=None, timeout=10, check_same_thread=False)
        self.raw.row_factory = sqlite3.Row
        self.raw.execute("PRAGMA foreign_keys = ON")
        self.raw.execute("PRAGMA busy_timeout = 10000")
        if path != ":memory:":
            self.raw.execute("PRAGMA journal_mode = WAL")

    def execute(self, sql: str, params: Any = ()) -> sqlite3.Cursor:
        return self.raw.execute(sql, params)

    def close(self) -> None:
        self.raw.close()


_NAMED = re.compile(r"(?<![:\w]):([a-z_][a-z0-9_]*)")


def to_pyformat(sql: str) -> str:
    """`?` / `:name` placeholders → psycopg's `%s` / `%(name)s`."""
    sql = sql.replace("%", "%%")
    sql = _NAMED.sub(r"%(\1)s", sql)
    return sql.replace("?", "%s")


class _PgCursor:
    def __init__(self, cur: Any) -> None:
        self._cur = cur
        self.rowcount = cur.rowcount

    def fetchone(self) -> Row | None:
        row = self._cur.fetchone()
        return None if row is None else Row(row)

    def fetchall(self) -> list[Row]:
        return [Row(r) for r in self._cur.fetchall()]


class PostgresConnection:
    dialect = "postgres"

    def __init__(self, url: str) -> None:
        import psycopg
        from psycopg.rows import dict_row

        self.raw = psycopg.connect(url, autocommit=True, row_factory=dict_row, connect_timeout=10)

    def execute(self, sql: str, params: Any = ()) -> _PgCursor:
        return _PgCursor(self.raw.execute(to_pyformat(sql), params or None))

    def close(self) -> None:
        self.raw.close()


def is_postgres_url(target: str) -> bool:
    return target.startswith(("postgres://", "postgresql://"))


def connect(target: str) -> Connection:
    """`target` is a PostgreSQL URL or a SQLite file path."""
    return PostgresConnection(target) if is_postgres_url(target) else SqliteConnection(target)


@contextmanager
def transaction(conn: Connection) -> Iterator[Connection]:
    conn.execute("BEGIN IMMEDIATE" if conn.dialect == "sqlite" else "BEGIN")
    try:
        yield conn
    except BaseException:
        conn.execute("ROLLBACK")
        raise
    else:
        conn.execute("COMMIT")


def _ddl(conn: Connection, sql: str) -> str:
    if conn.dialect == "postgres":
        sql = sql.replace("INTEGER PRIMARY KEY AUTOINCREMENT", "BIGSERIAL PRIMARY KEY")
    return sql


def schema_version(conn: Connection) -> int:
    if conn.dialect == "sqlite":
        return conn.execute("PRAGMA user_version").fetchone()[0]
    conn.execute("CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)")
    row = conn.execute("SELECT MAX(version) FROM schema_version").fetchone()
    return row[0] or 0


def migrate(conn: Connection) -> int:
    """Applies pending migrations, each in its own transaction. Returns the version."""
    current = schema_version(conn)
    for version, _description, statements in MIGRATIONS:
        if version <= current:
            continue
        with transaction(conn):
            for sql in statements:
                conn.execute(_ddl(conn, sql))
            if conn.dialect == "sqlite":
                conn.execute(f"PRAGMA user_version = {version}")
            else:
                conn.execute("INSERT INTO schema_version (version) VALUES (?)", (version,))
        current = version
    return current
