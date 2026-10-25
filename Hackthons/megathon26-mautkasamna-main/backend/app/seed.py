"""Fictional demo organisations.

These NGOs are made up for the prototype; they are not real integrations.
Seeding is idempotent (`ON CONFLICT DO NOTHING`) and never creates students:
every student on a dashboard got there by enrolling through the app (or the
`scripts/simulate_students.py` demo client, which uses the same public API).

Two parts:
- `seed_orgs`: NGOs, centres and enrolment codes (safe anywhere).
- `seed_users`: one dashboard login per demo NGO. In development the public
  demo passwords below are used; on a public deployment each password comes
  from an environment variable (`GULLAK_PASSWORD_GREEN` / `_UDAAN` / `_YFC`),
  and an NGO without one gets no login. Setting the variable again later
  replaces that password.
"""

from __future__ import annotations

from .db import Connection, now_iso, transaction
from .security import hash_password, verify_password

DEMO_NGOS = [
    {
        "ngo_id": "ngo_green_futures",
        "name": "Green Futures Foundation",
        "centres": [
            ("ctr_gff_ameerpet", "Ameerpet Learning Centre", "Hyderabad", "NGO-HYD-001"),
            ("ctr_gff_secunderabad", "Secunderabad Youth Hub", "Hyderabad", "NGO-HYD-002"),
        ],
        "user": ("green.coordinator", "Green Futures coordinator", "green-demo-2026"),
    },
    {
        "ngo_id": "ngo_udaan",
        "name": "Udaan Learning Trust",
        "centres": [
            ("ctr_udaan_warangal", "Warangal Study Centre", "Warangal", "NGO-WGL-001"),
            ("ctr_udaan_karimnagar", "Karimnagar Study Centre", "Karimnagar", "NGO-KRM-001"),
        ],
        "user": ("udaan.coordinator", "Udaan coordinator", "udaan-demo-2026"),
    },
    {
        "ngo_id": "ngo_youth_finance",
        "name": "Youth Finance Collective",
        "centres": [
            ("ctr_yfc_vijayawada", "Vijayawada Centre", "Vijayawada", "NGO-VJA-001"),
        ],
        "user": ("yfc.coordinator", "Youth Finance Collective coordinator", "yfc-demo-2026"),
    },
]

# An old pilot code, revoked, to demonstrate the "code no longer active" path.
REVOKED_CODE = ("NGO-HYD-000", "ngo_green_futures", "ctr_gff_ameerpet")


PASSWORD_ENV = {
    "ngo_green_futures": "GULLAK_PASSWORD_GREEN",
    "ngo_udaan": "GULLAK_PASSWORD_UDAAN",
    "ngo_youth_finance": "GULLAK_PASSWORD_YFC",
}


def seed_orgs(conn: Connection) -> None:
    now = now_iso()
    with transaction(conn):
        for ngo in DEMO_NGOS:
            conn.execute(
                "INSERT INTO ngo (ngo_id, name, created_at) VALUES (?, ?, ?) ON CONFLICT DO NOTHING",
                (ngo["ngo_id"], ngo["name"], now),
            )
            for centre_id, name, city, code in ngo["centres"]:
                conn.execute(
                    "INSERT INTO centre (centre_id, ngo_id, name, city, created_at) VALUES (?, ?, ?, ?, ?) "
                    "ON CONFLICT DO NOTHING",
                    (centre_id, ngo["ngo_id"], name, city, now),
                )
                conn.execute(
                    "INSERT INTO enrolment_code (code, ngo_id, centre_id, created_at) VALUES (?, ?, ?, ?) "
                    "ON CONFLICT DO NOTHING",
                    (code, ngo["ngo_id"], centre_id, now),
                )
        code, ngo_id, centre_id = REVOKED_CODE
        conn.execute(
            """
            INSERT INTO enrolment_code (code, ngo_id, centre_id, status, created_at, revoked_at)
            VALUES (?, ?, ?, 'revoked', ?, ?) ON CONFLICT DO NOTHING
            """,
            (code, ngo_id, centre_id, now, now),
        )


def seed_users(conn: Connection, passwords: dict[str, str] | None = None) -> None:
    """`passwords` maps ngo_id → password. None = the public demo passwords
    (development only)."""
    now = now_iso()
    with transaction(conn):
        for ngo in DEMO_NGOS:
            username, display, demo_password = ngo["user"]
            password = demo_password if passwords is None else passwords.get(ngo["ngo_id"])
            if not password:
                continue
            existing = conn.execute(
                "SELECT user_id, password_hash FROM dashboard_user WHERE lower(username) = lower(?)", (username,)
            ).fetchone()
            if existing is None:
                conn.execute(
                    """
                    INSERT INTO dashboard_user (ngo_id, username, display_name, password_hash, is_demo, created_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (ngo["ngo_id"], username, display, hash_password(password), int(passwords is None), now),
                )
            elif passwords is not None and not verify_password(password, existing[1]):
                # Runs on every start; only a changed password is rewritten.
                conn.execute(
                    "UPDATE dashboard_user SET password_hash = ?, is_demo = 0 WHERE user_id = ?",
                    (hash_password(password), existing[0]),
                )
                # Old sessions end when a password is replaced.
                conn.execute("DELETE FROM dashboard_session WHERE user_id = ?", (existing[0],))


def seed_demo(conn: Connection) -> None:
    """Development: organisations plus the public demo logins."""
    seed_orgs(conn)
    seed_users(conn)
