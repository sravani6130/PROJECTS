"""Writes the API's OpenAPI document to backend/openapi.json.

    python scripts/export_openapi.py
"""

import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.config import Settings  # noqa: E402
from app.main import create_app  # noqa: E402

with tempfile.TemporaryDirectory() as tmp:
    app = create_app(Settings(env="test", db_path=f"{tmp}/openapi.db", seed_demo=False))
    out = Path(__file__).resolve().parent.parent / "openapi.json"
    out.write_text(json.dumps(app.openapi(), indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {out}")
