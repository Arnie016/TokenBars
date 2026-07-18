#!/usr/bin/env python3
"""Minimal TokenBar Stripe fulfillment webhook.

Environment:
  STRIPE_WEBHOOK_SECRET=whsec_...
  TOKENBAR_ENTITLEMENTS_PATH=./tokenbar-entitlements.json
  AGENTMAIL_API_KEY=am_...                  optional
  AGENTMAIL_INBOX_ID=tokenbar@agentmail.to  optional

Run:
  python3 scripts/tokenbar_fulfillment_webhook.py --port 8787
"""

from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


def verify_stripe_signature(payload: bytes, header: str, secret: str) -> bool:
    parts = dict(part.split("=", 1) for part in header.split(",") if "=" in part)
    timestamp = parts.get("t")
    signature = parts.get("v1")
    if not timestamp or not signature:
        return False
    signed = f"{timestamp}.".encode("utf-8") + payload
    expected = hmac.new(secret.encode("utf-8"), signed, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def load_entitlements(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_entitlements(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def send_agentmail(to: str, subject: str, text: str) -> None:
    api_key = os.environ.get("AGENTMAIL_API_KEY")
    inbox_id = os.environ.get("AGENTMAIL_INBOX_ID")
    if not api_key or not inbox_id:
        return
    request = urllib.request.Request(
        f"https://api.agentmail.to/v0/inboxes/{inbox_id}/messages/send",
        data=json.dumps({"to": to, "subject": subject, "text": text}).encode("utf-8"),
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        urllib.request.urlopen(request, timeout=20).read()
    except urllib.error.HTTPError as exc:
        print(f"AgentMail send failed: HTTP {exc.code} {exc.read().decode('utf-8', 'replace')}")
    except Exception as exc:
        print(f"AgentMail send failed: {exc}")


def email_from_event(event: dict) -> str | None:
    obj = event.get("data", {}).get("object", {})
    details = obj.get("customer_details") or {}
    return details.get("email") or obj.get("customer_email") or obj.get("email")


def update_entitlement(event: dict) -> dict | None:
    event_type = event.get("type")
    obj = event.get("data", {}).get("object", {})
    email = email_from_event(event)
    if not email and event_type.startswith("customer.subscription."):
        # Subscription events often carry customer IDs, not emails. Store by subscription ID.
        email = f"stripe-customer:{obj.get('customer', 'unknown')}"
    if not email:
        return None

    active_types = {
        "checkout.session.completed",
        "customer.subscription.created",
        "customer.subscription.updated",
        "invoice.paid",
    }
    inactive_types = {
        "customer.subscription.deleted",
        "customer.subscription.paused",
    }
    if event_type not in active_types and event_type not in inactive_types:
        return None

    active = event_type in active_types
    status = obj.get("status")
    if status in {"canceled", "unpaid", "paused", "incomplete_expired"}:
        active = False

    return {
        "email": email,
        "active": active,
        "stripe_event": event_type,
        "stripe_customer": obj.get("customer"),
        "stripe_subscription": obj.get("subscription") or obj.get("id"),
        "status": status,
        "updated_at": int(time.time()),
    }


class Handler(BaseHTTPRequestHandler):
    def do_POST(self) -> None:
        secret = os.environ.get("STRIPE_WEBHOOK_SECRET")
        if not secret:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b"missing STRIPE_WEBHOOK_SECRET")
            return

        length = int(self.headers.get("content-length", "0"))
        payload = self.rfile.read(length)
        signature = self.headers.get("stripe-signature", "")
        if not verify_stripe_signature(payload, signature, secret):
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"bad signature")
            return

        event = json.loads(payload.decode("utf-8"))
        entitlement = update_entitlement(event)
        if entitlement:
            path = Path(os.environ.get("TOKENBAR_ENTITLEMENTS_PATH", "./tokenbar-entitlements.json"))
            data = load_entitlements(path)
            data[entitlement["email"]] = entitlement
            save_entitlements(path, data)
            if entitlement["active"] and "@" in entitlement["email"]:
                send_agentmail(
                    entitlement["email"],
                    "TokenBar Pro is ready",
                    "Your TokenBar Pro trial is active. Run: tokenbar profile --days 7 --pdf",
                )

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()
    server = HTTPServer(("0.0.0.0", args.port), Handler)
    print(f"TokenBar webhook listening on http://0.0.0.0:{args.port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
