# Gullak NGO API (backend)

One shared API and database for every NGO. Python 3.10+, FastAPI; SQLite
locally (standard-library `sqlite3`, WAL mode) or PostgreSQL when
`DATABASE_URL` is set. The NGO dashboard (`../ngo-dashboard/`) is served by the
same process at `/`. Full design: `../docs/NGO_INTEGRATION.md`.

## Setup and run

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt   # runtime + test tools
cp .env.example .env            # optional; defaults match it
.venv/bin/python -m app          # API → http://127.0.0.1:8787/api/v1 (docs: /api/v1/docs)
                                 # dashboard → http://127.0.0.1:8787/
```

On first start the schema is created (`app/db.py`, append-only migrations
tracked in `PRAGMA user_version`) and, in development, the three fictional
NGOs are seeded (`app/seed.py`). No students are seeded.

> On machines where `PYTHONPATH` points at another Python install (ROS, conda…),
> prefix commands with `env -u PYTHONPATH`.

## Tests

```bash
env -u PYTHONPATH PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 .venv/bin/python -m pytest
# the same suite on PostgreSQL (schema is dropped and recreated per test!):
GULLAK_TEST_DATABASE_URL=postgresql://user@host:port/throwaway_db .venv/bin/python -m pytest
```

## Demo data and operations

| Command | Does |
|---|---|
| `.venv/bin/python scripts/simulate_students.py --count 12` | Enrols fictional students **through the public API** (same calls as the app) |
| `.venv/bin/python scripts/export_openapi.py` | Regenerates `openapi.json` |
| `.venv/bin/python -m app.admin add-ngo ngo_x "Name"` | New organisation (then `add-centre`, `add-code`, `add-user`) |
| `.venv/bin/python -m app.admin revoke-code NGO-XXX-001` | Stop new enrolments with a code |
| `.venv/bin/python -m app.admin revoke-student STU-…` | Turn off one student's token(s) |
| `.venv/bin/python -m app.admin delete-student STU-…` | Erase a student and all their progress |
| `.venv/bin/python -m app.admin purge-history` | Delete history older than `GULLAK_HISTORY_RETENTION_DAYS` |

## Demo codes and logins (fictional, development only)

| NGO | Codes (centre) | Dashboard login |
|---|---|---|
| Green Futures Foundation | `NGO-HYD-001` (Ameerpet), `NGO-HYD-002` (Secunderabad) | `green.coordinator` / `green-demo-2026` |
| Udaan Learning Trust | `NGO-WGL-001` (Warangal), `NGO-KRM-001` (Karimnagar) | `udaan.coordinator` / `udaan-demo-2026` |
| Youth Finance Collective | `NGO-VJA-001` (Vijayawada) | `yfc.coordinator` / `yfc-demo-2026` |
| (revoked pilot code) | `NGO-HYD-000` | — |

`GULLAK_ENV=production` refuses to start with demo seeding or `http://` dashboard origins.

## Deploying to Render (free plan)

`render.yaml` at the repository root is a Render Blueprint: one Python web
service (API + dashboard) and a free PostgreSQL database.

1. Push the repository to GitHub.
2. In Render: **New → Blueprint**, connect the repository, and apply. Render
   creates `gullak-ngo` and `gullak-db`, generates the three dashboard passwords
   (`GULLAK_PASSWORD_GREEN/UDAAN/YFC`), and starts the service.
3. Wait for the health check (`/api/v1/health`) to pass. The service URL looks
   like `https://gullak-ngo.onrender.com` (Render may add a suffix if the name is taken).
4. Read the passwords in the service's **Environment** tab and give each one only
   to that NGO's coordinator. Usernames: `green.coordinator`,
   `udaan.coordinator`, `yfc.coordinator`.
5. Build the app against it (HTTPS is required for release builds):
   `flutter build apk --release --dart-define=GULLAK_API_URL=https://<your-service>.onrender.com`

Free-plan behaviour (Render docs): the service sleeps after 15 minutes without
traffic and takes about a minute to wake (the app waits up to 75 s, and progress
stays queued if it gives up); the free database expires 30 days after creation
unless upgraded — after that, replace `DATABASE_URL` with another PostgreSQL
(Render paid, Neon, Supabase…). The service's own disk is temporary, which is
why SQLite is not used there.
