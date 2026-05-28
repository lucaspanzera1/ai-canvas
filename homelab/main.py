"""
AICanvas Sync Server
FastAPI server for syncing notebooks, drawings, and PDFs from the iOS app.

Endpoints:
  GET  /health                  → health check
  GET  /sync/manifest           → list of files with sizes and mtimes
  POST /sync/push               → upload one or more files
  GET  /sync/pull/{file_path}   → download a specific file

Auth: Authorization: Bearer <API_KEY>

Google Drive sync (via rclone):
  Set GDRIVE_REMOTE=gdrive and GDRIVE_PATH=Obsidian to enable automatic
  upload whenever a file under obsidian/ is pushed.

Notion sync:
  Set NOTION_TOKEN=secret_xxx and NOTION_DATABASE_ID=<db-id> to enable
  automatic upsert of obsidian/*.md files as Notion database pages.
"""

import asyncio
import logging
import os
import re
import time
import secrets
import hashlib
import urllib.parse
from pathlib import Path
from typing import Annotated

from fastapi import BackgroundTasks, FastAPI, Header, HTTPException, Request
from fastapi.responses import FileResponse, JSONResponse

logger = logging.getLogger("aicanvas")

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

API_KEY = os.environ.get("AICANVAS_API_KEY", "")
DATA_DIR = Path(os.environ.get("AICANVAS_DATA_DIR", "/var/aicanvas/data"))
GDRIVE_REMOTE = os.environ.get("GDRIVE_REMOTE", "")   # e.g. "gdrive"
GDRIVE_PATH = os.environ.get("GDRIVE_PATH", "Obsidian")  # folder on Drive

ALLOWED_EXTENSIONS = {".drawing", ".chat", ".pdf", ".json", ".md"}
ALLOWED_PREFIXES = {"drawings/", "pdfs/", "obsidian/", "metadata.json"}

NOTION_TOKEN = os.environ.get("NOTION_TOKEN", "")
NOTION_DATABASE_ID = os.environ.get("NOTION_DATABASE_ID", "")

# Notion rich_text items are capped at 2000 chars each.
_NOTION_TEXT_LIMIT = 2000

# ---------------------------------------------------------------------------
# Notion helpers
# ---------------------------------------------------------------------------

def _rich_text(text: str) -> list[dict]:
    """Split plain text into ≤2000-char rich_text chunks."""
    chunks = []
    for i in range(0, max(len(text), 1), _NOTION_TEXT_LIMIT):
        chunks.append({"type": "text", "text": {"content": text[i:i + _NOTION_TEXT_LIMIT]}})
    return chunks


_INLINE_RE = re.compile(
    r"\*\*(?P<bold>.+?)\*\*"
    r"|\*(?P<italic>.+?)\*"
    r"|`(?P<code>.+?)`"
    r"|\[(?P<link_text>[^\]]+)\]\((?P<link_url>[^)]+)\)"
)


def _parse_inline(text: str) -> list[dict]:
    """Convert inline markdown (bold/italic/code/link) to Notion rich_text."""
    parts: list[dict] = []
    last = 0
    for m in _INLINE_RE.finditer(text):
        if m.start() > last:
            parts.extend(_rich_text(text[last:m.start()]))
        if m.group("bold"):
            parts.append({"type": "text", "text": {"content": m.group("bold")}, "annotations": {"bold": True}})
        elif m.group("italic"):
            parts.append({"type": "text", "text": {"content": m.group("italic")}, "annotations": {"italic": True}})
        elif m.group("code"):
            parts.append({"type": "text", "text": {"content": m.group("code")}, "annotations": {"code": True}})
        elif m.group("link_text"):
            parts.append({"type": "text", "text": {"content": m.group("link_text"), "link": {"url": m.group("link_url")}}})
        last = m.end()
    if last < len(text):
        parts.extend(_rich_text(text[last:]))
    return parts or [{"type": "text", "text": {"content": ""}}]


def _md_to_notion_blocks(content: str) -> list[dict]:
    """Convert a Markdown string to a list of Notion block objects."""
    blocks: list[dict] = []
    lines = content.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]

        # Fenced code block
        if line.startswith("```"):
            lang = line[3:].strip() or "plain text"
            code_lines: list[str] = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i])
                i += 1
            blocks.append({
                "type": "code",
                "code": {
                    "rich_text": _rich_text("\n".join(code_lines)),
                    "language": lang,
                },
            })

        # Headings
        elif line.startswith("### "):
            blocks.append({"type": "heading_3", "heading_3": {"rich_text": _parse_inline(line[4:])}})
        elif line.startswith("## "):
            blocks.append({"type": "heading_2", "heading_2": {"rich_text": _parse_inline(line[3:])}})
        elif line.startswith("# "):
            blocks.append({"type": "heading_1", "heading_1": {"rich_text": _parse_inline(line[2:])}})

        # To-do  (- [ ] / - [x])
        elif re.match(r"^- \[[ x]\] ", line):
            checked = line[3] == "x"
            blocks.append({"type": "to_do", "to_do": {"rich_text": _parse_inline(line[6:]), "checked": checked}})

        # Bulleted list
        elif re.match(r"^[-*] ", line):
            blocks.append({"type": "bulleted_list_item", "bulleted_list_item": {"rich_text": _parse_inline(line[2:])}})

        # Numbered list
        elif re.match(r"^\d+\. ", line):
            text = re.sub(r"^\d+\. ", "", line)
            blocks.append({"type": "numbered_list_item", "numbered_list_item": {"rich_text": _parse_inline(text)}})

        # Blockquote
        elif line.startswith("> "):
            blocks.append({"type": "quote", "quote": {"rich_text": _parse_inline(line[2:])}})

        # Divider
        elif line.strip() in ("---", "***", "___"):
            blocks.append({"type": "divider", "divider": {}})

        # Empty line
        elif line.strip() == "":
            pass

        # Paragraph
        else:
            blocks.append({"type": "paragraph", "paragraph": {"rich_text": _parse_inline(line)}})

        i += 1

    return blocks


async def _sync_md_to_notion(file_path: Path) -> None:
    """Upsert a Markdown file as a page in the configured Notion database."""
    if not NOTION_TOKEN or not NOTION_DATABASE_ID:
        return
    try:
        from notion_client import AsyncClient as NotionAsyncClient
    except ImportError:
        logger.error("notion-client not installed; skipping Notion sync")
        return

    notion = NotionAsyncClient(auth=NOTION_TOKEN)
    title = file_path.stem
    content = file_path.read_text(encoding="utf-8")
    blocks = _md_to_notion_blocks(content)

    try:
        results = await notion.databases.query(
            database_id=NOTION_DATABASE_ID,
            filter={"property": "title", "title": {"equals": title}},
        )
        if results["results"]:
            page_id = results["results"][0]["id"]
            existing = await notion.blocks.children.list(block_id=page_id)
            for block in existing["results"]:
                await notion.blocks.delete(block_id=block["id"])
        else:
            page = await notion.pages.create(
                parent={"database_id": NOTION_DATABASE_ID},
                properties={"title": {"title": [{"type": "text", "text": {"content": title}}]}},
                children=blocks[:100],
            )
            page_id = page["id"]
            blocks = blocks[100:]

        for i in range(0, len(blocks), 100):
            await notion.blocks.children.append(block_id=page_id, children=blocks[i:i + 100])

        logger.info("Notion sync ok: '%s'", title)
    except Exception:
        logger.exception("Notion sync failed for '%s'", title)


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


def _file_hash(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _file_info(path: Path) -> dict:
    stat = path.stat()
    return {
        "size": stat.st_size,
        "mtime": stat.st_mtime,
        "sha256": _file_hash(path),
    }


async def _sync_obsidian_to_gdrive() -> None:
    """Push obsidian/ to Google Drive via rclone (fire-and-forget)."""
    if not GDRIVE_REMOTE:
        return
    src = str(DATA_DIR / "obsidian") + "/"
    dest = f"{GDRIVE_REMOTE}:{GDRIVE_PATH}/"
    proc = await asyncio.create_subprocess_exec(
        "rclone", "copy", src, dest, "--update", "--create-empty-src-dirs",
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    _, stderr = await proc.communicate()
    if proc.returncode != 0:
        logger.error("rclone failed (rc=%d): %s", proc.returncode, stderr.decode())


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
        files[rel] = _file_info(path)

    return {"files": files}


@app.post("/sync/push/{file_path:path}")
async def push(
    file_path: str,
    request: Request,
    background_tasks: BackgroundTasks,
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

    if decoded_path.startswith("obsidian/"):
        background_tasks.add_task(_sync_obsidian_to_gdrive)
        if decoded_path.endswith(".md"):
            background_tasks.add_task(_sync_md_to_notion, dest)

    return {"received": decoded_path, "mtime": dest.stat().st_mtime}


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
