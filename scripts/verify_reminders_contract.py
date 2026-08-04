#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def run_json(cli: Path, env: dict[str, str]) -> dict:
    result = subprocess.run(
        [str(cli), "reminders", "json"],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} reminders json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def validate_payload(payload: dict, label: str) -> None:
    require(payload.get("schema") == "tokenbar.reminders.v1", f"{label} schema mismatch")
    require(payload.get("source") == "local-usage-index", f"{label} source mismatch")
    reminders = payload.get("reminders") or []
    privacy = payload.get("privacy") or {}
    runway = payload.get("runwayBrief") or {}
    require(reminders, f"{label} reminders missing")
    require(payload.get("topReminder"), f"{label} top reminder missing")
    require(runway.get("title") == "Budget brief before the next run", f"{label} runway brief title missing")
    require(runway.get("delivery") == "suggested-only", f"{label} runway brief should be suggested-only")
    require(runway.get("approvalRequired") is True, f"{label} runway brief must require approval")
    require(runway.get("scheduledNotifications") is False, f"{label} runway brief must not schedule notifications")
    require("Budget:" in (runway.get("setupPrompt") or ""), f"{label} runway setup prompt missing budget")
    commands = runway.get("commands") or {}
    require(commands.get("copyPrompt") == "tokenbar playbooks copy budget-runway", f"{label} runway copy command drifted")
    require(commands.get("openReminders") == "tokenbar reminders json", f"{label} runway reminder command drifted")
    require(any(item.get("kind") == "budget" for item in reminders), f"{label} missing budget reminder")
    require(any(item.get("kind") == "forecast" for item in reminders), f"{label} missing forecast reminder")
    require(any(item.get("kind") == "cost" for item in reminders), f"{label} missing cost reminder")
    require(all(item.get("requiresApproval") is True for item in reminders), f"{label} reminders must require approval")
    require(all(item.get("delivery") == "suggested-only" for item in reminders), f"{label} reminders should be suggested-only")
    for key in [
        "rawPromptsIncluded",
        "rawTranscriptsIncluded",
        "sourceCodeIncluded",
        "localPathsIncluded",
        "credentialsIncluded",
        "networkActions",
        "scheduledNotifications",
    ]:
        require(privacy.get(key) is False, f"{label} privacy {key} should be false")
    serialized = json.dumps(payload, sort_keys=True)
    for forbidden in ["/Users/", "session-a.jsonl", "PRIVATE_PROMPT", "sk-", "arnav@example.com"]:
        require(forbidden not in serialized, f"{label} leaked forbidden marker {forbidden}")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="tokenbar-reminders-") as temp:
        home = Path(temp) / "home"
        support = home / "Library" / "Application Support" / "CodexLimitBar"
        support.mkdir(parents=True)
        today = datetime.now().strftime("%Y-%m-%d")
        (support / "usage-index.json").write_text(
            json.dumps(
                {
                    "updatedAt": 1780000000,
                    "dayTokens": {
                        "2026-07-20": 20_000_000,
                        "2026-07-21": 80_000_000,
                        "2026-07-22": 150_000_000,
                        "2026-07-23": 190_000_000,
                        today: 190_000_000,
                    },
                    "modelTokens": {"gpt-5.4": 300_000_000, "opencode": 140_000_000},
                    "folderTokens": {"/Users/example/private/agent-lab": 440_000_000},
                    "folderSessionPaths": {"/Users/example/private/agent-lab": ["/Users/example/private/session-a.jsonl"]},
                    "activeFolderPaths": ["/Users/example/private/agent-lab"],
                    "sessionPaths": ["/Users/example/private/session-a.jsonl"],
                }
            ),
            encoding="utf-8",
        )
        (support / "user-controls.json").write_text(
            json.dumps(
                {
                    "logTrackingEnabled": True,
                    "activitySignalsEnabled": True,
                    "dailyGuardrailTokens": "100M",
                    "weeklyGuardrailTokens": "300M",
                    "thirtyDayGuardrailTokens": "1B",
                    "dailyCostLimitUSD": "20",
                    "weeklyCostLimitUSD": "40",
                }
            ),
            encoding="utf-8",
        )

        env = os.environ.copy()
        env["HOME"] = str(home)
        env["TOKENBAR_SUPPORT_DIR"] = str(support)
        env["TOKENBAR_PRICE_PER_MILLION"] = "150"

        src_payload = run_json(SRC_CLI, env)
        bin_payload = run_json(BIN_CLI, env)
        validate_payload(src_payload, "src")
        validate_payload(bin_payload, "bin")
        require(src_payload["summary"]["projectedNext7"] == bin_payload["summary"]["projectedNext7"], "src/bin reminder forecast drifted")

    print("reminders_contract: PASS")


if __name__ == "__main__":
    main()
