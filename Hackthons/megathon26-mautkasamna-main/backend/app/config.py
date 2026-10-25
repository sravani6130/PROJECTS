"""Environment-based configuration.

Values come from the process environment, optionally pre-filled from a
`backend/.env` file (simple KEY=VALUE lines; real environment wins). No
secrets have defaults that could leak into production: the only credentials
the server creates are demo dashboard logins, and only in development.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent


def load_dotenv(path: Path = BACKEND_DIR / ".env") -> None:
    """Reads KEY=VALUE lines into os.environ without overriding real env."""
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def _bool(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Settings:
    env: str = "development"
    db_path: str = str(BACKEND_DIR / "data" / "gullak.db")
    host: str = "127.0.0.1"
    port: int = 8787
    cors_origins: tuple[str, ...] = ("http://localhost:5173", "http://127.0.0.1:5173")
    max_body_bytes: int = 16 * 1024
    enrol_rate_per_minute: int = 30
    session_ttl_minutes: int = 480
    active_days: int = 7
    history_retention_days: int = 180
    seed_demo: bool = True
    # Seed the fictional NGOs, centres and codes (without demo logins).
    seed_orgs: bool = False
    # PostgreSQL URL; when set it is used instead of the SQLite file.
    database_url: str = ""
    # Behind a reverse proxy (Render): rate-limit by the forwarded client IP.
    trust_proxy: bool = False
    # ngo_id → dashboard password for the demo NGOs on a public deployment.
    org_passwords: dict[str, str] = field(default_factory=dict)
    version: str = field(default="1.0.0")

    @property
    def database(self) -> str:
        """What `db.connect()` opens: the PostgreSQL URL or the SQLite path."""
        return self.database_url or self.db_path

    @property
    def is_production(self) -> bool:
        return self.env == "production"

    def validate(self) -> None:
        if self.env not in {"development", "test", "production"}:
            raise ValueError(f"GULLAK_ENV must be development, test or production, not {self.env!r}")
        if self.is_production:
            if self.seed_demo:
                raise ValueError("GULLAK_SEED_DEMO must be false in production (demo logins are public)")
            if any(o.startswith("http://") for o in self.cors_origins):
                raise ValueError("Production dashboard origins must use https://")
            weak = [k for k, v in self.org_passwords.items() if len(v) < 12]
            if weak:
                raise ValueError(f"Dashboard passwords must be at least 12 characters ({weak})")
        if self.max_body_bytes < 1024:
            raise ValueError("GULLAK_MAX_BODY_BYTES is too small")

    @classmethod
    def from_env(cls) -> "Settings":
        load_dotenv()
        e = os.environ
        from .seed import PASSWORD_ENV
        db_path = e.get("GULLAK_DB_PATH", "./data/gullak.db")
        if not os.path.isabs(db_path) and db_path != ":memory:":
            db_path = str((BACKEND_DIR / db_path).resolve())
        settings = cls(
            env=e.get("GULLAK_ENV", "development"),
            db_path=db_path,
            host=e.get("GULLAK_HOST", "127.0.0.1"),
            # Render and similar hosts pass the port as PORT.
            port=int(e.get("GULLAK_PORT") or e.get("PORT") or "8787"),
            cors_origins=tuple(
                o.strip() for o in e.get("GULLAK_CORS_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173").split(",") if o.strip()
            ),
            max_body_bytes=int(e.get("GULLAK_MAX_BODY_BYTES", str(16 * 1024))),
            enrol_rate_per_minute=int(e.get("GULLAK_ENROL_RATE_PER_MINUTE", "30")),
            session_ttl_minutes=int(e.get("GULLAK_SESSION_TTL_MINUTES", "480")),
            active_days=int(e.get("GULLAK_ACTIVE_DAYS", "7")),
            history_retention_days=int(e.get("GULLAK_HISTORY_RETENTION_DAYS", "180")),
            seed_demo=_bool(e.get("GULLAK_SEED_DEMO", "true")),
            seed_orgs=_bool(e.get("GULLAK_SEED_ORGS", "false")),
            database_url=e.get("DATABASE_URL", "").strip(),
            trust_proxy=_bool(e.get("GULLAK_TRUST_PROXY", "false")),
            org_passwords={ngo: e[var] for ngo, var in PASSWORD_ENV.items() if e.get(var)},
        )
        settings.validate()
        return settings
