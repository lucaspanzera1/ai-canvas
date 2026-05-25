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
import urllib.parse
from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, Header, HTTPException, Request, UploadFile, File
from fastapi.responses import FileResponse, JSONResponse

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

API_KEY = os.environ.get("AICANVAS_API_KEY", "")
DATA_DIR = Path(os.environ.get("AICANVAS_DATA_DIR", "/var/aicanvas/data"))

ALLOWED_EXTENSIONS = {".drawing", ".chat", ".pdf", ".json", ".md"}
ALLOWED_PREFIXES = {"drawings/", "pdfs/", "obsidian/", "metadata.json"}

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


@app.post("/sync/push/{file_path:path}")
async def push(
    file_path: str,
    request: Request,
    authorization: Annotated[str | None, Header()] = None,
):
    """
    Upload a single file. Path is in the URL, body is raw bytes.
    Example: POST /sync/push/drawings/abc.drawing
    """
    require_auth(authorization)
    # Starlette does not always decode %xx in path parameters — decode explicitly.
    decoded_path = urllib.parse.unquote(file_path)
    dest = _validate_path(decoded_path)
    dest.parent.mkdir(parents=True, exist_ok=True)
    content = await request.body()
    dest.write_bytes(content)
    return {"received": decoded_path}


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


@app.get("/obsidian")
def list_obsidian(authorization: Annotated[str | None, Header()] = None):
    """List all generated Markdown files with metadata."""
    require_auth(authorization)
    obsidian_dir = DATA_DIR / "obsidian"
    obsidian_dir.mkdir(parents=True, exist_ok=True)

    files = []
    for path in sorted(obsidian_dir.glob("*.md")):
        stat = path.stat()
        files.append({
            "name": path.stem,
            "filename": path.name,
            "size": stat.st_size,
            "updated_at": stat.st_mtime,
            "pull_url": f"/sync/pull/obsidian/{path.name}",
        })
    return {"notes": files, "count": len(files)}
