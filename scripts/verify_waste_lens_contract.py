#!/usr/bin/env python3
"""Verify TokenBar's aggregate-only waste lens CLI contract."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def run_cli(cli: Path, *args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run([str(cli), "waste", *args], cwd=ROOT, text=True, capture_output=True, timeout=35)


def run_json(cli: Path) -> dict:
    result = run_cli(cli, "json")
    require(result.returncode == 0, f"{cli} waste json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def validate_payload(payload: dict, label: str) -> None:
    require(payload.get("schema") == "tokenbar.waste_lens.v1", f"{label} schema mismatch")
    require(payload.get("source") == "local-aggregate-usage-shape", f"{label} source mismatch")
    score = payload.get("score")
    require(isinstance(score, int) and 0 <= score <= 100, f"{label} score out of range")
    require(payload.get("label") in {"Clear", "Watch", "High"}, f"{label} label mismatch")
    require(payload.get("primaryDriver"), f"{label} primary driver missing")
    summary = payload.get("summary") or {}
    for key in ["today", "last7", "last30", "activeDays30", "peakRecent", "basis"]:
        require(key in summary, f"{label} summary missing {key}")
    require("does not judge output quality" in summary.get("basis", ""), f"{label} basis must reject quality claims")
    levers = payload.get("levers") or []
    require(len(levers) == 3, f"{label} should expose exactly three levers")
    commands = {lever.get("command") for lever in levers}
    for command in ["tokenbar playbooks copy mission-lock", "tokenbar playbooks copy output-budget", "tokenbar cost-passport"]:
        require(command in commands, f"{label} missing lever command {command}")
    privacy = payload.get("privacy") or {}
    for key in ["readOnly"]:
        require(privacy.get(key) is True, f"{label} privacy {key} should be true")
    for key in ["rawPrompts", "rawTranscripts", "sourceCode", "localPaths", "credentials", "providerCalls", "accountMutation", "externalActions", "qualityJudgment"]:
        require(privacy.get(key) is False, f"{label} privacy {key} should be false")
    serialized = json.dumps(payload, sort_keys=True)
    for forbidden in ["/Users/", "sk-", "never leak", "transcript excerpt", "providerAnalyses", "signaturePhrases"]:
        require(forbidden not in serialized, f"{label} leaked forbidden marker {forbidden}")


def main() -> None:
    src_payload = run_json(SRC_CLI)
    bin_payload = run_json(BIN_CLI)
    validate_payload(src_payload, "src")
    validate_payload(bin_payload, "bin")
    require(src_payload == bin_payload, "src/bin waste lens payload drifted")

    text_result = run_cli(BIN_CLI)
    require(text_result.returncode == 0, f"tokenbar waste failed: {text_result.stderr or text_result.stdout}")
    for marker in [
        "TokenBar waste lens",
        "Saver levers",
        "Scope before run",
        "Shorten output",
        "Review cost",
        "Privacy: aggregate usage shape only",
        "no raw prompts",
        "output-quality judgment",
    ]:
        require(marker in text_result.stdout, f"text output missing {marker}")

    print("waste_lens_contract: PASS")


if __name__ == "__main__":
    main()
