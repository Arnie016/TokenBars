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
        [str(cli), "launch-kit", "json"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} launch-kit json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def run_text(cli):
    result = subprocess.run(
        [str(cli), "launch-kit"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} launch-kit failed: {result.stderr or result.stdout}")
    return result.stdout


def validate_payload(payload, label):
    require(payload.get("schema") == "tokenbar.launch_kit.v1", f"{label} schema mismatch")
    product = payload.get("product") or {}
    require(product.get("name") == "TokenBar", f"{label} product name missing")
    require(product.get("primaryCommand") == "tokenbar usage", f"{label} primary command missing")
    require(product.get("costCommand") == "tokenbar cost-passport", f"{label} cost command missing")
    require(product.get("remindersCommand") == "tokenbar reminders", f"{label} reminders command missing")
    require(product.get("proofCommand") == "tokenbar prove", f"{label} proof command missing")
    require(product.get("proofPacketCommand") == "tokenbar proof-packet", f"{label} proof packet command missing")
    require(product.get("playbooksCommand") == "tokenbar playbooks", f"{label} playbooks command missing")
    require("Product Hunt" not in product.get("oneLiner", ""), f"{label} one-liner should describe product, not a launch surface")

    ph = payload.get("productHunt") or {}
    require("menu bar" in ph.get("tagline", "").lower(), f"{label} Product Hunt tagline missing menu bar positioning")
    require("budgets" in ph.get("description", "").lower(), f"{label} Product Hunt description missing budgets")
    require("proof" in ph.get("description", "").lower(), f"{label} Product Hunt description missing proof")

    macapp = payload.get("macappSupply") or {}
    require(macapp.get("category") == "Productivity", f"{label} Macapp category missing")
    require("macOS menu bar" in macapp.get("shortDescription", ""), f"{label} Macapp copy missing macOS menu bar")

    beats = (payload.get("demoVideo") or {}).get("beats") or []
    require(len(beats) == 7, f"{label} demo video should have seven beats")
    beat_text = " ".join(beat.get("line", "") + " " + beat.get("shot", "") for beat in beats).lower()
    for marker in ["account", "forecast", "budget", "cost", "playbooks", "proof"]:
        require(marker in beat_text, f"{label} demo beats missing {marker}")

    gates = payload.get("approvalGates") or []
    gate_text = " ".join(gates).lower()
    for marker in ["do not submit", "do not enable stripe", "do not upload raw transcripts", "explicit user approval"]:
        require(marker in gate_text, f"{label} approval gates missing {marker}")

    checklist = payload.get("checklist") or []
    require(len(checklist) >= 6, f"{label} checklist too short")
    checklist_text = " ".join(item.get("item", "") + " " + item.get("proof", "") for item in checklist)
    require("Install handoff resolves" in checklist_text, f"{label} checklist missing install handoff")
    require("tokenbar copy-install" in checklist_text, f"{label} checklist missing copy-install proof")
    require("Cost passport works" in checklist_text, f"{label} checklist missing cost passport")
    require("tokenbar cost-passport json" in checklist_text, f"{label} checklist missing cost passport proof")
    require("Launch proof packet works" in checklist_text, f"{label} checklist missing launch proof packet")
    require("tokenbar proof-packet json" in checklist_text, f"{label} checklist missing proof packet proof")
    require("Reminder plan works" in checklist_text, f"{label} checklist missing reminder plan")
    require("tokenbar reminders json" in checklist_text, f"{label} checklist missing reminder proof")


def main():
    src_payload = run_json(SRC_CLI)
    bin_payload = run_json(BIN_CLI)
    validate_payload(src_payload, "src")
    validate_payload(bin_payload, "bin")
    require(src_payload["productHunt"]["tagline"] == bin_payload["productHunt"]["tagline"], "src/bin launch copy drifted")

    text_output = run_text(SRC_CLI)
    for marker in ["Product Hunt", "Macapp Supply", "60-second demo arc", "Approval gates", "tokenbar proof-packet", "No external submission is performed"]:
        require(marker in text_output, f"text launch kit missing {marker}")

    index = INDEX.read_text()
    css = CSS.read_text()
    for marker in [
        'id="launch-kit"',
        "Draft the launch without posting anything.",
        "Product Hunt",
        "Macapp Supply",
        "tokenbar launch-kit",
        "tokenbar cost-passport",
        "tokenbar reminders",
        "No auto-submit. No raw logs. No surprise billing.",
        'class="launch-demo-reel"',
        "TokenBar 60-second demo storyboard",
        "Your AI work becomes a proof story.",
        "Menu-bar opens over Codex",
        "Account and provider lanes",
        "Forecast with error bars",
        "Cost passport and reminders",
        "Proof card",
    ]:
        require(marker in index, f"homepage launch kit missing {marker}")
    require(index.count("<article>") >= 7, "homepage should include storyboard article cards")
    for marker in [
        ".launch-kit-band",
        ".launch-kit-grid",
        ".launch-kit-copy",
        ".launch-demo-reel",
        ".launch-demo-strip",
        ".launch-demo-strip article::before",
    ]:
        require(marker in css, f"launch kit CSS missing {marker}")

    print("launch_kit_contract: PASS")


if __name__ == "__main__":
    main()
