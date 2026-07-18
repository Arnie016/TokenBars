from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler


MAX_BODY_BYTES = 32_000


def json_response(handler: BaseHTTPRequestHandler, status: int, body: dict) -> None:
    payload = json.dumps(body, sort_keys=True).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Access-Control-Allow-Origin", os.environ.get("TOKENBAR_CORS_ORIGIN", "*"))
    handler.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type")
    handler.send_header("Content-Length", str(len(payload)))
    handler.end_headers()
    handler.wfile.write(payload)


def clean_text(value: object, limit: int) -> str:
    text = str(value or "").replace("\x00", "").strip()
    return text[:limit]


def send_agentmail(feedback: dict) -> bool:
    api_key = os.environ.get("AGENTMAIL_API_KEY")
    inbox_id = os.environ.get("AGENTMAIL_INBOX_ID")
    to = (
        os.environ.get("TOKENBAR_REPORT_FEEDBACK_TO")
        or os.environ.get("AGENTMAIL_FEEDBACK_TO")
        or os.environ.get("TOKENBAR_SUPPORT_EMAIL")
        or ""
    ).strip()
    if not api_key or not inbox_id or "@" not in to:
        return False

    subject = f"TokenBar report feedback: {feedback['category']} ({feedback['token'] or 'no token'})"
    text = "\n".join(
        [
            "TokenBar report feedback",
            "",
            f"Category: {feedback['category']}",
            f"Token: {feedback['token'] or 'not provided'}",
            f"Reporter email: {feedback['email'] or 'not provided'}",
            f"Report URL: {feedback['reportUrl'] or 'not provided'}",
            f"Created at: {feedback['createdAt']}",
            "",
            "Message:",
            feedback["message"],
            "",
            "Privacy boundary: this endpoint should receive only the generated report token, public URL, and user-written feedback. Raw transcripts, source code, credentials, and private files should not be pasted here.",
        ]
    )
    request = urllib.request.Request(
        f"https://api.agentmail.to/v0/inboxes/{inbox_id}/messages/send",
        data=json.dumps({"to": to, "subject": subject, "text": text}).encode("utf-8"),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        urllib.request.urlopen(request, timeout=20).read()
        return True
    except urllib.error.HTTPError as exc:
        print(f"AgentMail report feedback failed: HTTP {exc.code} {exc.read().decode('utf-8', 'replace')}")
    except Exception as exc:
        print(f"AgentMail report feedback failed: {exc}")
    return False


class handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self) -> None:
        json_response(self, 200, {"ok": True})

    def do_POST(self) -> None:
        try:
            length = int(self.headers.get("Content-Length") or "0")
        except ValueError:
            length = 0
        if length <= 0 or length > MAX_BODY_BYTES:
            json_response(self, 413, {"ok": False, "error": "invalid_body_size"})
            return

        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except Exception:
            json_response(self, 400, {"ok": False, "error": "invalid_json"})
            return

        feedback = {
            "category": clean_text(payload.get("category") or "correction", 80),
            "token": clean_text(payload.get("token"), 80),
            "email": clean_text(payload.get("email"), 180),
            "reportUrl": clean_text(payload.get("reportUrl"), 500),
            "message": clean_text(payload.get("message"), 4000),
            "createdAt": int(time.time()),
        }
        if len(feedback["message"]) < 8:
            json_response(self, 400, {"ok": False, "error": "message_required"})
            return

        sent = send_agentmail(feedback)
        json_response(
            self,
            200,
            {
                "ok": True,
                "delivered": sent,
                "message": "Feedback received." if sent else "Feedback accepted locally; AgentMail delivery is not configured.",
            },
        )
