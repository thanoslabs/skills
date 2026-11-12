#!/usr/bin/env python3
"""Local web dashboard for coordinate work items, across every repo.

Serves assets/dashboard.html and a read-only JSON view of the state
directory. Binds to 127.0.0.1 only and never writes anything.

Requires: python3 (standard library only).

Usage:
  dashboard.py [--port 8765] [--open]

Endpoints:
  /                                      the board
  /api/items                             every item's state plus each file's status line and summary
  /api/file?repo=<repo>&id=<id>&name=<f> one of the item's Markdown files, as plain text
"""

import argparse
import json
import os
import re
import sys
import webbrowser
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

SKILL_DIR = Path(__file__).resolve().parents[1]
PAGE = SKILL_DIR / "assets" / "dashboard.html"
# Files the board may show, in pipeline order.
FILES = ["spec.md", "plan.md", "build.md", "checks.md", "review.md", "pr-body.md"]
REPO_RE = re.compile(r"^[A-Za-z0-9._-]{1,200}$")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{0,63}$")
STATE_FIELDS = ["id", "title", "group", "part", "summary", "ticket", "source", "stage",
                "awaiting", "mode", "publish", "base", "branch", "pr", "approvals",
                "attempts", "escalation", "updated_at"]


def state_root():
    explicit = os.environ.get("COORDINATE_STATE_DIR")
    if explicit:
        return Path(explicit)
    xdg = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(xdg) / "coordinate"


def file_digest(path):
    """The status line (if the file has one) and the ## Summary bullets."""
    lines = path.read_text(errors="replace").splitlines()
    first = lines[0].strip() if lines else ""
    status = first if re.match(r"^(STATUS|CHECKS|VERDICT):", first) else None
    summary, inside = [], False
    for line in lines:
        if line.startswith("## "):
            if inside:
                break
            inside = line.strip() == "## Summary"
        elif inside and line.lstrip().startswith("- "):
            summary.append(line.lstrip()[2:].strip())
    return {"status": status, "summary": summary[:5],
            "mtime": datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()}


def load_items(root):
    items, problems = [], []
    for state in sorted(root.glob("*/*/state.json")):
        item_dir = state.parent
        try:
            data = json.loads(state.read_text())
        except (OSError, ValueError) as e:
            problems.append(f"{item_dir.parent.name}/{item_dir.name}: unreadable state.json ({e})")
            continue
        item = {k: data.get(k) for k in STATE_FIELDS}
        item["id"] = item["id"] or item_dir.name
        item["repo"] = item_dir.parent.name
        item["files"] = {name: file_digest(item_dir / name)
                         for name in FILES if (item_dir / name).is_file()}
        items.append(item)
    return items, problems


class Handler(BaseHTTPRequestHandler):
    root = state_root()
    allowed_hosts = set()

    def log_message(self, *args):
        pass

    def send(self, status, body, content_type):
        data = body.encode() if isinstance(body, str) else body
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy",
                         "default-src 'self'; script-src 'unsafe-inline'; "
                         "style-src 'unsafe-inline'; img-src 'self' data:")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        # Refuse other Host headers so a web page can't reach this server
        # through DNS rebinding.
        if self.headers.get("Host", "") not in self.allowed_hosts:
            return self.send(HTTPStatus.FORBIDDEN, "forbidden host\n", "text/plain")
        url = urlparse(self.path)
        if url.path == "/":
            return self.send(HTTPStatus.OK, PAGE.read_bytes(), "text/html; charset=utf-8")
        if url.path == "/api/items":
            items, problems = load_items(self.root)
            body = json.dumps({"state_root": str(self.root), "items": items, "problems": problems,
                               "generated_at": datetime.now(timezone.utc).isoformat()})
            return self.send(HTTPStatus.OK, body, "application/json")
        if url.path == "/api/file":
            q = {k: v[0] for k, v in parse_qs(url.query).items()}
            repo, item_id, name = q.get("repo", ""), q.get("id", ""), q.get("name", "")
            if not (REPO_RE.match(repo) and ID_RE.match(item_id) and name in FILES):
                return self.send(HTTPStatus.BAD_REQUEST, "bad request\n", "text/plain")
            path = (self.root / repo / item_id / name).resolve()
            if self.root.resolve() not in path.parents:
                return self.send(HTTPStatus.BAD_REQUEST, "bad request\n", "text/plain")
            if not path.is_file():
                return self.send(HTTPStatus.NOT_FOUND, "not found\n", "text/plain")
            return self.send(HTTPStatus.OK, path.read_bytes(), "text/plain; charset=utf-8")
        self.send(HTTPStatus.NOT_FOUND, "not found\n", "text/plain")


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--port", type=int, default=8765)
    p.add_argument("--open", action="store_true", help="open the board in a browser")
    args = p.parse_args()

    Handler.allowed_hosts = {f"127.0.0.1:{args.port}", f"localhost:{args.port}"}
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    except OSError as e:
        sys.exit(f"dashboard.py: can't listen on 127.0.0.1:{args.port} ({e.strerror}); try --port")
    url = f"http://127.0.0.1:{args.port}/"
    print(f"coordinate dashboard: {url}  (state: {Handler.root})", flush=True)
    if args.open:
        webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
