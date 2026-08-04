#!/usr/bin/env python3
import json
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"
IDENTITY_API = ROOT / "src" / "tokenbar" / "identity_api.py"
INDEX = ROOT / "docs" / "index.html"
CSS = ROOT / "docs" / "styles.css"


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def run_json(cli):
    result = subprocess.run(
        [str(cli), "proof-packet", "json"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} proof-packet json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def run_text(cli):
    result = subprocess.run(
        [str(cli), "proof-packet"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} proof-packet failed: {result.stderr or result.stdout}")
    return result.stdout


def validate_payload(payload, label):
    require(payload.get("schema") == "tokenbar.launch_proof_packet.v1", f"{label} schema mismatch")
    require(payload.get("title") == "TokenBar Launch Proof Packet", f"{label} title mismatch")
    require("generated proof" in payload.get("headline", ""), f"{label} headline missing proof framing")
    summary = payload.get("summary") or {}
    for key in [
        "sessionCount",
        "activeDayCount",
        "totalTokens",
        "last7Tokens",
        "last30Tokens",
        "measuredProviderCount",
        "setupProviderCount",
        "wasteScore",
        "comparisonState",
        "playbookCount",
    ]:
        require(key in summary, f"{label} summary missing {key}")
    cards = payload.get("cards") or []
    card_keys = {card.get("key") for card in cards}
    require(card_keys == {"usage", "cost", "waste", "comparison", "playbooks"}, f"{label} card keys mismatch: {sorted(card_keys)}")
    commands = " ".join(card.get("command", "") for card in cards) + " " + " ".join(payload.get("commands") or [])
    for command in [
        "tokenbar usage",
        "tokenbar cost-passport json",
        "tokenbar waste json",
        "tokenbar comparison-lens json",
        "tokenbar playbooks json",
        "tokenbar proof-packet json",
        "tokenbar launch-kit",
        "tokenbar runway",
        "tokenbar browser-companion",
    ]:
        require(command in commands, f"{label} missing command {command}")
    gates = " ".join(payload.get("approvalGates") or [])
    for marker in ["No Product Hunt", "No Stripe", "No account switching", "explicit review"]:
        require(marker in gates, f"{label} approval gates missing {marker}")
    blocked = " ".join(payload.get("blockedFields") or [])
    for marker in [
        "raw prompts",
        "transcripts",
        "source code",
        "private diffs",
        "local paths",
        "credentials",
        "provider cookies",
        "official invoice claims",
        "top-percentile claims",
    ]:
        require(marker in blocked, f"{label} blocked fields missing {marker}")
    privacy = payload.get("privacy") or {}
    for flag in [
        "rawPromptsIncluded",
        "rawTranscriptsIncluded",
        "sourceCodeIncluded",
        "localPathsIncluded",
        "credentialsIncluded",
        "providerCalls",
        "paymentActions",
        "externalActions",
        "publicPosting",
    ]:
        require(privacy.get(flag) is False, f"{label} privacy flag must be false: {flag}")
    require("not a submission" in payload.get("disclaimer", ""), f"{label} disclaimer missing no-submit boundary")


def main():
    src_payload = run_json(SRC_CLI)
    bin_payload = run_json(BIN_CLI)
    validate_payload(src_payload, "src")
    validate_payload(bin_payload, "bin")
    require(src_payload["schema"] == bin_payload["schema"], "src/bin proof packet schema drifted")
    require(src_payload["cards"] == bin_payload["cards"], "src/bin proof packet card drifted")

    text = run_text(SRC_CLI)
    for marker in ["TokenBar Launch Proof Packet", "Approval gates", "Blocked from packet", "tokenbar cost-passport json", "tokenbar comparison-lens json"]:
        require(marker in text, f"text proof packet missing {marker}")

    api = IDENTITY_API.read_text()
    for marker in [
        "def proof_packet_payload",
        "/v1/proof-packet",
        "proofPacket",
        "tokenbar.launch_proof_packet.v1",
        "provider cookies",
        "official invoice claims",
        "top-percentile claims without opt-in cohorts",
    ]:
        require(marker in api, f"identity API missing {marker}")

    index = INDEX.read_text()
    for marker in [
        'id="proof-packet"',
        "Launch proof packet",
        "One safe packet for demos, directories, and investor updates.",
        "tokenbar proof-packet json",
        "cohort locked",
        "no-submit",
        "never posts",
        "without an opt-in cohort",
    ]:
        require(marker in index, f"homepage proof packet missing {marker}")

    css = CSS.read_text()
    for marker in [
        ".proof-packet-band",
        ".proof-packet-copy",
        ".proof-packet-card",
        ".proof-packet-seal",
        ".proof-packet-grid",
    ]:
        require(marker in css, f"proof packet CSS missing {marker}")

    print("proof_packet_contract: PASS")


if __name__ == "__main__":
    main()
