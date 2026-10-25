"""Enrols fictional demo students through the PUBLIC API, exactly like the
app does (validate code -> register -> upload progress). Nothing is written
to the database directly, so the dashboard shows only what the API accepted.

    python scripts/simulate_students.py                       # 12 students, default codes
    python scripts/simulate_students.py --count 30 --codes NGO-WGL-001,NGO-KRM-001
    python scripts/simulate_students.py --api http://127.0.0.1:8787 --seed 7

All data is synthetic. Uses only the standard library.
"""

from __future__ import annotations

import argparse
import json
import random
import secrets
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone


def call(api: str, method: str, path: str, body: dict | None = None, token: str | None = None) -> dict:
    req = urllib.request.Request(f"{api}/api/v1{path}", method=method,
                                 data=json.dumps(body).encode() if body is not None else None)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=10) as res:
            return json.loads(res.read())
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} -> {e.code}: {e.read().decode()}")


def fake_report(rng: random.Random, student_id: str, revision: int) -> dict:
    done = rng.choices(range(8), weights=[2, 3, 3, 3, 2, 2, 1, 2])[0]
    now = datetime.now(timezone.utc)
    last = (now - timedelta(days=rng.choice([0, 0, 1, 2, 3, 6, 10, 20]))).replace(minute=0, second=0, microsecond=0)
    chapters = [{"id": f"C{n}", "completed": True, "best_stars": rng.choices([1, 2, 3], [1, 3, 4])[0],
                 "plays": rng.choice([1, 1, 1, 2, 3]), "first_completed_at": (last - timedelta(days=7 - n)).isoformat()}
                for n in range(1, done + 1)]
    ind: dict = {}
    if done >= 1: ind["c1_surprise_cost"] = rng.choice(["own_money", "own_money", "advance"])
    if done >= 2: ind |= {"c2_goal": rng.choice(["kit", "course", "laptop"]), "c2_weeks_saved": rng.choice([1, 2, 3, 4, 4])}
    if done >= 3: ind["c3_pending_payment"] = rng.choice(["verified", "verified", "paid_twice", "paid_cash"])
    if done >= 4:
        followed = rng.choice([0, 0, 0, 1, 2])
        ind |= {"c4_scams_followed": followed, "c4_scams_handled_safely": 4 - followed, "c4_hints_used": rng.randint(0, 4)}
    if done >= 5:
        method = rng.choice(["debit", "cash", "credit", "waited"])
        ind["c5_payment_method"] = method
        if method == "credit": ind["c5_credit_repayment"] = rng.choice(["full", "more_than_minimum", "minimum"])
    if done >= 6: ind |= {"c6_fixed_deposit": rng.random() < .6, "c6_emergency_source": rng.choice(["savings", "savings", "broke_deposit", "borrowed_family"])}
    if done >= 7: ind |= {"c7_claimed_excluded_cost": rng.random() < .3, "c7_policy_choice": rng.choice(["keep", "addon", "drop"]), "c7_used_emergency_fund": rng.random() < .7}
    badges = (["budget_planner"] if done >= 1 else []) + (["smart_saver"] if done >= 6 else [])
    return {"schema_version": 1, "student_id": student_id, "revision": revision, "generated_at": now.isoformat(),
            "last_activity_at": last.isoformat(), "app_version": "1.0.0",
            "story": {"current_chapter": min(done + 1, 8), "finished": done == 7},
            "chapters": chapters, "badges": badges, "indicators": ind}


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--api", default="http://127.0.0.1:8787")
    p.add_argument("--count", type=int, default=12)
    p.add_argument("--codes", default="NGO-HYD-001,NGO-HYD-002,NGO-WGL-001")
    p.add_argument("--seed", type=int, default=2026)
    args = p.parse_args()
    rng = random.Random(args.seed)
    codes = args.codes.split(",")
    for i in range(args.count):
        code = codes[i % len(codes)]
        info = call(args.api, "POST", "/enrolment/validate", {"code": code})
        reg = call(args.api, "POST", "/students/register",
                   {"code": code, "registration_key": secrets.token_hex(16), "app_version": "1.0.0"})
        if rng.random() < 0.85:  # some students have not synced yet
            call(args.api, "POST", "/progress", fake_report(rng, reg["student_id"], 1), reg["token"])
        print(f"{reg['student_id']}  {info['ngo']['name']} / {info['centre']['name']}")


if __name__ == "__main__":
    main()
