#!/usr/bin/env python3
"""Holy Moley community level service.

A deliberately small, dependency-free HTTP service for publishing and loading
Level Forge JSON files. By default it stores everything in one local JSON file.
Set UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN to keep the same JSON
document in a free Upstash Redis database instead, which survives free Render
web-service restarts. It is meant to run behind Render, Fly, a VPS, or on a LAN
machine while testing.

Run locally:
    python server/level_server.py --port 8787 --data-dir server/data

The game's editor talks to /api/levels. CORS is open so the Web export can use
the same service.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import secrets
import threading
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

MAX_BODY_BYTES = 1024 * 1024
MAX_BLOCKS = 30000
MAX_ENEMIES = 1000
MAX_PROPS = 3000
NAME_MAX = 60
AUTHOR_MAX = 40
DESCRIPTION_MAX = 280
ID_RE = re.compile(r"^[a-f0-9]{12}$")

STORE_LOCK = threading.Lock()
STORE: dict = {"version": 1, "levels": {}}
DATA_FILE: Path = Path("server/data/levels.json")
UPSTASH_URL = os.environ.get("UPSTASH_REDIS_REST_URL", "").strip().rstrip("/")
UPSTASH_TOKEN = os.environ.get("UPSTASH_REDIS_REST_TOKEN", "").strip()
UPSTASH_KEY = (
    os.environ.get("UPSTASH_REDIS_KEY", "holy-moley-levels").strip()
    or "holy-moley-levels"
)


class StoreError(RuntimeError):
    """Raised when the optional remote store cannot be reached."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def clean_text(value, max_length: int) -> str:
    if not isinstance(value, str):
        return ""
    # Keep normal text, including line breaks in descriptions, but strip control
    # characters so a payload cannot smuggle terminal or HTML tricks into logs.
    cleaned = "".join(
        ch for ch in value if ch in "\n\r\t" or ord(ch) >= 32
    ).strip()
    return cleaned[:max_length]


def clean_line(value, max_length: int) -> str:
    """Collapse whitespace for names and author handles."""
    return " ".join(clean_text(value, max_length).split())


def remote_store_enabled() -> bool:
    return bool(UPSTASH_URL or UPSTASH_TOKEN)


def upstash_command(*args) -> object:
    """Run one Redis command through Upstash's HTTPS REST API."""
    if not UPSTASH_URL or not UPSTASH_TOKEN:
        raise StoreError(
            "set both UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN"
        )
    body = json.dumps(
        list(args), ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    request = urllib.request.Request(
        UPSTASH_URL,
        data=body,
        headers={
            "Authorization": f"Bearer {UPSTASH_TOKEN}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")[:300]
        raise StoreError(f"Upstash HTTP {exc.code}: {detail}") from exc
    except OSError as exc:
        raise StoreError(f"Upstash request failed: {exc}") from exc
    try:
        parsed = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise StoreError("Upstash returned invalid JSON") from exc
    if not isinstance(parsed, dict):
        raise StoreError("Upstash returned an unexpected response")
    if parsed.get("error"):
        raise StoreError(f"Upstash error: {parsed['error']}")
    return parsed.get("result")


def parse_store(raw: str, source: str) -> dict:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Could not read {source}: {exc}") from exc
    if not isinstance(parsed, dict) or not isinstance(parsed.get("levels"), dict):
        raise SystemExit(f"{source} is not a level store")
    parsed.setdefault("version", 1)
    return parsed


def load_store() -> dict:
    if remote_store_enabled():
        raw = upstash_command("GET", UPSTASH_KEY)
        if raw is None or raw == "":
            return {"version": 1, "levels": {}}
        if not isinstance(raw, str):
            raise SystemExit(f"Upstash key {UPSTASH_KEY!r} is not a text value")
        return parse_store(raw, f"Upstash key {UPSTASH_KEY!r}")
    if not DATA_FILE.exists():
        return {"version": 1, "levels": {}}
    try:
        raw = DATA_FILE.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise SystemExit(f"Could not read {DATA_FILE}: {exc}") from exc
    return parse_store(raw, str(DATA_FILE))


def save_store() -> None:
    serialized = json.dumps(STORE, ensure_ascii=False, separators=(",", ":"))
    if remote_store_enabled():
        upstash_command("SET", UPSTASH_KEY, serialized)
        return
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    temporary = DATA_FILE.with_suffix(".json.tmp")
    temporary.write_text(serialized, encoding="utf-8")
    os.replace(temporary, DATA_FILE)


def validate_level(level) -> str | None:
    if not isinstance(level, dict):
        return "level must be an object"
    if not isinstance(level.get("blocks"), list):
        return "level.blocks must be an array"
    if not isinstance(level.get("enemies"), list):
        return "level.enemies must be an array"
    if len(level["blocks"]) > MAX_BLOCKS:
        return f"level.blocks is too large ({MAX_BLOCKS} max)"
    if len(level["enemies"]) > MAX_ENEMIES:
        return f"level.enemies is too large ({MAX_ENEMIES} max)"
    props = level.get("props", [])
    if props is not None and not isinstance(props, list):
        return "level.props must be an array"
    if isinstance(props, list) and len(props) > MAX_PROPS:
        return f"level.props is too large ({MAX_PROPS} max)"
    return None


def summary(record: dict) -> dict:
    data = record.get("data", {})
    blocks = data.get("blocks", []) if isinstance(data, dict) else []
    enemies = data.get("enemies", []) if isinstance(data, dict) else []
    return {
        "id": record["id"],
        "name": record["name"],
        "author": record["author"],
        "description": record["description"],
        "created_at": record["created_at"],
        "downloads": int(record.get("downloads", 0)),
        "blocks": len(blocks) if isinstance(blocks, list) else 0,
        "enemies": len(enemies) if isinstance(enemies, list) else 0,
    }


def list_levels(limit: int, offset: int) -> tuple[list[dict], int]:
    levels = sorted(
        STORE["levels"].values(),
        key=lambda entry: (entry.get("created_at", ""), entry.get("id", "")),
        reverse=True,
    )
    total = len(levels)
    window = levels[offset : offset + limit]
    return [summary(entry) for entry in window], total


def create_level(payload: dict) -> tuple[dict | None, str | None]:
    if not isinstance(payload, dict):
        return None, "body must be a JSON object"
    error = validate_level(payload.get("level"))
    if error:
        return None, error
    record = {
        "id": secrets.token_hex(6),
        "name": clean_line(payload.get("name"), NAME_MAX) or "Untitled Level",
        "author": clean_line(payload.get("author"), AUTHOR_MAX) or "Anonymous",
        "description": clean_text(payload.get("description"), DESCRIPTION_MAX),
        "created_at": utc_now(),
        "downloads": 0,
        "data": payload["level"],
    }
    STORE["levels"][record["id"]] = record
    try:
        save_store()
    except StoreError:
        # Do not leave a level in memory that the client was told failed to save.
        STORE["levels"].pop(record["id"], None)
        raise
    return summary(record), None


def get_level(level_id: str, count_download: bool = True) -> dict | None:
    record = STORE["levels"].get(level_id)
    if record is None:
        return None
    if count_download:
        previous = int(record.get("downloads", 0))
        record["downloads"] = previous + 1
        try:
            save_store()
        except StoreError as exc:
            # Download counts are nice-to-have; never fail a load because the
            # counter could not be written.
            record["downloads"] = previous
            print(f"[levels] could not persist download count: {exc}")
    return record


def render_gallery() -> str:
    with STORE_LOCK:
        levels, total = list_levels(100, 0)
    rows = []
    for entry in levels:
        description = html.escape(entry["description"] or "No description.")
        rows.append(
            "<article>"
            f"<h2><a href=\"/api/levels/{entry['id']}\">{html.escape(entry['name'])}</a></h2>"
            f"<p class=\"meta\">by {html.escape(entry['author'])} &middot; "
            f"{html.escape(entry['created_at'][:10])} &middot; "
            f"{entry['downloads']} downloads &middot; "
            f"{entry['blocks']} blocks &middot; {entry['enemies']} enemies</p>"
            f"<p>{description}</p>"
            "</article>"
        )
    body = "\n".join(rows) or "<p>No levels have been published yet.</p>"
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Holy Moley Community Levels</title>
<style>
  body {{ margin: 0; background: #1a120e; color: #f8e6cc; font: 17px/1.5 system-ui, sans-serif; }}
  main {{ max-width: 760px; margin: 0 auto; padding: 40px 20px 80px; }}
  h1 {{ color: #ffd36f; margin-bottom: 4px; }}
  .sub {{ color: #b8a58c; margin-top: 0; }}
  article {{ border-top: 1px solid #55402d; padding: 18px 0; }}
  h2 {{ margin: 0 0 4px; font-size: 1.25rem; }}
  a {{ color: #ffd36f; }}
  .meta {{ color: #b8a58c; font-size: .9rem; margin: 0 0 8px; }}
</style>
</head>
<body><main>
<h1>Holy Moley Community Levels</h1>
<p class="sub">{total} published level(s). Open one to download its JSON.</p>
{body}
</main></body></html>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "HolyMoleyLevels/1.0"

    def log_message(self, fmt: str, *args) -> None:
        print(f"[levels] {self.address_string()} {fmt % args}")

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Max-Age", "86400")

    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, status: int, body: str) -> None:
        encoded = body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded)))
        self._cors()
        self.end_headers()
        self.wfile.write(encoded)

    def _read_json(self) -> tuple[dict | None, str | None]:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None, "invalid Content-Length"
        if length <= 0:
            return None, "request body is required"
        if length > MAX_BODY_BYTES:
            return None, f"request body is too large ({MAX_BODY_BYTES} bytes max)"
        raw = self.rfile.read(length)
        try:
            parsed = json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return None, "body must be valid JSON"
        if not isinstance(parsed, dict):
            return None, "body must be a JSON object"
        return parsed, None

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        if path == "/health":
            self._send_json(200, {"ok": True})
            return
        if path == "/":
            self._send_html(200, render_gallery())
            return
        if path == "/api/levels":
            query = parse_qs(parsed.query)
            try:
                limit = int(query.get("limit", ["50"])[0])
                offset = int(query.get("offset", ["0"])[0])
            except ValueError:
                self._send_json(400, {"error": "limit and offset must be integers"})
                return
            limit = max(1, min(limit, 100))
            offset = max(0, offset)
            with STORE_LOCK:
                levels, total = list_levels(limit, offset)
            self._send_json(200, {"levels": levels, "total": total})
            return
        if path.startswith("/api/levels/"):
            level_id = path.rsplit("/", 1)[-1]
            if not ID_RE.fullmatch(level_id):
                self._send_json(404, {"error": "level not found"})
                return
            with STORE_LOCK:
                record = get_level(level_id)
            if record is None:
                self._send_json(404, {"error": "level not found"})
                return
            self._send_json(
                200,
                {"level": summary(record), "data": record["data"]},
            )
            return
        self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"
        if path != "/api/levels":
            self._send_json(404, {"error": "not found"})
            return
        payload, error = self._read_json()
        if error:
            self._send_json(400, {"error": error})
            return
        try:
            with STORE_LOCK:
                summary_record, error = create_level(payload)
        except StoreError as exc:
            print(f"[levels] could not save level: {exc}")
            self._send_json(503, {"error": "level storage is unavailable"})
            return
        if error:
            self._send_json(400, {"error": error})
            return
        self._send_json(201, {"level": summary_record})


def main() -> None:
    global DATA_FILE, STORE
    parser = argparse.ArgumentParser(description="Holy Moley community level service")
    parser.add_argument("--host", default=os.environ.get("HOST", "127.0.0.1"))
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("PORT", "8787")),
    )
    parser.add_argument("--data-dir", default=str(Path(__file__).resolve().parent / "data"))
    args = parser.parse_args()

    if bool(UPSTASH_URL) != bool(UPSTASH_TOKEN):
        raise SystemExit(
            "Set both UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN, "
            "or neither for local file storage."
        )
    DATA_FILE = Path(args.data_dir) / "levels.json"
    try:
        STORE = load_store()
    except StoreError as exc:
        raise SystemExit(f"Could not load the Upstash level store: {exc}") from exc
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    storage = f"Upstash key {UPSTASH_KEY!r}" if remote_store_enabled() else str(DATA_FILE)
    print(
        f"Holy Moley level service listening on http://{args.host}:{args.port} "
        f"(data: {storage})"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
