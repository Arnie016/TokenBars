#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "docs" / "index.html"
CSS = ROOT / "docs" / "styles.css"
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def run_payload(cli):
    with tempfile.TemporaryDirectory(prefix="tokenbar-memory-pressure-") as temp:
        result = subprocess.run(
            [str(cli), "memory-pressure", "json"],
            cwd=ROOT,
            env={"HOME": temp, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"},
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=45,
            check=False,
        )
    require(result.returncode == 0, f"{cli} memory-pressure json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def check_payload(payload, label):
    require(payload.get("schema") == "tokenbar.memory_pressure.v1", f"{label} schema mismatch")
    require(payload.get("source") == "local-ps-aggregate", f"{label} source mismatch")
    summary = payload.get("summary") or {}
    require(summary.get("pressure") in {"clear", "watch", "high", "unknown"}, f"{label} invalid pressure")
    require("process names and RSS only" in summary.get("basis", ""), f"{label} missing safe basis")
    require(isinstance(payload.get("categories"), list), f"{label} categories missing")
    require(isinstance(payload.get("topApps"), list), f"{label} top apps missing")
    actions = payload.get("actions") or []
    require(actions, f"{label} actions missing")
    require(all(item.get("approvalRequired") is True for item in actions), f"{label} actions must require approval")
    require(all(any(marker in item.get("safeNext", "").lower() for marker in ["approval", "approve", "rerun"]) for item in actions), f"{label} safe next must preserve approval")
    privacy = payload.get("privacy") or {}
    for key in [
        "rawPromptsIncluded",
        "rawTranscriptsIncluded",
        "sourceCodeIncluded",
        "localPathsIncluded",
        "commandArgumentsIncluded",
        "credentialsIncluded",
        "browserTabsIncluded",
        "processKill",
        "browserRestore",
        "externalActions",
    ]:
        require(privacy.get(key) is False, f"{label} privacy flag should be false: {key}")
    disclaimer = payload.get("disclaimer", "")
    for marker in ["read-only", "does not close apps", "restore windows", "contact providers", "change accounts"]:
        require(marker in disclaimer, f"{label} disclaimer missing {marker}")


def main():
    src_payload = run_payload(SRC_CLI)
    bin_payload = run_payload(BIN_CLI)
    check_payload(src_payload, "src")
    check_payload(bin_payload, "bin")

    index = INDEX.read_text()
    css = CSS.read_text()
    required_html = [
        'id="memory-pressure"',
        'class="memory-pressure-surface"',
        "Local Automation Relay",
        "Explain overload before asking to clean anything.",
        "tokenbar memory-pressure json",
        "No apps closed",
        "no browser windows restored",
        "no process",
        "no browser tabs",
        "no prompts",
        "no source code",
        "no credentials",
        "no external actions",
        "tokenbar memory-pressure",
    ]
    for marker in required_html:
        require(marker in index, f"homepage missing memory marker: {marker}")

    required_css = [
        ".memory-pressure-surface",
        ".memory-pressure-stage",
        ".memory-orbit",
        ".memory-dot",
        ".memory-lane-stack",
        ".memory-pressure-boundary",
        ".dot-browser",
        ".dot-agent",
        ".dot-runtime",
    ]
    for marker in required_css:
        require(marker in css, f"CSS missing memory marker: {marker}")

    print("memory_pressure_contract: PASS")


if __name__ == "__main__":
    main()
