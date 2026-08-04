#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"
INDEX = ROOT / "docs" / "index.html"
CSS = ROOT / "docs" / "styles.css"


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def run_json(cli):
    result = subprocess.run(
        [str(cli), "runway", "json"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} runway json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def run_text(cli):
    result = subprocess.run(
        [str(cli), "runway"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} runway failed: {result.stderr or result.stdout}")
    return result.stdout


def validate_payload(payload, label):
    require(payload.get("schema") == "tokenbar.launch_runway.v1", f"{label} schema mismatch")
    require(payload.get("product") == "TokenBar", f"{label} product mismatch")
    principle = payload.get("principle", "")
    require("Launch only what has proof" in principle, f"{label} missing proof-first principle")
    require("explicit approval" in principle, f"{label} missing approval principle")

    rings = payload.get("rings") or []
    states = {ring.get("state") for ring in rings}
    require(states == {"ready", "approval", "pending"}, f"{label} rings must be ready/approval/pending")
    all_items = " ".join(
        item.get("label", "") + " " + item.get("proof", "")
        for ring in rings
        for item in ring.get("items", [])
    )
    for marker in [
        "Website story",
        "Menu-bar contract",
        "Launch proof packet",
        "Product Hunt submission",
        "Macapp Supply submission",
        "Stripe activation",
        "Signed release ZIP",
        "Browser Companion prototype",
        "Local Automation Relay",
    ]:
        require(marker in all_items, f"{label} runway missing {marker}")

    gates = " ".join(payload.get("approvalGates") or [])
    for marker in [
        "No Product Hunt",
        "No Stripe",
        "No account switching",
        "No raw prompts",
    ]:
        require(marker in gates, f"{label} approval gates missing {marker}")

    commands = {row.get("command") for row in payload.get("commands") or []}
    require("tokenbar launch-kit" in commands, f"{label} missing launch-kit command")
    require("tokenbar proof-packet" in commands, f"{label} missing proof packet command")
    require("tokenbar ecosystem" in commands, f"{label} missing ecosystem command")
    require("tokenbar browser-companion" in commands, f"{label} missing browser companion command")
    require(any(str(command).startswith("curl -fsSL https://raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh") for command in commands), f"{label} missing live install command")


def main():
    src_payload = run_json(SRC_CLI)
    bin_payload = run_json(BIN_CLI)
    validate_payload(src_payload, "src")
    validate_payload(bin_payload, "bin")
    require(src_payload["rings"] == bin_payload["rings"], "src/bin runway payload drifted")

    text_output = run_text(SRC_CLI)
    for marker in ["TokenBar launch map", "Demo-ready surfaces", "Needs your review", "Polish before launch", "Approval gates"]:
        require(marker in text_output, f"text runway missing {marker}")

    index = INDEX.read_text()
    css = CSS.read_text()
    for marker in [
        'id="runway"',
        "See what you can demo, what needs your review, and what still needs polish.",
        "tokenbar runway",
        "tokenbar proof-packet",
        "Demo-ready",
        "Needs your review",
        "Polish before launch",
        "No posting, billing, account switching, cleanup, credential use, or",
        "Browser Companion prototype",
        "tokenbar browser-companion",
        "Install handoff",
        "Start in the menu bar. Expand into the studio.",
        "One-line CLI + app installer",
        "Install does not sign into providers",
        "Open icon bar",
        "Start local API",
        "Open Mac studio",
        "tokenbar api",
    ]:
        require(marker in index, f"homepage runway missing {marker}")
    require("Get the ZIP" not in index, "homepage still says ZIP download")
    for marker in [".runway-band", ".runway-board", ".runway-ring", ".runway-command-strip", ".runway-boundary"]:
        require(marker in css, f"runway CSS missing {marker}")

    print("launch_runway_contract: PASS")


if __name__ == "__main__":
    main()
