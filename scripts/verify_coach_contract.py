#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def run_json(cli):
    result = subprocess.run(
        [str(cli), "coach", "json"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} coach json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def run_text(cli):
    result = subprocess.run(
        [str(cli), "coach"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} coach failed: {result.stderr or result.stdout}")
    return result.stdout


def validate_payload(payload, label):
    require(payload.get("schema") == "tokenbar.coach.v1", f"{label} schema mismatch")
    require(payload.get("product") == "TokenBar", f"{label} product mismatch")
    require("before your next AI coding run" in payload.get("question", ""), f"{label} missing MCQ question")

    choices = payload.get("choices") or []
    keys = [choice.get("key") for choice in choices]
    require(keys == ["install", "analyze", "budget", "playbook", "proof"], f"{label} choice order mismatch")
    commands = " ".join(choice.get("command", "") for choice in choices)
    for marker in [
        "raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh",
        "tokenbar usage",
        "tokenbar reminders",
        "tokenbar playbooks copy budget-runway",
        "tokenbar proof-packet",
    ]:
        require(marker in commands, f"{label} choices missing {marker}")

    recommended = payload.get("recommended") or {}
    require(recommended.get("key") in keys, f"{label} recommended choice is not one of the choices")

    bridge_commands = " ".join(row.get("command", "") for row in payload.get("commands") or [])
    for marker in ["tokenbar open", "tokenbar api", "tokenbar browser-companion", "tokenbar runway"]:
        require(marker in bridge_commands, f"{label} bridge commands missing {marker}")

    privacy = payload.get("privacy") or {}
    for key in [
        "rawPrompts",
        "transcripts",
        "sourceCode",
        "credentials",
        "providerCalls",
        "accountMutation",
        "externalActions",
        "scheduledNotifications",
    ]:
        require(privacy.get(key) is False, f"{label} privacy flag {key} must be false")
    disclaimer = payload.get("disclaimer", "")
    for marker in [
        "Suggested-only local guide",
        "does not schedule reminders",
        "change accounts",
        "call providers",
        "publish proof",
        "enable payments",
        "close apps",
        "upload private work",
    ]:
        require(marker in disclaimer, f"{label} disclaimer missing {marker}")


def main():
    src_payload = run_json(SRC_CLI)
    bin_payload = run_json(BIN_CLI)
    validate_payload(src_payload, "src")
    validate_payload(bin_payload, "bin")
    require(src_payload["choices"] == bin_payload["choices"], "src/bin coach choices drifted")

    text_output = run_text(SRC_CLI)
    for marker in [
        "TokenBar coach",
        "What should TokenBar help with",
        "Recommended",
        "Other choices",
        "Bridge commands",
        "Suggested-only local guide",
    ]:
        require(marker in text_output, f"text coach output missing {marker}")

    help_output = subprocess.run(
        [str(SRC_CLI), "help"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    ).stdout
    require("tokenbar coach" in help_output, "help output missing coach command")
    require("Machine-readable suggested-only decision guide" in help_output, "help output missing coach json copy")

    print("coach_contract: PASS")


if __name__ == "__main__":
    main()
