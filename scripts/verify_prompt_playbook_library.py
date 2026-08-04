#!/usr/bin/env python3
import re
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PLAYBOOKS = ROOT / "docs/prompt-playbooks.md"
PAGE = ROOT / "docs/playbooks.html"
VERCEL = ROOT / "vercel.json"
DOCS = ROOT / "docs/docs.html"
SRC_CLI = ROOT / "src/tokenbar/tokenbar"
BIN_CLI = ROOT / "bin/tokenbar"

text = PLAYBOOKS.read_text()
page = PAGE.read_text()
vercel = VERCEL.read_text()
docs = DOCS.read_text()
src_cli = SRC_CLI.read_text()
bin_cli = BIN_CLI.read_text()
entries = re.findall(r"^###\s+\d{3}\.", text, flags=re.MULTILINE)

if len(entries) < 100:
    raise SystemExit(f"FAIL: expected at least 100 playbooks, found {len(entries)}")

required = [
    "Tier: Free",
    "Tier: Pro",
    "Budget:",
    "Context cap:",
    "Stop:",
    "verification",
    "credentials",
    "raw transcripts",
    "source code",
    "Thread Handoff",
    "System Prompt Hardener",
    "Cost Saver Header",
    "Freemium Boundary",
]

for needle in required:
    if needle not in text:
        raise SystemExit(f"FAIL: missing required playbook marker: {needle}")

page_required = [
    "Stop paying for vague prompts twice.",
    "Use free playbooks",
    "Preview Pro library",
    "tokenbar playbooks",
    "Read the 100-template catalog",
    "System Prompt Hardener",
    "No-Submit Launch Draft",
    "Cost Passport",
    "Comparison Engine",
    "Prompt quality becomes a measurable budget loop.",
    "TokenBar prompt savings lab",
    "Input waste",
    "Playbook run",
    "Proof lift",
    "Personal usage cockpit",
    "Prompt marketplace",
    "Team",
    "raw transcripts required",
    "data-copy-command",
    "Choose by leak",
    "What is wasting the next run?",
    "data-playbook-diagnosis",
    'data-diagnosis-mode="scope"',
    'data-diagnosis-mode="verify"',
    'data-diagnosis-mode="connector"',
    'data-diagnosis-mode="launch"',
    "Vague scope",
    "No verifier",
    "Provider fog",
    "Launch drift",
    "data-diagnosis-title",
    "data-diagnosis-score",
    "data-diagnosis-command",
    "data-diagnosis-copy-button",
    "data-diagnosis-boundary",
    "Copy-only. No subscription, account change, provider call, or payment action happens here.",
]

for needle in page_required:
    if needle not in page:
        raise SystemExit(f"FAIL: missing playbook marketplace page marker: {needle}")

app = (ROOT / "docs/app.js").read_text()
app_required = [
    'const playbookDiagnosis = document.querySelector("[data-playbook-diagnosis]")',
    "const diagnosisModes =",
    "function updateDiagnosisMode",
    "dataset.activeDiagnosis",
    "tokenbar playbooks copy verifier-first",
    "tokenbar playbooks copy connector-truth",
    "No-Submit Launch Draft",
    "ArrowLeft",
    "ArrowRight",
]

for needle in app_required:
    if needle not in app:
        raise SystemExit(f"FAIL: missing playbook diagnosis JS marker: {needle}")

for needle in ['"src": "/playbooks/?"', '"dest": "/docs/playbooks.html"']:
    if needle not in vercel:
        raise SystemExit(f"FAIL: missing playbooks route marker: {needle}")

docs_required = [
    "tokenbar playbooks",
    "tokenbar playbooks json",
    "tokenbar playbooks copy mission-lock",
    "tokenbar playbooks copy budget-runway",
    "reducing waste before the next agent run",
    "structured JSON for the menu-bar app",
]

for needle in docs_required:
    if needle not in docs:
        raise SystemExit(f"FAIL: missing docs playbooks command marker: {needle}")

cli_required = [
    "playbooks_command()",
    "tokenbar playbooks copy mission-lock",
    "tokenbar playbooks json",
    "tokenbar.playbooks.v1",
    "mission-lock",
    "budget-runway",
    "cost-saver",
    "verifier-first",
    "connector-truth",
    "Antigravity, and OpenCode sources",
    "Privacy: playbooks never require raw transcripts, source code, or credentials.",
]

for cli_name, cli_text in [("src/tokenbar/tokenbar", src_cli), ("bin/tokenbar", bin_cli)]:
    for needle in cli_required:
        if needle not in cli_text:
            raise SystemExit(f"FAIL: missing {cli_name} playbooks CLI marker: {needle}")
    if "Gemini sources" in cli_text:
        raise SystemExit(f"FAIL: stale Gemini connector help remains in {cli_name}")

css = (ROOT / "docs/styles.css").read_text()
css_required = [
    ".savings-lab",
    ".savings-stage",
    ".savings-meter",
    ".savings-meter.is-improved",
    ".pro-comparison-strip",
    ".playbook-diagnosis",
    ".diagnosis-stage",
    ".diagnosis-options",
    ".diagnosis-options button.is-active",
    ".diagnosis-result",
    ".diagnosis-orbit",
    ".diagnosis-command",
    'data-active-diagnosis="launch"',
]
for needle in css_required:
    if needle not in css:
        raise SystemExit(f"FAIL: missing playbook savings CSS marker: {needle}")

for cli_path in [SRC_CLI, BIN_CLI]:
    result = subprocess.run(
        [str(cli_path), "playbooks", "json"],
        cwd=ROOT,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    payload = json.loads(result.stdout)
    if payload.get("schema") != "tokenbar.playbooks.v1":
        raise SystemExit(f"FAIL: {cli_path.name} playbooks json schema mismatch")
    privacy = payload.get("privacy", {})
    for flag in [
        "raw_transcripts_required",
        "source_code_required",
        "credentials_required",
    ]:
        if privacy.get(flag) is not False:
            raise SystemExit(f"FAIL: {cli_path.name} playbooks json privacy flag not false: {flag}")
    if privacy.get("external_actions_require_approval") is not True:
        raise SystemExit(f"FAIL: {cli_path.name} playbooks json missing approval gate")
    tiers = payload.get("tiers", [])
    tier_names = {tier.get("name") for tier in tiers}
    if {"Free", "Pro"} - tier_names:
        raise SystemExit(f"FAIL: {cli_path.name} playbooks json missing Free/Pro tiers")
    free_playbooks = next(tier for tier in tiers if tier.get("name") == "Free").get("playbooks", [])
    free_keys = {item.get("key") for item in free_playbooks}
    if {"mission-lock", "budget-runway", "cost-saver", "verifier-first", "connector-truth"} - free_keys:
        raise SystemExit(f"FAIL: {cli_path.name} playbooks json missing starter keys")
    targets = set(payload.get("connector_targets", []))
    if {"Codex", "Claude Code", "Cursor", "Antigravity", "OpenCode"} - targets:
        raise SystemExit(f"FAIL: {cli_path.name} playbooks json missing connector targets")
    if "Gemini" in targets:
        raise SystemExit(f"FAIL: {cli_path.name} playbooks json includes Gemini target")
    links = payload.get("links", {})
    if not str(links.get("marketplace", "")).endswith("/playbooks"):
        raise SystemExit(f"FAIL: {cli_path.name} playbooks json marketplace link invalid")
    if not str(links.get("catalog", "")).endswith("/prompt-playbooks.md"):
        raise SystemExit(f"FAIL: {cli_path.name} playbooks json catalog link invalid")

for forbidden in [
    "paste your API key",
    "ignore approval",
    "spend without approval",
    "automatically upload raw",
    "automatically upload source",
]:
    if forbidden in text.lower():
        raise SystemExit(f"FAIL: unsafe playbook phrase remains: {forbidden}")

print(f"PASS: TokenBar prompt playbook library has {len(entries)} templates plus a freemium marketplace page with budget gates and privacy boundaries.")
