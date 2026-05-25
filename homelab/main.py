"""
AICanvas Sync Server
FastAPI server for syncing notebooks, drawings, and PDFs from the iOS app.

Endpoints:
  GET  /health                  → health check
  GET  /sync/manifest           → list of files with sizes and mtimes
  POST /sync/push               → upload one or more files
  GET  /sync/pull/{file_path}   → download a specific file

Auth: Authorization: Bearer <API_KEY>
"""

import os
import time
import secrets
import hashlib
from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, Header, HTTPException, UploadFile, File, Form
from fastapi.responses import FileResponse, JSONResponse

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

API_KEY = os.environ.get("AICANVAS_API_KEY", "")
DATA_DIR = Path(os.environ.get("AICANVAS_DATA_DIR", "/var/aicanvas/data"))

ALLOWED_EXTENSIONS = {".drawing", ".chat", ".pdf", ".json"}
ALLOWED_PREFIXES = {"drawings/", "pdfs/", "metadata.json"}

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(title="AICanvas Sync", version="1.0.0")


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

def require_auth(authorization: str | None) -> None:
    if not API_KEY:
        raise RuntimeError("AICANVAS_API_KEY env var is not set")
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Authorization header")
    token = authorization.removeprefix("Bearer ").strip()
    if not secrets.compare_digest(token, API_KEY):
        raise HTTPException(status_code=403, detail="Invalid API key")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _validate_path(file_path: str) -> Path:
    """Resolve and validate that the requested path stays inside DATA_DIR."""
    # Normalise separators and strip leading slashes
    clean = file_path.replace("\\", "/").lstrip("/")
    resolved = (DATA_DIR / clean).resolve()
    try:
        resolved.relative_to(DATA_DIR.resolve())
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid file path")
    suffix = resolved.suffix.lower()
    if suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(status_code=400, detail=f"Extension not allowed: {suffix}")
    return resolved


def _file_info(path: Path, relative_to: Path) -> dict:
    stat = path.stat()
    return {
        "size": stat.st_size,
        "mtime": stat.st_mtime,
    }


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    return {"status": "ok", "timestamp": time.time()}


@app.get("/sync/manifest")
def manifest(authorization: Annotated[str | None, Header()] = None):
    """Return a dict of {relative_path: {size, mtime}} for all stored files."""
    require_auth(authorization)
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    files: dict[str, dict] = {}
    for path in DATA_DIR.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() not in ALLOWED_EXTENSIONS:
            continue
        rel = path.relative_to(DATA_DIR).as_posix()
        stat = path.stat()
        files[rel] = {"size": stat.st_size, "mtime": stat.st_mtime}

    return {"files": files}


@app.post("/sync/push")
async def push(
    authorization: Annotated[str | None, Header()] = None,
    files: list[UploadFile] = File(...),
    paths: list[str] = Form(...),
):
    """
    Upload files from the device to the server.
    `files` and `paths` must be parallel arrays of the same length.
    `paths` are relative paths like 'drawings/<UUID>.drawing'.
    """
    require_auth(authorization)

    if len(files) != len(paths):
        raise HTTPException(status_code=400, detail="files and paths must have the same length")

    received: list[str] = []
    for upload, rel_path in zip(files, paths):
        dest = _validate_path(rel_path)
        dest.parent.mkdir(parents=True, exist_ok=True)
        content = await upload.read()
        dest.write_bytes(content)
        received.append(rel_path)

    return {"received": received, "count": len(received)}


@app.get("/sync/pull/{file_path:path}")
def pull(
    file_path: str,
    authorization: Annotated[str | None, Header()] = None,
):
    """Download a specific file from the server."""
    require_auth(authorization)
    dest = _validate_path(file_path)
    if not dest.exists():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(dest)
