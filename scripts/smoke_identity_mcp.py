#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = Path(os.environ.get("TOKENBAR_MCP_CLI", str(ROOT / "bin/tokenbar"))).expanduser()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def request(request_id: int, method: str, params: dict | None = None) -> dict:
    message: dict = {"jsonrpc": "2.0", "id": request_id, "method": method}
    if params is not None:
        message["params"] = params
    return message


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="tokenbar-identity-mcp-") as temp:
        support = Path(temp) / "support"
        profiles = support / "profiles"
        profiles.mkdir(parents=True)
        identity = {
            "schema": "tokenbar.identity.v1",
            "title": "Fixture Systems Cartographer",
            "subtitle": "Turns uncertain terrain into inspectable systems.",
            "primaryArchetype": "Systems Cartographer",
            "proofScore": 73,
            "loopScore": 68,
            "dimensions": [{"name": "Steering", "score": 81, "commandPromptRatio": 0.8}],
            "signatureMoves": ["Closes with inspectable proof"],
            "curiousFacts": [{"label": "Redirect rhythm", "value": "3 turns", "copy": "You steer early."}],
            "growthEdge": "Make the verification receipt easier to inspect.",
            "usage": {"sessionsIndexed": 12, "totalTokens": 24000},
            "sessionAnalysis": {
                "sessionCount": 12,
                "prompt": "never return this raw prompt",
                "sourcePath": "/Users/example/private/repo",
                "note": "Built at /Users/example/private/repo with sk-secret123456789",
            },
            "privacy": {"rawTranscriptsIncluded": False, "sourceCodeIncluded": False},
            "token": "TBAR-SHOULD-NOT-LEAK",
            "email": "owner@example.com",
        }
        (profiles / "fixture.identity.json").write_text(json.dumps(identity), encoding="utf-8")
        (support / "usage-index.json").write_text(
            json.dumps(
                {
                    "updatedAt": 1234,
                    "dayTokens": {"2026-07-22": 2000},
                    "modelTokens": {"gpt-test": 2000},
                    "sessionPaths": ["/Users/example/private/session.jsonl"],
                    "activeFolderPaths": ["/Users/example/private/repo"],
                }
            ),
            encoding="utf-8",
        )

        messages = [
            request(
                1,
                "initialize",
                {
                    "protocolVersion": "2025-06-18",
                    "capabilities": {},
                    "clientInfo": {"name": "tokenbar-smoke", "version": "1"},
                },
            ),
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            request(2, "tools/list"),
            request(3, "tools/call", {"name": "tokenbar_get_builder_identity", "arguments": {}}),
            request(4, "tools/call", {"name": "tokenbar_get_usage_stats", "arguments": {}}),
            request(5, "tools/call", {"name": "tokenbar_get_builder_bundle", "arguments": {}}),
            request(6, "ping"),
            request(7, "tools/call", {"name": "tokenbar_unknown", "arguments": {}}),
        ]
        stdin = "".join(json.dumps(message, separators=(",", ":")) + "\n" for message in messages)
        env = os.environ.copy()
        env["TOKENBAR_SUPPORT_DIR"] = str(support)
        completed = subprocess.run(
            [str(CLI), "mcp"],
            cwd=ROOT,
            env=env,
            input=stdin,
            capture_output=True,
            text=True,
            check=True,
            timeout=10,
        )
        require(not completed.stderr, f"MCP wrote unexpected stderr: {completed.stderr}")
        responses = [json.loads(line) for line in completed.stdout.splitlines() if line.strip()]
        require(len(responses) == 7, "notifications must not receive a response")
        by_id = {response.get("id"): response for response in responses}

        require(by_id[1]["result"]["protocolVersion"] == "2025-06-18", "protocol negotiation failed")
        require(by_id[1]["result"]["capabilities"] == {"tools": {"listChanged": False}}, "capabilities mismatch")
        names = [tool["name"] for tool in by_id[2]["result"]["tools"]]
        require(
            names
            == [
                "tokenbar_get_builder_identity",
                "tokenbar_get_usage_stats",
                "tokenbar_get_builder_bundle",
            ],
            "tool list is incomplete or unstable",
        )

        identity_result = by_id[3]["result"]
        stats_result = by_id[4]["result"]
        bundle_result = by_id[5]["result"]
        require(identity_result["structuredContent"]["identity"]["title"] == "Fixture Systems Cartographer", "identity missing")
        require("12 analyzed sessions" in identity_result["content"][0]["text"], "identity summary missing evidence")
        require(stats_result["structuredContent"]["stats"]["sessionCount"] == 1, "safe usage count mismatch")
        require(bundle_result["structuredContent"]["schema"] == "tokenbar.builder_bundle.v1", "bundle schema mismatch")
        require(bundle_result["structuredContent"]["privacy"]["secretsIncluded"] is False, "privacy receipt missing")
        require(by_id[6]["result"] == {}, "ping failed")
        require(by_id[7]["error"]["code"] == -32602, "unknown tool must return Invalid params")

        serialized = completed.stdout
        require("/Users/" not in serialized, "local path leaked")
        require("sk-secret" not in serialized, "secret leaked")
        require("never return this raw prompt" not in serialized, "raw prompt leaked")
        require("owner@example.com" not in serialized, "email leaked")
        require("TBAR-SHOULD-NOT-LEAK" not in serialized, "identity token leaked")

    print("TokenBar Builder Identity MCP smoke passed")
    print("  protocol: JSON-RPC 2.0 over newline-delimited stdio · MCP 2025-06-18")
    print("  tools: builder identity, aggregate usage stats, combined safe bundle")
    print("  privacy: hostile prompt, source path, email, token, and secret excluded")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"TokenBar Builder Identity MCP smoke failed: {exc}", file=sys.stderr)
        raise
