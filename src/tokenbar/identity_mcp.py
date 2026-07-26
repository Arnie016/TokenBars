from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

try:
    from identity_api import bundle_payload, identity_payload, privacy_receipt, stats_payload, support_dir
except ImportError:  # pragma: no cover - package import path
    from .identity_api import bundle_payload, identity_payload, privacy_receipt, stats_payload, support_dir


PROTOCOL_VERSION = "2025-06-18"
SERVER_VERSION = "0.1.1"
MAX_MESSAGE_BYTES = 2 * 1024 * 1024

TOOLS: list[dict[str, Any]] = [
    {
        "name": "tokenbar_get_builder_identity",
        "title": "Get TokenBar Builder Identity",
        "description": (
            "Read the latest privacy-safe Builder Identity generated on this Mac. "
            "Returns derived archetype, evidence scores, signature moves, and growth edge; "
            "never raw prompts, transcripts, source code, paths, or secrets."
        ),
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "tokenbar_get_usage_stats",
        "title": "Get TokenBar Usage Stats",
        "description": (
            "Read aggregate local TokenBar usage: token totals, session count, active days, "
            "and model/day rollups. No session text or local paths are returned."
        ),
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
    {
        "name": "tokenbar_get_builder_bundle",
        "title": "Get TokenBar Builder Bundle",
        "description": (
            "Read one inspectable bundle containing the latest safe Builder Identity, current "
            "aggregate usage, generation time, and an explicit privacy receipt."
        ),
        "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False},
    },
]


def _number(value: Any) -> int:
    try:
        return max(0, int(float(value or 0)))
    except (TypeError, ValueError):
        return 0


def _compact_tokens(value: Any) -> str:
    tokens = _number(value)
    if tokens >= 1_000_000_000:
        return f"{tokens / 1_000_000_000:.2f}B"
    if tokens >= 1_000_000:
        return f"{tokens / 1_000_000:.1f}M"
    if tokens >= 1_000:
        return f"{tokens / 1_000:.1f}K"
    return str(tokens)


def _identity_summary(payload: dict[str, Any]) -> str:
    identity = payload.get("identity") if isinstance(payload.get("identity"), dict) else {}
    usage = identity.get("usage") if isinstance(identity.get("usage"), dict) else {}
    title = str(identity.get("title") or "Builder Identity")
    subtitle = str(identity.get("subtitle") or "No safe identity narrative is available yet.")
    proof = _number(identity.get("proofScore"))
    loop = _number(identity.get("loopScore"))
    sessions = _number(usage.get("sessionsIndexed"))
    return (
        f"{title}\n{subtitle}\n"
        f"Evidence: {sessions} analyzed sessions · proof {proof}/100 · loop {loop}/100.\n"
        "Privacy: generated identity fields only; no raw prompts, transcripts, source code, paths, or secrets."
    )


def _stats_summary(payload: dict[str, Any]) -> str:
    stats = payload.get("stats") if isinstance(payload.get("stats"), dict) else {}
    return (
        "Current TokenBar aggregate usage: "
        f"{_compact_tokens(stats.get('totalTokens'))} tokens · "
        f"{_number(stats.get('sessionCount'))} sessions · "
        f"{_number(stats.get('activeDayCount'))} active days.\n"
        "Privacy: aggregate counts only; no session text or local paths."
    )


def _bundle_summary(payload: dict[str, Any]) -> str:
    identity = payload.get("identity") if isinstance(payload.get("identity"), dict) else {}
    stats = payload.get("stats") if isinstance(payload.get("stats"), dict) else {}
    usage = identity.get("usage") if isinstance(identity.get("usage"), dict) else {}
    return (
        f"{identity.get('title') or 'TokenBar Builder Identity'}\n"
        f"{_number(usage.get('sessionsIndexed'))} sessions in the analyzed profile · "
        f"{_number(stats.get('sessionCount'))} sessions currently indexed · "
        f"{_compact_tokens(stats.get('totalTokens'))} aggregate tokens.\n"
        "The structured result includes the identity, current stats, and privacy receipt."
    )


def _tool_result(payload: dict[str, Any], summary: str, *, is_error: bool = False) -> dict[str, Any]:
    return {
        "content": [{"type": "text", "text": summary}],
        "structuredContent": payload,
        "isError": is_error,
    }


def call_tool(name: str, arguments: Any, root: Path) -> dict[str, Any]:
    if arguments not in (None, {}) or (arguments is not None and not isinstance(arguments, dict)):
        raise ValueError("This read-only tool does not accept arguments.")
    if name == "tokenbar_get_builder_identity":
        payload = identity_payload(root)
        if payload is None:
            missing = {
                "ok": False,
                "error": "No safe Builder Identity report found. Run tokenbar claim first.",
                "privacy": privacy_receipt(),
            }
            return _tool_result(missing, missing["error"], is_error=True)
        return _tool_result(payload, _identity_summary(payload))
    if name == "tokenbar_get_usage_stats":
        payload = stats_payload(root)
        return _tool_result(payload, _stats_summary(payload))
    if name == "tokenbar_get_builder_bundle":
        payload = bundle_payload(root)
        if not payload.get("ok"):
            return _tool_result(
                payload,
                "No safe Builder Identity report found. Run tokenbar claim first.",
                is_error=True,
            )
        return _tool_result(payload, _bundle_summary(payload))
    raise KeyError(name)


def _success(request_id: Any, result: dict[str, Any]) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": request_id, "result": result}


def _error(request_id: Any, code: int, message: str, data: Any = None) -> dict[str, Any]:
    error: dict[str, Any] = {"code": code, "message": message}
    if data is not None:
        error["data"] = data
    return {"jsonrpc": "2.0", "id": request_id, "error": error}


def handle_message(message: Any, root: Path) -> dict[str, Any] | None:
    if not isinstance(message, dict) or message.get("jsonrpc") != "2.0":
        return _error(message.get("id") if isinstance(message, dict) else None, -32600, "Invalid Request")
    method = message.get("method")
    request_id = message.get("id")
    if not isinstance(method, str):
        return _error(request_id, -32600, "Invalid Request")

    if request_id is None:
        return None
    if method == "initialize":
        return _success(
            request_id,
            {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "tokenbar-builder-identity", "version": SERVER_VERSION},
                "instructions": (
                    "Use these read-only tools to understand the local builder's generated identity "
                    "and aggregate TokenBar usage. Never infer access to raw prompts, transcripts, source code, or secrets."
                ),
            },
        )
    if method == "ping":
        return _success(request_id, {})
    if method == "tools/list":
        return _success(request_id, {"tools": TOOLS})
    if method == "tools/call":
        params = message.get("params")
        if not isinstance(params, dict) or not isinstance(params.get("name"), str):
            return _error(request_id, -32602, "Invalid params")
        try:
            result = call_tool(params["name"], params.get("arguments", {}), root)
        except KeyError:
            return _error(request_id, -32602, f"Unknown tool: {params['name']}")
        except ValueError as exc:
            return _error(request_id, -32602, str(exc))
        return _success(request_id, result)
    return _error(request_id, -32601, "Method not found")


def _write(message: dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(message, separators=(",", ":"), ensure_ascii=False) + "\n")
    sys.stdout.flush()


def main() -> int:
    root = support_dir()
    for raw_line in sys.stdin.buffer:
        if len(raw_line) > MAX_MESSAGE_BYTES:
            _write(_error(None, -32600, "Message exceeds the 2 MB limit"))
            continue
        if not raw_line.strip():
            continue
        try:
            message = json.loads(raw_line)
        except (UnicodeDecodeError, json.JSONDecodeError):
            _write(_error(None, -32700, "Parse error"))
            continue
        response = handle_message(message, root)
        if response is not None:
            try:
                _write(response)
            except BrokenPipeError:
                return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
