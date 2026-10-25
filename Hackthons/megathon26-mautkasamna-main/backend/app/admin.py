"""Operator commands. Adding an NGO needs only these rows, no app release.

    python -m app.admin add-ngo   ngo_new "New Horizons Trust"
    python -m app.admin add-centre ngo_new ctr_new_khammam "Khammam Centre" Khammam
    python -m app.admin add-code  ngo_new ctr_new_khammam NGO-KHM-001
    python -m app.admin add-user  ngo_new new.coordinator "New Horizons coordinator"   (prompts for a password)
    python -m app.admin revoke-code NGO-KHM-001
    python -m app.admin revoke-student STU-XXXX-XXXX
    python -m app.admin delete-student STU-XXXX-XXXX
    python -m app.admin purge-history
"""

from __future__ import annotations

import argparse
import getpass
import re
import sys

from .config import Settings
from .db import connect, migrate, now_iso, transaction
from .progress import purge_old_history
from .schemas import CODE_PATTERN, normalise_code
from .security import hash_password


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="python -m app.admin")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("add-ngo")
    p.add_argument("ngo_id")
    p.add_argument("name")
    p = sub.add_parser("add-centre")
    p.add_argument("ngo_id")
    p.add_argument("centre_id")
    p.add_argument("name")
    p.add_argument("city")
    p = sub.add_parser("add-code")
    p.add_argument("ngo_id")
    p.add_argument("centre_id")
    p.add_argument("code")
    p = sub.add_parser("add-user")
    p.add_argument("ngo_id")
    p.add_argument("username")
    p.add_argument("display_name")
    sub.add_parser("revoke-code").add_argument("code")
    sub.add_parser("revoke-student").add_argument("student_id")
    sub.add_parser("delete-student").add_argument("student_id")
    sub.add_parser("purge-history")
    args = parser.parse_args(argv)

    settings = Settings.from_env()
    conn = connect(settings.database)
    migrate(conn)
    now = now_iso()

    with transaction(conn):
        if args.cmd == "add-ngo":
            conn.execute("INSERT INTO ngo (ngo_id, name, created_at) VALUES (?, ?, ?)", (args.ngo_id, args.name, now))
        elif args.cmd == "add-centre":
            conn.execute(
                "INSERT INTO centre (centre_id, ngo_id, name, city, created_at) VALUES (?, ?, ?, ?, ?)",
                (args.centre_id, args.ngo_id, args.name, args.city, now),
            )
        elif args.cmd == "add-code":
            code = normalise_code(args.code)
            if not re.match(CODE_PATTERN, code):
                print(f"Invalid code format: {code}", file=sys.stderr)
                return 2
            owner = conn.execute(
                "SELECT 1 FROM centre WHERE centre_id = ? AND ngo_id = ?", (args.centre_id, args.ngo_id)
            ).fetchone()
            if owner is None:
                print("That centre does not belong to that NGO.", file=sys.stderr)
                return 2
            conn.execute(
                "INSERT INTO enrolment_code (code, ngo_id, centre_id, created_at) VALUES (?, ?, ?, ?)",
                (code, args.ngo_id, args.centre_id, now),
            )
        elif args.cmd == "add-user":
            password = getpass.getpass("Password for the new dashboard user: ")
            if len(password) < 12:
                print("Use at least 12 characters.", file=sys.stderr)
                return 2
            conn.execute(
                "INSERT INTO dashboard_user (ngo_id, username, display_name, password_hash, created_at) VALUES (?, ?, ?, ?, ?)",
                (args.ngo_id, args.username, args.display_name, hash_password(password), now),
            )
        elif args.cmd == "revoke-code":
            conn.execute(
                "UPDATE enrolment_code SET status = 'revoked', revoked_at = ? WHERE code = ?",
                (now, normalise_code(args.code)),
            )
        elif args.cmd == "revoke-student":
            conn.execute(
                "UPDATE student SET status = 'revoked', revoked_at = ? WHERE student_id = ?", (now, args.student_id)
            )
            conn.execute(
                "UPDATE student_token SET revoked_at = ? WHERE student_id = ? AND revoked_at IS NULL",
                (now, args.student_id),
            )
        elif args.cmd == "delete-student":
            conn.execute("DELETE FROM student WHERE student_id = ?", (args.student_id,))
    if args.cmd == "purge-history":
        print(f"Deleted {purge_old_history(conn, settings.history_retention_days)} history rows.")
    print("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
