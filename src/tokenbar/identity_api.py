from __future__ import annotations

import argparse
import json
import os
import re
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


IDENTITY_FIELDS = {
    "schema",
    "generatedAt",
    "title",
    "subtitle",
    "primaryArchetype",
    "npcClass",
    "identityLabel",
    "labelRationale",
    "archetypeDistribution",
    "modifierDistribution",
    "stanceDistribution",
    "labelDistribution",
    "labelModel",
    "specificityScore",
    "estimatedRarityPercent",
    "proofScore",
    "loopMaturity",
    "loopScore",
    "loopScale",
    "dimensions",
    "signatureMoves",
    "curiousFacts",
    "growthEdge",
    "usage",
    "sessionAnalysis",
    "shippingAnalysis",
    "providerAnalyses",
    "leaderboard",
}

BLOCKED_KEY_PARTS = (
    "path",
    "transcript",
    "sourcecode",
    "source_code",
    "secret",
    "credential",
    "rawcontent",
    "raw_content",
)
BLOCKED_KEYS = {
    "token",
    "email",
    "prompt",
    "prompts",
    "prompttext",
    "prompt_text",
    "promptcontent",
    "prompt_content",
}
LOCAL_PATH_RE = re.compile(
    r"(?:/Users/[^/\s]+|/home/[^/\s]+|/private/var|/var/folders|/tmp)(?:/[^\s\"']*)?"
)
SECRET_RE = re.compile(r"\b(?:sk|whsec|ghp|github_pat|xox[baprs])[-_][A-Za-z0-9_-]{8,}\b")


def support_dir() -> Path:
    override = os.environ.get("TOKENBAR_SUPPORT_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / "Library/Application Support/CodexLimitBar"


def latest_identity(root: Path) -> Path | None:
    candidates = list((root / "profiles").glob("*.identity.json"))
    return max(candidates, key=lambda item: item.stat().st_mtime) if candidates else None


def _blocked_key(key: str) -> bool:
    normalized = key.replace("-", "_").lower()
    return normalized in BLOCKED_KEYS or any(part in normalized for part in BLOCKED_KEY_PARTS)


def sanitize(value: Any, *, key: str = "", depth: int = 0) -> Any:
    if depth > 8:
        return None
    if key and _blocked_key(key):
        return None
    if value is None or isinstance(value, (bool, int, float)):
        return value
    if isinstance(value, str):
        text = LOCAL_PATH_RE.sub("[local path]", value.replace("\x00", ""))
        text = SECRET_RE.sub("[redacted secret]", text)
        return text[:1200]
    if isinstance(value, list):
        cleaned = [sanitize(item, depth=depth + 1) for item in value[:100]]
        return [item for item in cleaned if item is not None]
    if isinstance(value, dict):
        cleaned: dict[str, Any] = {}
        for child_key, child_value in list(value.items())[:100]:
            name = str(child_key)[:100]
            safe_value = sanitize(child_value, key=name, depth=depth + 1)
            if safe_value is not None:
                cleaned[name] = safe_value
        return cleaned
    return str(value)[:1200]


def privacy_receipt() -> dict[str, Any]:
    return {
        "schema": "tokenbar.safe_local_api.v1",
        "localOnlyByDefault": True,
        "rawTranscriptsIncluded": False,
        "sourceCodeIncluded": False,
        "localPathsIncluded": False,
        "secretsIncluded": False,
        "material": "generated identity fields and aggregate usage only",
    }


def identity_payload(root: Path) -> dict[str, Any] | None:
    path = latest_identity(root)
    if not path:
        return None
    try:
        source = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(source, dict):
        return None
    privacy = source.get("privacy") if isinstance(source.get("privacy"), dict) else {}
    if privacy.get("rawTranscriptsIncluded") or privacy.get("sourceCodeIncluded"):
        return None
    selected = {name: source[name] for name in IDENTITY_FIELDS if name in source}
    return {
        "ok": True,
        "identity": sanitize(selected),
        "privacy": privacy_receipt(),
    }


def _safe_number(value: Any) -> int:
    try:
        return max(0, int(float(value or 0)))
    except (TypeError, ValueError):
        return 0


def stats_payload(root: Path) -> dict[str, Any]:
    index_path = root / "usage-index.json"
    try:
        index = json.loads(index_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        index = {}
    if not isinstance(index, dict):
        index = {}

    day_tokens = index.get("dayTokens") if isinstance(index.get("dayTokens"), dict) else {}
    model_tokens = index.get("modelTokens") if isinstance(index.get("modelTokens"), dict) else {}
    sessions = index.get("sessionPaths") if isinstance(index.get("sessionPaths"), list) else []
    folders = index.get("activeFolderPaths") if isinstance(index.get("activeFolderPaths"), list) else []
    safe_days = {str(day)[:32]: _safe_number(tokens) for day, tokens in list(day_tokens.items())[-90:]}
    safe_models = {str(model)[:100]: _safe_number(tokens) for model, tokens in list(model_tokens.items())[:50]}
    total_tokens = sum(safe_models.values()) or sum(safe_days.values())
    return {
        "ok": True,
        "stats": {
            "updatedAt": index.get("updatedAt"),
            "totalTokens": total_tokens,
            "sessionCount": len(sessions),
            "activeDayCount": sum(1 for value in safe_days.values() if value > 0),
            "activeFolderCount": len(folders),
            "dayTokens": safe_days,
            "modelTokens": safe_models,
        },
        "privacy": privacy_receipt(),
    }


def bundle_payload(root: Path) -> dict[str, Any]:
    identity = identity_payload(root)
    return {
        "ok": bool(identity),
        "schema": "tokenbar.builder_bundle.v1",
        "generatedAt": time.time(),
        "identity": identity.get("identity") if identity else None,
        "stats": stats_payload(root)["stats"],
        "privacy": privacy_receipt(),
    }


class IdentityApiHandler(BaseHTTPRequestHandler):
    root: Path = support_dir()
    allowed_origin: str = ""
    server_version = "TokenBarIdentityAPI/0.1"

    def log_message(self, fmt: str, *args: object) -> None:
        if os.environ.get("TOKENBAR_API_QUIET") == "1":
            return
        super().log_message(fmt, *args)

    def do_OPTIONS(self) -> None:
        self._respond(204, None)

    def do_GET(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"
        if path in {"/", "/v1"}:
            self._respond(
                200,
                {
                    "ok": True,
                    "service": "tokenbar-safe-local-api",
                    "resources": ["/v1/identity", "/v1/stats", "/v1/bundle", "/health"],
                    "privacy": privacy_receipt(),
                },
            )
        elif path == "/health":
            self._respond(200, {"ok": True, "service": "tokenbar-safe-local-api"})
        elif path == "/v1/identity":
            payload = identity_payload(self.root)
            self._respond(200 if payload else 404, payload or {"ok": False, "error": "no safe identity report found"})
        elif path == "/v1/stats":
            self._respond(200, stats_payload(self.root))
        elif path == "/v1/bundle":
            payload = bundle_payload(self.root)
            self._respond(200 if payload["ok"] else 404, payload)
        else:
            self._respond(404, {"ok": False, "error": "not found"})

    def _respond(self, status: int, body: dict[str, Any] | None) -> None:
        payload = b"" if body is None else json.dumps(body, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if self.allowed_origin:
            self.send_header("Access-Control-Allow-Origin", self.allowed_origin)
            self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Accept, Content-Type")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if payload:
            self.wfile.write(payload)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Expose TokenBar's safe generated identity and aggregate stats locally.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=int(os.environ.get("TOKENBAR_API_PORT", "8769")))
    parser.add_argument("--allow-remote", action="store_true", help="Allow a non-loopback bind. Use only on a trusted network.")
    parser.add_argument("--snapshot", action="store_true", help="Print the safe combined bundle and exit.")
    parser.add_argument("--output", help="Write --snapshot JSON to this file instead of stdout.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = support_dir()
    if args.snapshot:
        payload = json.dumps(bundle_payload(root), indent=2, sort_keys=True) + "\n"
        if args.output:
            target = Path(args.output).expanduser()
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(payload, encoding="utf-8")
            print(f"TokenBar safe identity bundle: {target}")
        else:
            print(payload, end="")
        return 0

    if args.host not in {"127.0.0.1", "localhost", "::1"} and not args.allow_remote:
        raise SystemExit("Refusing a remote bind. Use --allow-remote only on a trusted network.")
    IdentityApiHandler.root = root
    IdentityApiHandler.allowed_origin = os.environ.get("TOKENBAR_API_ALLOWED_ORIGIN", "").strip()
    server = ThreadingHTTPServer((args.host, args.port), IdentityApiHandler)
    print(f"TokenBar safe local API: http://{args.host}:{args.port}/v1")
    print("Resources: /v1/identity, /v1/stats, /v1/bundle, /health")
    print("Privacy: generated identity fields + aggregate usage only; no raw logs, source code, paths, or secrets")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
