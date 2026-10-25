"""Gullak NGO API: one backend and database shared by every NGO.

Routes (all under /api/v1):
  Student app   POST /enrolment/validate, POST /students/register,
                GET/DELETE /students/me, POST /progress
  Dashboard     POST /dashboard/login, POST /dashboard/logout, GET /dashboard/me,
                GET /dashboard/overview, /dashboard/students, /dashboard/students/{id},
                /dashboard/centres, /dashboard/activity
  Operations    GET /health, GET /diagnostics
OpenAPI: /api/v1/openapi.json (interactive docs at /api/v1/docs).
"""


import json
import logging
import threading
import time
from collections import defaultdict, deque
from typing import Annotated, Iterator

from fastapi import Depends, FastAPI, Header, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from . import dashboard, enrolment, progress
from .config import BACKEND_DIR, Settings
from .db import Connection, connect, migrate, schema_version, transaction
from .errors import ApiError, error_body
from .schemas import CodeCheck, Login, ProgressReport, Registration
from .seed import seed_demo, seed_orgs, seed_users

log = logging.getLogger("gullak.api")
API = "/api/v1"


class BodyLimit:
    """Rejects request bodies larger than the limit with 413, whether or
    not the client sent a Content-Length."""

    def __init__(self, app: ASGIApp, max_bytes: int) -> None:
        self.app = app
        self.max_bytes = max_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return
        headers = dict(scope.get("headers") or [])
        length = headers.get(b"content-length")
        if length is not None and length.isdigit() and int(length) > self.max_bytes:
            await _send_json(send, 413, error_body("payload_too_large", "Request body is too large."))
            return
        received = 0

        async def limited() -> Message:
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > self.max_bytes:
                    raise _TooLarge()
            return message

        try:
            await self.app(scope, limited, send)
        except _TooLarge:
            await _send_json(send, 413, error_body("payload_too_large", "Request body is too large."))


class _TooLarge(Exception):
    pass


async def _send_json(send: Send, status: int, body: dict) -> None:
    raw = json.dumps(body).encode()
    await send({"type": "http.response.start", "status": status,
                "headers": [(b"content-type", b"application/json"), (b"content-length", str(len(raw)).encode())]})
    await send({"type": "http.response.body", "body": raw})


class RateLimiter:
    """Small in-memory sliding window per client and bucket. Enough for one
    process; a deployment behind several workers needs a shared store."""

    def __init__(self, per_minute: int) -> None:
        self.per_minute = per_minute
        self._hits: dict[tuple[str, str], deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def check(self, bucket: str, client: str) -> None:
        if self.per_minute <= 0:
            return
        now = time.monotonic()
        with self._lock:
            hits = self._hits[(bucket, client)]
            while hits and now - hits[0] > 60:
                hits.popleft()
            if len(hits) >= self.per_minute:
                raise ApiError(429, "rate_limited", "Too many attempts. Wait a minute and try again.")
            hits.append(now)


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    settings.validate()

    if settings.database == ":memory:":
        raise ValueError("Use a database file; each request opens its own connection.")
    boot = connect(settings.database)
    migrate(boot)
    if settings.seed_demo:
        seed_demo(boot)
    elif settings.seed_orgs:
        seed_orgs(boot)
    if settings.org_passwords:
        seed_users(boot, settings.org_passwords)
    boot.close()
    started = time.time()
    limiter = RateLimiter(settings.enrol_rate_per_minute)

    app = FastAPI(
        title="Gullak NGO API",
        version=settings.version,
        description="Multi-NGO enrolment, progress sync and dashboards for the Gullak app. "
        "All organisations in the demo are fictional.",
        openapi_url=f"{API}/openapi.json",
        docs_url=f"{API}/docs",
        redoc_url=None,
    )
    app.state.settings = settings
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(settings.cors_origins),
        allow_methods=["GET", "POST", "DELETE"],
        allow_headers=["Authorization", "Content-Type"],
        max_age=600,
    )
    app.add_middleware(BodyLimit, max_bytes=settings.max_body_bytes)

    @app.middleware("http")
    async def headers_and_log(request: Request, call_next):
        start = time.perf_counter()
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Cache-Control"] = "no-store"
        response.headers["Referrer-Policy"] = "no-referrer"
        # Path and status only: no bodies, query strings or Authorization.
        log.info("%s %s -> %s (%.0f ms)", request.method, request.url.path, response.status_code,
                 (time.perf_counter() - start) * 1000)
        return response

    @app.exception_handler(ApiError)
    async def api_error(_: Request, exc: ApiError) -> JSONResponse:
        return JSONResponse(exc.body(), status_code=exc.status)

    @app.exception_handler(RequestValidationError)
    async def invalid(_: Request, exc: RequestValidationError) -> JSONResponse:
        details = [
            {"field": ".".join(str(p) for p in e.get("loc", ()) if p != "body"), "problem": e.get("msg", "")}
            for e in exc.errors()[:20]
        ]
        return JSONResponse(error_body("invalid_request", "The request is not valid.", details=details), 422)

    def get_db() -> Iterator[Connection]:
        conn = connect(settings.database)
        try:
            yield conn
        finally:
            conn.close()

    Db = Annotated[Connection, Depends(get_db)]
    Auth = Annotated[str | None, Header(alias="Authorization")]

    def client_ip(request: Request) -> str:
        if settings.trust_proxy:
            # Render sits behind Cloudflare, which sets CF-Connecting-IP;
            # otherwise the first X-Forwarded-For hop. Only used for rate
            # limiting, so a spoofed value can at worst dodge the limit.
            forwarded = request.headers.get("cf-connecting-ip") or request.headers.get("x-forwarded-for", "")
            if forwarded:
                return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "unknown"

    def session(db: Db, authorization: Auth = None) -> dashboard.Session:
        return dashboard.authenticate(db, authorization)

    Sess = Annotated[dashboard.Session, Depends(session)]

    # ---- Operations ----------------------------------------------------------

    @app.get(f"{API}/health", tags=["operations"])
    def health(db: Db) -> dict:
        db.execute("SELECT 1").fetchone()
        return {"status": "ok", "version": settings.version, "schema_version": schema_version(db),
                # Lets the dashboard know whether the public demo passwords work.
                "demo_logins": settings.seed_demo}

    @app.get(f"{API}/diagnostics", tags=["operations"])
    def diagnostics(db: Db) -> dict:
        """Non-tenant operational numbers only; no student data."""
        counts = {
            t: db.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
            for t in ("ngo", "centre", "enrolment_code", "student", "progress_history")
        }
        return {
            "status": "ok",
            "env": settings.env,
            "database": "postgres" if settings.database_url else "sqlite",
            "uptime_seconds": int(time.time() - started),
            "schema_version": schema_version(db),
            "counts": counts,
            "limits": {"max_body_bytes": settings.max_body_bytes,
                       "enrol_rate_per_minute": settings.enrol_rate_per_minute},
        }

    # ---- Student app -----------------------------------------------------------

    @app.post(f"{API}/enrolment/validate", tags=["student"])
    def validate_code(body: CodeCheck, db: Db, request: Request) -> dict:
        limiter.check("enrol", client_ip(request))
        info = enrolment.lookup_code(db, body.code)
        return {"valid": True, "code": info.code, "ngo": {"id": info.ngo_id, "name": info.ngo_name},
                "centre": {"id": info.centre_id, "name": info.centre_name, "city": info.city}}

    @app.post(f"{API}/students/register", tags=["student"], status_code=201)
    def register(body: Registration, db: Db, request: Request) -> JSONResponse:
        limiter.check("enrol", client_ip(request))
        result, created = enrolment.register(
            db, code=body.code, registration_key=body.registration_key, app_version=body.app_version
        )
        return JSONResponse({**result, "replayed": not created}, status_code=201 if created else 200)

    @app.get(f"{API}/students/me", tags=["student"])
    def me(db: Db, authorization: Auth = None) -> dict:
        student = enrolment.authenticate_student(db, authorization)
        return enrolment.student_profile(db, student)

    @app.delete(f"{API}/students/me", tags=["student"])
    def unlink(db: Db, authorization: Auth = None) -> dict:
        student = enrolment.authenticate_student(db, authorization)
        enrolment.unlink(db, student)
        return {"unlinked": True, "student_id": student.student_id}

    @app.post(f"{API}/progress", tags=["student"])
    def upload(report: ProgressReport, db: Db, authorization: Auth = None) -> dict:
        student = enrolment.authenticate_student(db, authorization)
        result = progress.accept(db, student, report)
        with transaction(db):
            enrolment.touch_token(db, authorization or "")
        return result

    # ---- Dashboard -------------------------------------------------------------

    @app.post(f"{API}/dashboard/login", tags=["dashboard"])
    def login(body: Login, db: Db, request: Request) -> dict:
        limiter.check("login", client_ip(request))
        return dashboard.login(db, body.username, body.password, settings.session_ttl_minutes)

    @app.post(f"{API}/dashboard/logout", tags=["dashboard"])
    def logout(s: Sess, db: Db, authorization: Auth = None) -> dict:
        dashboard.logout(db, authorization or "")
        return {"signed_out": True}

    @app.get(f"{API}/dashboard/me", tags=["dashboard"])
    def dashboard_me(s: Sess, db: Db) -> dict:
        return {"user": {"username": s.username, "display_name": s.display_name},
                "ngo": dashboard.ngo_info(db, s.ngo_id)}

    @app.get(f"{API}/dashboard/overview", tags=["dashboard"])
    def overview(s: Sess, db: Db) -> dict:
        return dashboard.overview(db, s.ngo_id, settings.active_days)

    @app.get(f"{API}/dashboard/students", tags=["dashboard"])
    def list_students(
        s: Sess,
        db: Db,
        search: Annotated[str, Query(max_length=20)] = "",
        centre: Annotated[str, Query(max_length=64)] = "",
        status: Annotated[str, Query(max_length=32)] = "",
        sort: Annotated[str, Query(max_length=32)] = "last_activity",
        order: Annotated[str, Query(pattern="^(asc|desc)$")] = "desc",
        page: Annotated[int, Query(ge=1, le=10_000)] = 1,
        page_size: Annotated[int, Query(ge=1, le=100)] = 25,
    ) -> dict:
        return dashboard.students(db, s.ngo_id, active_days=settings.active_days, search=search, centre_id=centre,
                                  status=status, sort=sort, order=order, page=page, page_size=page_size)

    @app.get(f"{API}/dashboard/students/{{student_id}}", tags=["dashboard"])
    def student_detail(student_id: str, s: Sess, db: Db) -> dict:
        return dashboard.student_detail(db, s.ngo_id, student_id.upper(), settings.active_days)

    @app.get(f"{API}/dashboard/centres", tags=["dashboard"])
    def centres(s: Sess, db: Db) -> dict:
        return dashboard.centres(db, s.ngo_id, settings.active_days)

    @app.get(f"{API}/dashboard/activity", tags=["dashboard"])
    def recent(s: Sess, db: Db, limit: Annotated[int, Query(ge=1, le=100)] = 25) -> dict:
        return {"activity": dashboard.activity(db, s.ngo_id, limit)}

    # The NGO dashboard is served from the same origin as the API when the
    # folder is present (deployments), so no CORS is needed there.
    dashboard_dir = BACKEND_DIR.parent / "ngo-dashboard"
    if dashboard_dir.is_dir():
        app.mount("/", StaticFiles(directory=dashboard_dir, html=True), name="dashboard")

    return app
