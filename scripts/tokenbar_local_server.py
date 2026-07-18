#!/usr/bin/env python3
"""Local TokenBar proof server for judge and smoke-test flows.

Routes the same lightweight API handlers used by the hosted app and serves the
static docs pages. This is intentionally local-only and uses JSON file stores
unless Supabase env vars are explicitly configured.
"""

from __future__ import annotations

import argparse
import mimetypes
import os
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
sys.path.insert(0, str(ROOT))

from api import actions, profiles, report_feedback  # noqa: E402


ROUTE_FILES = {
    "/": "index.html",
    "/index": "index.html",
    "/social": "social.html",
    "/rankings": "rankings.html",
    "/profile": "profile.html",
    "/archetypes": "archetypes.html",
    "/docs": "docs.html",
}


class TokenBarLocalHandler(BaseHTTPRequestHandler):
    server_version = "TokenBarLocal/0.1"

    def log_message(self, fmt: str, *args: object) -> None:
        if os.environ.get("TOKENBAR_LOCAL_SERVER_QUIET") == "1":
            return
        super().log_message(fmt, *args)

    def do_OPTIONS(self) -> None:
        self._dispatch_api()

    def do_GET(self) -> None:
        if self._dispatch_api():
            return
        self._serve_static()

    def do_HEAD(self) -> None:
        if self._dispatch_api():
            return
        self._serve_static(send_body=False)

    def do_POST(self) -> None:
        if self._dispatch_api():
            return
        self.send_error(404, "not found")

    def _dispatch_api(self) -> bool:
        path = urlparse(self.path).path.rstrip("/") or "/"
        if path == "/api/actions":
            actions.handler(self)
            return True
        if path == "/api/profiles":
            if self.command == "GET":
                profiles.handler.do_GET(self)
            elif self.command == "POST":
                profiles.handler.do_POST(self)
            elif self.command == "OPTIONS":
                profiles.handler.do_OPTIONS(self)
            else:
                self.send_error(405, "method not allowed")
            return True
        if path == "/api/report-feedback":
            if self.command == "POST":
                report_feedback.handler.do_POST(self)
            elif self.command == "OPTIONS":
                report_feedback.handler.do_OPTIONS(self)
            else:
                self.send_error(405, "method not allowed")
            return True
        return False

    def _serve_static(self, send_body: bool = True) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        relative = ROUTE_FILES.get(path)
        if not relative:
            relative = path.lstrip("/")
        target = (DOCS / relative).resolve()
        if not str(target).startswith(str(DOCS.resolve())) or not target.is_file():
            self.send_error(404, "not found")
            return
        data = target.read_bytes()
        content_type = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
        if target.suffix == ".js":
            content_type = "text/javascript"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if send_body:
            self.wfile.write(data)


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the local TokenBar proof server.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=int(os.environ.get("PORT", "8768")))
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), TokenBarLocalHandler)
    print(f"TokenBar local proof server: http://{args.host}:{args.port}")
    print("Routes: /api/actions, /api/profiles, /api/report-feedback, /social, /rankings, /profile")
    server.serve_forever()


if __name__ == "__main__":
    main()
