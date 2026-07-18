from __future__ import annotations

import hashlib
import hmac
import json
import os
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler


ACTIVE_EVENTS = {
    "checkout.session.completed",
    "customer.subscription.created",
    "customer.subscription.updated",
    "invoice.paid",
}

INACTIVE_EVENTS = {
    "customer.subscription.deleted",
    "customer.subscription.paused",
    "invoice.payment_failed",
}


def respond(handler: BaseHTTPRequestHandler, status: int, body: dict) -> None:
    payload = json.dumps(body, sort_keys=True).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(payload)))
    handler.end_headers()
    handler.wfile.write(payload)


def verify_stripe_signature(payload: bytes, header: str, secret: str) -> bool:
    try:
        parts = dict(part.split("=", 1) for part in header.split(",") if "=" in part)
    except ValueError:
        return False

    timestamp = parts.get("t")
    signature = parts.get("v1")
    if not timestamp or not signature:
        return False

    try:
        if abs(time.time() - int(timestamp)) > 300:
            return False
    except ValueError:
        return False

    signed = f"{timestamp}.".encode("utf-8") + payload
    expected = hmac.new(secret.encode("utf-8"), signed, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


def email_from_event(event: dict) -> str | None:
    obj = event.get("data", {}).get("object", {})
    details = obj.get("customer_details") or {}
    return details.get("email") or obj.get("customer_email") or obj.get("email")


def entitlement_from_event(event: dict) -> dict | None:
    event_type = event.get("type")
    if event_type not in ACTIVE_EVENTS and event_type not in INACTIVE_EVENTS:
        return None

    obj = event.get("data", {}).get("object", {})
    email = email_from_event(event)
    if not email and str(event_type).startswith("customer.subscription."):
        email = f"stripe-customer:{obj.get('customer', 'unknown')}"
    if not email:
        return None

    active = event_type in ACTIVE_EVENTS
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


def send_agentmail(to: str, entitlement: dict) -> None:
    api_key = os.environ.get("AGENTMAIL_API_KEY")
    inbox_id = os.environ.get("AGENTMAIL_INBOX_ID")
    if not api_key or not inbox_id or "@" not in to:
        return

    subject = "TokenBar Pro is ready" if entitlement["active"] else "TokenBar Pro billing needs attention"
    text = (
        "Your TokenBar Pro trial is active.\n\n"
        "Run this locally:\n"
        "tokenbar profile --days 7 --pdf\n"
    )
    if not entitlement["active"]:
        text = (
            "TokenBar received a billing update that may affect your Pro access.\n\n"
            "If this looks wrong, reply to this email and we will help."
        )

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


def forward_entitlement(entitlement: dict) -> None:
    target = os.environ.get("TOKENBAR_ENTITLEMENTS_WEBHOOK_URL")
    token = os.environ.get("TOKENBAR_ENTITLEMENTS_WEBHOOK_TOKEN")
    if not target:
        return

    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    request = urllib.request.Request(
        target,
        data=json.dumps(entitlement).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        urllib.request.urlopen(request, timeout=20).read()
    except Exception as exc:
        print(f"Entitlement forward failed: {exc}")


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        respond(self, 200, {"ok": True, "service": "tokenbar-stripe-webhook"})

    def do_POST(self):
        secret = os.environ.get("STRIPE_WEBHOOK_SECRET")
        if not secret:
            respond(self, 500, {"ok": False, "error": "missing STRIPE_WEBHOOK_SECRET"})
            return

        length = int(self.headers.get("content-length", "0"))
        payload = self.rfile.read(length)
        signature = self.headers.get("stripe-signature", "")

        if not verify_stripe_signature(payload, signature, secret):
            respond(self, 400, {"ok": False, "error": "bad signature"})
            return

        try:
            event = json.loads(payload.decode("utf-8"))
        except json.JSONDecodeError:
            respond(self, 400, {"ok": False, "error": "invalid json"})
            return

        entitlement = entitlement_from_event(event)
        if entitlement:
            forward_entitlement(entitlement)
            send_agentmail(entitlement["email"], entitlement)

        respond(self, 200, {"ok": True, "handled": bool(entitlement)})
