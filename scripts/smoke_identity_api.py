#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "tokenbar"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def get_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=3) as response:
        return json.loads(response.read().decode("utf-8"))


def main() -> None:
    port = int(os.environ.get("TOKENBAR_IDENTITY_API_SMOKE_PORT", "8881"))
    with tempfile.TemporaryDirectory(prefix="tokenbar-identity-api-") as temp:
        support = Path(temp) / "support"
        profiles = support / "profiles"
        profiles.mkdir(parents=True)
        identity = {
            "schema": "tokenbar.identity.v1",
            "title": "Fixture Systems Cartographer",
            "primaryArchetype": "Systems Cartographer",
            "proofScore": 73,
            "dimensions": [{"name": "Steering", "score": 81, "commandPromptRatio": 0.8}],
            "signatureMoves": ["Closes with inspectable proof"],
            "curiousFacts": [{"label": "Redirect rhythm", "value": "3 turns", "copy": "You steer early."}],
            "growthEdge": "Make the verification receipt easier to inspect.",
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
        env = os.environ.copy()
        env["TOKENBAR_SUPPORT_DIR"] = str(support)
        env["TOKENBAR_API_QUIET"] = "1"
        process = subprocess.Popen(
            [str(CLI), "api", "--port", str(port)],
            cwd=ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            base = f"http://127.0.0.1:{port}"
            for _ in range(30):
                try:
                    if get_json(f"{base}/health").get("ok"):
                        break
                except Exception:
                    time.sleep(0.1)
            else:
                raise AssertionError("identity API did not become healthy")

            identity_response = get_json(f"{base}/v1/identity")
            stats_response = get_json(f"{base}/v1/stats")
            bundle_response = get_json(f"{base}/v1/bundle")
            serialized = json.dumps(bundle_response, sort_keys=True)

            require(identity_response["identity"]["title"] == "Fixture Systems Cartographer", "identity title missing")
            require(identity_response["identity"]["dimensions"][0]["commandPromptRatio"] == 0.8, "safe aggregate prompt ratio removed")
            require(identity_response["identity"]["signatureMoves"][0] == "Closes with inspectable proof", "safe signature move missing")
            require(identity_response["identity"]["curiousFacts"][0]["value"] == "3 turns", "safe curious fact missing")
            require(stats_response["stats"]["sessionCount"] == 1, "session count mismatch")
            require(stats_response["stats"]["activeFolderCount"] == 1, "folder count mismatch")
            require("/Users/" not in serialized, "local path leaked")
            require("sk-secret" not in serialized, "secret leaked")
            require("never return this raw prompt" not in serialized, "raw prompt leaked")
            require("owner@example.com" not in serialized, "email leaked")
            require("TBAR-SHOULD-NOT-LEAK" not in serialized, "identity token leaked")
            require(bundle_response["privacy"]["rawTranscriptsIncluded"] is False, "privacy receipt missing")

            snapshot = subprocess.run(
                [str(CLI), "api", "--snapshot"],
                cwd=ROOT,
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            require(json.loads(snapshot.stdout)["schema"] == "tokenbar.builder_bundle.v1", "snapshot schema mismatch")
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)

    print("TokenBar safe identity API smoke passed")
    print("  routes: /v1/identity, /v1/stats, /v1/bundle, /health")
    print("  privacy: no raw prompt, transcript, source code, local path, email, token, or secret")
    print("  packaging: tokenbar api --snapshot returned tokenbar.builder_bundle.v1")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"TokenBar safe identity API smoke failed: {exc}", file=sys.stderr)
        raise
