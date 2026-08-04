#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BIN_CLI = ROOT / "bin" / "tokenbar"
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def run_provider_json(cli: Path, support: Path) -> dict:
    env = os.environ.copy()
    env["TOKENBAR_SUPPORT_DIR"] = str(support)
    result = subprocess.run(
        [str(cli), "providers", "json"],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} providers json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def run_provider_text(cli: Path, support: Path) -> str:
    env = os.environ.copy()
    env["TOKENBAR_SUPPORT_DIR"] = str(support)
    result = subprocess.run(
        [str(cli), "providers"],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} providers failed: {result.stderr or result.stdout}")
    return result.stdout


def validate_payload(payload: dict, label: str) -> None:
    require(payload.get("schema") == "tokenbar.provider_truth.v1", f"{label} schema mismatch")
    providers = payload.get("providers") or []
    names = [item.get("name") for item in providers]
    require(names == ["Codex", "Claude Code", "Cursor", "Antigravity", "OpenCode"], f"{label} provider list mismatch")
    require("Gemini" not in names, f"{label} must not include Gemini")
    privacy = payload.get("privacy") or {}
    for key in ["providerCalls", "accountMutation", "browserCookies", "credentials", "rawPrompts", "externalActions"]:
        require(privacy.get(key) is False, f"{label} privacy {key} should be false")
    for provider in providers:
        require(provider.get("status") in {"measured", "setup"}, f"{label} bad provider status")
        require(provider.get("command") in {"tokenbar usage", "tokenbar providers"}, f"{label} bad provider command")
        require(provider.get("evidenceNeeded"), f"{label} missing evidenceNeeded")
        flow = provider.get("setupFlow") or []
        require([step.get("label") for step in flow] == ["Detect", "Connect", "Review"], f"{label} setup flow mismatch")
    status = {item["name"]: item["status"] for item in providers}
    require(status["Codex"] == "measured", f"{label} Codex should be measured")
    require(status["OpenCode"] == "measured", f"{label} OpenCode should be measured")
    require(status["Claude Code"] == "setup", f"{label} Claude Code should stay setup")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="tokenbar-provider-cli-") as temp:
        support = Path(temp)
        (support / "usage-index.json").write_text(
            json.dumps(
                {
                    "modelTokens": {"codex": 5000, "opencode": 2000},
                    "dayTokens": {"2026-08-03": 7000},
                    "sessionPaths": [],
                    "activeFolderPaths": [],
                }
            ),
            encoding="utf-8",
        )
        src_payload = run_provider_json(SRC_CLI, support)
        bin_payload = run_provider_json(BIN_CLI, support)
        validate_payload(src_payload, "src")
        validate_payload(bin_payload, "bin")
        require(src_payload == bin_payload, "src/bin provider JSON drifted")
        text = run_provider_text(BIN_CLI, support)
        for marker in ["TokenBar provider truth", "Codex: measured", "OpenCode: measured", "Claude Code: setup", "Detect", "Connect", "Review", "No provider API calls"]:
            require(marker in text, f"text output missing {marker}")
        require("Gemini" not in text, "text output must not include Gemini")

    print("provider_cli_contract: PASS")


if __name__ == "__main__":
    main()
