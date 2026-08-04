#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"
INDEX = ROOT / "docs" / "index.html"
CSS = ROOT / "docs" / "styles.css"
README = ROOT / "README.md"


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def run_json(cli):
    result = subprocess.run(
        [str(cli), "ecosystem", "json"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} ecosystem json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def run_text(cli):
    result = subprocess.run(
        [str(cli), "ecosystem"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} ecosystem failed: {result.stderr or result.stdout}")
    return result.stdout


def validate_payload(payload, label):
    require(payload.get("schema") == "tokenbar.ecosystem.v1", f"{label} schema mismatch")
    require(payload.get("product") == "TokenBar", f"{label} product mismatch")

    surfaces = payload.get("surfaces") or []
    surface_names = {surface.get("name") for surface in surfaces}
    for name in ["Menu Bar", "CLI", "Mac App", "Web App"]:
        require(name in surface_names, f"{label} missing surface {name}")

    lanes = payload.get("nextTechnologies") or []
    lane_names = {lane.get("name") for lane in lanes}
    require(lane_names == {"Browser Companion", "Local Automation Relay"}, f"{label} next technology lanes mismatch")
    lane_text = " ".join(
        " ".join(str(lane.get(key, "")) for key in ["why", "safeBoundary", "firstExperiment"])
        for lane in lanes
    ).lower()
    for marker in ["codex", "github", "product hunt", "memory pressure", "explicit approval", "read-only", "browser-companion", "tokenbar browser-companion"]:
        require(marker in lane_text, f"{label} next technology copy missing {marker}")

    business = payload.get("businessLayer") or {}
    require("premium playbooks" in " ".join(business.get("pro") or []), f"{label} pro layer missing premium playbooks")
    require("Stripe" in business.get("paymentGate", ""), f"{label} payment gate missing Stripe boundary")
    handoff = payload.get("handoff") or {}
    require(handoff.get("installCommand", "").startswith("curl -fsSL https://raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh"), f"{label} install command points away from TokenBar")
    require(handoff.get("downloadUrl", "").endswith("/Arnie016/TokenBar/main/install.sh"), f"{label} download URL should default to live install script")
    journey = payload.get("handoffJourney") or []
    require([row.get("step") for row in journey] == ["Install", "Open icon bar", "Start local API", "Open Mac studio"], f"{label} handoff journey order mismatch")
    journey_text = " ".join(
        " ".join(str(row.get(key, "")) for key in ["surface", "command", "userValue", "safeBoundary"])
        for row in journey
    )
    for marker in [
        "macOS icon-bar",
        "active account",
        "tokenbar api",
        "127.0.0.1",
        "browser companion",
        "proof packets",
        "Does not sign into providers",
        "no provider account mutation",
        "no content scripts",
        "Public proof remains review-first",
    ]:
        require(marker in journey_text, f"{label} handoff journey missing {marker}")

    relay = payload.get("surfaceRelay") or []
    require([row.get("key") for row in relay] == ["cli", "menu", "companion", "studio", "pro"], f"{label} surface relay order mismatch")
    relay_text = " ".join(
        " ".join(str(row.get(key, "")) for key in ["surface", "command", "tier", "gate", "value"])
        for row in relay
    )
    for marker in [
        "CLI evidence line",
        "Menu-bar cockpit",
        "Browser context rail",
        "Mac studio archive",
        "Pro proof market",
        "tokenbar usage",
        "tokenbar status",
        "tokenbar api",
        "tokenbar proof-packet",
        "tokenbar playbooks",
        "No provider sign-in",
        "127.0.0.1 only",
        "Review before share",
        "No auto-billing",
        "Paid prompt playbooks",
    ]:
        require(marker in relay_text, f"{label} surface relay missing {marker}")


def main():
    src_payload = run_json(SRC_CLI)
    bin_payload = run_json(BIN_CLI)
    validate_payload(src_payload, "src")
    validate_payload(bin_payload, "bin")
    require(src_payload["nextTechnologies"] == bin_payload["nextTechnologies"], "src/bin ecosystem payload drifted")
    require(src_payload["surfaceRelay"] == bin_payload["surfaceRelay"], "src/bin ecosystem relay drifted")

    text_output = run_text(SRC_CLI)
    for marker in ["TokenBar ecosystem", "Surface relay", "Pro proof market", "No auto-billing", "Browser Companion", "Local Automation Relay", "Business layer", "Install journey", "tokenbar launch-kit", "tokenbar api"]:
        require(marker in text_output, f"text ecosystem output missing {marker}")

    index = INDEX.read_text()
    css = CSS.read_text()
    readme = README.read_text()
    for marker in [
        'id="ecosystem"',
        "One signal layer across every AI coding surface.",
        "Browser Companion",
        "Local Automation Relay",
        "tokenbar ecosystem",
        "tokenbar browser-companion",
        "No content scripts",
        "No process closing, browser restore, webhook, or external action without approval.",
        "https://raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh",
    ]:
        require(marker in index, f"homepage ecosystem missing {marker}")
    for marker in [".ecosystem-band", ".ecosystem-map", ".ecosystem-node", ".ecosystem-lane"]:
        require(marker in css, f"ecosystem CSS missing {marker}")
    require("github.com/Arnie016/TokenBars/releases" not in readme, "README still points to stale TokenBars release")
    require("curl -fsSL https://raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh | bash" in readme, "README missing live install command")

    print("ecosystem_contract: PASS")


if __name__ == "__main__":
    main()
