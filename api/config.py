from __future__ import annotations

import json
import os
from http.server import BaseHTTPRequestHandler


class handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        publishable_key = (
            os.environ.get("NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY")
            or os.environ.get("CLERK_PUBLISHABLE_KEY")
            or ""
        ).strip()
        body = {
            "clerk": {
                "enabled": bool(publishable_key),
                "publishableKey": publishable_key,
            }
        }
        payload = json.dumps(body, sort_keys=True).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)
