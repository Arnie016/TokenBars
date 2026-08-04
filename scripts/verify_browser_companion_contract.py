#!/usr/bin/env python3
import json
import importlib.util
import subprocess
from html.parser import HTMLParser
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"
MANIFEST = ROOT / "browser-companion" / "manifest.json"
POPUP_HTML = ROOT / "browser-companion" / "popup.html"
POPUP_CSS = ROOT / "browser-companion" / "popup.css"
POPUP_JS = ROOT / "browser-companion" / "popup.js"
INDEX = ROOT / "docs" / "index.html"
IDENTITY_API = ROOT / "src" / "tokenbar" / "identity_api.py"


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


class Parser(HTMLParser):
    pass


def load_identity_api():
    spec = importlib.util.spec_from_file_location("tokenbar_identity_api", IDENTITY_API)
    require(spec is not None and spec.loader is not None, "could not load identity_api module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_json(cli):
    result = subprocess.run(
        [str(cli), "browser-companion", "json"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} browser-companion json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def validate_payload(payload, label):
    require(payload.get("schema") == "tokenbar.browser_companion.v1", f"{label} schema mismatch")
    require(payload.get("product") == "TokenBar Companion", f"{label} product mismatch")
    require(payload.get("path") == "browser-companion", f"{label} path mismatch")
    require(payload.get("manifest") == "browser-companion/manifest.json", f"{label} manifest mismatch")
    require(payload.get("popup") == "browser-companion/popup.html", f"{label} popup mismatch")
    require(payload.get("apiUrl") == "http://127.0.0.1:8769/v1/bundle", f"{label} API URL mismatch")
    require(payload.get("fallbackApiUrl") == "http://127.0.0.1:8769/v1/stats", f"{label} fallback API URL mismatch")
    require(payload.get("remindersApiUrl") == "http://127.0.0.1:8769/v1/reminders", f"{label} reminders API URL mismatch")
    require(payload.get("memoryPressureApiUrl") == "http://127.0.0.1:8769/v1/memory-pressure", f"{label} memory pressure API URL mismatch")
    require(payload.get("guideApiUrl") == "http://127.0.0.1:8769/v1/guide", f"{label} guide API URL mismatch")
    require(payload.get("wasteLensApiUrl") == "http://127.0.0.1:8769/v1/waste-lens", f"{label} waste lens API URL mismatch")
    require(payload.get("playbooksApiUrl") == "http://127.0.0.1:8769/v1/playbooks", f"{label} playbooks API URL mismatch")
    require(payload.get("providersApiUrl") == "http://127.0.0.1:8769/v1/providers", f"{label} providers API URL mismatch")
    require(payload.get("comparisonLensApiUrl") == "http://127.0.0.1:8769/v1/comparison-lens", f"{label} comparison lens API URL mismatch")
    require(payload.get("proofPacketApiUrl") == "http://127.0.0.1:8769/v1/proof-packet", f"{label} proof packet API URL mismatch")
    require(payload.get("startCommand") == "tokenbar api", f"{label} start command mismatch")
    steps = " ".join(payload.get("installExperiment") or [])
    for marker in ["chrome://extensions", "Load unpacked", "browser-companion", "tokenbar api"]:
        require(marker in steps, f"{label} install handoff missing {marker}")
    privacy = payload.get("privacy") or {}
    for true_key in ["readOnly"]:
        require(privacy.get(true_key) is True, f"{label} privacy {true_key} should be true")
    for false_key in ["rawPrompts", "sourceCode", "credentials", "contentScripts", "remoteHosts", "externalActions"]:
        require(privacy.get(false_key) is False, f"{label} privacy {false_key} should be false")
    surfaces = payload.get("surfaces") or []
    for surface in ["Codex", "GitHub", "Product Hunt"]:
        require(surface in surfaces, f"{label} missing surface {surface}")
    story_surfaces = " ".join(payload.get("storySurfaces") or [])
    for marker in ["account badge", "budget-left ring", "cost passport", "cost passport card", "structured reminder plan", "read-only memory pressure rail", "browser plus agent pressure", "MCQ guide", "suggested-only guide choices", "aggregate waste lens", "next-run saver playbook", "freemium prompt vault", "free and Pro playbook preview", "provider composition", "provider truth rail", "measured versus setup provider status", "comparison lens", "self-over-time benchmark", "locked percentile", "Mac app download handoff", "copyable install command", "no-submit launch coach", "copyable launch commands", "stats fallback"]:
        require(marker in story_surfaces, f"{label} missing story surface {marker}")
    for marker in ["reviewable launch proof packet", "blocked-field launch seal"]:
        require(marker in story_surfaces, f"{label} missing proof packet story surface {marker}")
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
        "Local read only",
        "No provider sign-in",
        "127.0.0.1 only",
        "Review before share",
        "No auto-billing",
    ]:
        require(marker in relay_text, f"{label} surface relay missing {marker}")
    launch_coach = payload.get("launchCoach") or {}
    require(launch_coach.get("state") == "No-submit", f"{label} launch coach must be no-submit")
    launch_commands = " ".join(launch_coach.get("commands") or [])
    for command in ["tokenbar coach", "tokenbar runway", "tokenbar launch-kit", "tokenbar playbooks"]:
        require(command in launch_commands, f"{label} launch coach missing {command}")
    launch_steps = " ".join(f"{row.get('label', '')} {row.get('copy', '')}" for row in launch_coach.get("steps") or [])
    for marker in ["Product Hunt", "Macapp Supply", "Mission Lock", "aggregates"]:
        require(marker in launch_steps, f"{label} launch coach missing {marker}")
    cost_passport = payload.get("costPassport") or {}
    require(cost_passport.get("command") == "tokenbar cost-passport --from 2026-06-02 --to 2026-08-02 json", f"{label} cost passport command mismatch")
    cost_fields = " ".join(cost_passport.get("fields") or [])
    for marker in ["selected range", "estimate", "peak day", "uncertainty", "next cost action"]:
        require(marker in cost_fields, f"{label} cost passport missing field {marker}")
    cost_privacy = " ".join(str(cost_passport.get(key, "")) for key in ["privacy", "disclaimer"])
    for marker in ["aggregate-only", "raw reports", "credentials", "not official provider invoices"]:
        require(marker in cost_privacy, f"{label} cost passport privacy missing {marker}")
    waste_lens = payload.get("wasteLens") or {}
    require(waste_lens.get("command") == "tokenbar waste", f"{label} waste lens command mismatch")
    waste_fields = " ".join(waste_lens.get("fields") or [])
    for marker in ["score", "driver", "saver levers"]:
        require(marker in waste_fields, f"{label} waste lens missing field {marker}")
    waste_privacy = str(waste_lens.get("privacy", ""))
    for marker in ["aggregate-only", "raw prompts", "provider calls", "output-quality judgment"]:
        require(marker in waste_privacy, f"{label} waste lens privacy missing {marker}")
    prompt_vault = payload.get("promptVault") or {}
    require(prompt_vault.get("apiUrl") == "http://127.0.0.1:8769/v1/playbooks", f"{label} prompt vault API mismatch")
    require(prompt_vault.get("command") == "tokenbar playbooks", f"{label} prompt vault command mismatch")
    require(prompt_vault.get("starterCommand") == "tokenbar playbooks copy mission-lock", f"{label} prompt vault starter command mismatch")
    prompt_vault_text = " ".join(str(prompt_vault.get(key, "")) for key in ["businessState", "marketplace", "catalog"])
    for marker in ["Freemium preview", "no local payment", "entitlement mutation", "/playbooks", "/prompt-playbooks.md"]:
        require(marker in prompt_vault_text, f"{label} prompt vault missing {marker}")
    comparison_lens = payload.get("comparisonLens") or {}
    require(comparison_lens.get("apiUrl") == "http://127.0.0.1:8769/v1/comparison-lens", f"{label} comparison lens API mismatch")
    require(comparison_lens.get("command") == "tokenbar comparison-lens", f"{label} comparison lens command mismatch")
    comparison_fields = " ".join(comparison_lens.get("fields") or [])
    for marker in ["cadence", "momentum", "cost control", "scope discipline", "cohort gate"]:
        require(marker in comparison_fields, f"{label} comparison lens missing field {marker}")
    comparison_boundary = " ".join(str(comparison_lens.get(key, "")) for key in ["privacy", "disclaimer"])
    for marker in ["self-over-time", "raw prompts", "source code", "provider calls", "top-percentile claims", "opt-in cohort"]:
        require(marker in comparison_boundary, f"{label} comparison lens boundary missing {marker}")
    proof_packet = payload.get("proofPacket") or {}
    require(proof_packet.get("apiUrl") == "http://127.0.0.1:8769/v1/proof-packet", f"{label} proof packet API mismatch")
    require(proof_packet.get("command") == "tokenbar proof-packet json", f"{label} proof packet command mismatch")
    proof_fields = " ".join(proof_packet.get("fields") or [])
    for marker in ["usage evidence", "cost passport", "waste lens", "comparison lock", "approval gates"]:
        require(marker in proof_fields, f"{label} proof packet missing field {marker}")
    proof_boundary = " ".join(str(proof_packet.get(key, "")) for key in ["privacy", "state"])
    for marker in ["public-ready aggregates", "raw prompts", "source code", "private diffs", "credentials", "provider cookies", "account switching", "posting", "uploads", "purchases", "top-percentile claims", "review first"]:
        require(marker in proof_boundary, f"{label} proof packet boundary missing {marker}")
    handoff = payload.get("handoff") or {}
    require(handoff.get("macAppUrl") == "https://www.tokenbar.site/#download", f"{label} Mac app handoff URL mismatch")
    require("raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh" in handoff.get("installCommand", ""), f"{label} install command missing live script")
    handoff_journey = payload.get("handoffJourney") or []
    require([row.get("step") for row in handoff_journey] == ["Install", "Icon bar", "Local API", "Mac studio"], f"{label} handoff journey order mismatch")
    handoff_journey_text = " ".join(
        " ".join(str(row.get(key, "")) for key in ["command", "surface"])
        for row in handoff_journey
    )
    for marker in ["tokenbar install", "tokenbar open", "tokenbar api", "127.0.0.1", "tokenbar proof-packet", "reviewable reports"]:
        require(marker in handoff_journey_text, f"{label} handoff journey missing {marker}")
    next_build = " ".join(payload.get("nextBuild") or [])
    require("provider truth" in next_build, f"{label} next build should mention provider truth")
    require("/v1/waste-lens" in next_build, f"{label} next build should mention waste lens")
    require("/v1/playbooks" in next_build, f"{label} next build should mention playbooks")
    require("/v1/comparison-lens" in next_build, f"{label} next build should mention comparison lens")
    require("/v1/proof-packet" in next_build, f"{label} next build should mention proof packet")


def validate_guide_payload(payload):
    require(payload.get("schema") == "tokenbar.guide.v1", "guide schema mismatch")
    question = payload.get("question", "")
    require(
        "before your next AI coding run" in question
        or "optimize next" in question
        or "safe next step" in question,
        "guide question mismatch",
    )
    choices = payload.get("choices") or []
    keys = [choice.get("key") for choice in choices]
    require(keys == ["install", "analyze", "budget", "playbook", "proof"], "guide choice order mismatch")
    commands = " ".join(choice.get("command", "") for choice in choices)
    for marker in [
        "raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh",
        "tokenbar usage",
        "tokenbar reminders",
        "tokenbar playbooks copy budget-runway",
        "tokenbar proof-packet",
    ]:
        require(marker in commands, f"guide choices missing {marker}")
    require(payload.get("priority") in keys, "guide priority must reference a guide choice")
    privacy = payload.get("privacy") or {}
    for key in [
        "rawPromptsIncluded",
        "rawTranscriptsIncluded",
        "sourceCodeIncluded",
        "localPathsIncluded",
        "credentialsIncluded",
        "writesSettings",
        "providerCalls",
        "accountMutation",
        "scheduledNotifications",
        "externalActions",
    ]:
        require(privacy.get(key) is False, f"guide privacy flag {key} must be false")
    disclaimer = payload.get("disclaimer", "")
    for marker in ["suggested-only", "does not write settings", "schedule reminders", "close apps", "post", "upload", "contact providers"]:
        require(marker in disclaimer, f"guide disclaimer missing {marker}")


def main():
    manifest = json.loads(MANIFEST.read_text())
    require(manifest.get("manifest_version") == 3, "manifest must be MV3")
    require(manifest.get("name") == "TokenBar Companion", "manifest name mismatch")
    require((manifest.get("action") or {}).get("default_popup") == "popup.html", "manifest default popup mismatch")

    permissions = set(manifest.get("permissions") or [])
    host_permissions = set(manifest.get("host_permissions") or [])
    require(permissions <= {"storage"}, f"unexpected extension permissions: {sorted(permissions)}")
    require(host_permissions == {"http://127.0.0.1:8769/*", "http://localhost:8769/*"}, "host permissions must be localhost-only")
    for forbidden_key in ["content_scripts", "background", "oauth2"]:
        require(forbidden_key not in manifest, f"manifest must not declare {forbidden_key}")
    for forbidden_permission in ["tabs", "scripting", "webRequest", "cookies", "history", "downloads", "nativeMessaging"]:
        require(forbidden_permission not in permissions, f"forbidden permission present: {forbidden_permission}")

    popup_html = POPUP_HTML.read_text()
    Parser().feed(popup_html)
    for marker in [
        "TokenBar Companion",
        "data-account-label",
        "data-today-tokens",
        "data-budget-state",
        "data-budget-ring",
        "data-cadence-state",
        "data-cost-state",
        "Surface relay",
        "data-surface-relay",
        "data-relay-title",
        "data-relay-tier",
        "data-relay-flow",
        "data-relay-value",
        "data-relay-command",
        "data-relay-gate",
        "data-relay-tabs",
        "data-relay-key=\"cli\"",
        "data-relay-key=\"menu\"",
        "data-relay-key=\"companion\"",
        "data-relay-key=\"studio\"",
        "data-relay-key=\"pro\"",
        "Menu-bar cockpit",
        "Browser context rail",
        "Pro proof market",
        "No auto-billing",
        "data-guide-question",
        "data-guide-state",
        "data-guide-options",
        "data-guide-choice=\"install\"",
        "data-guide-choice=\"analyze\"",
        "data-guide-choice=\"budget\"",
        "data-guide-choice=\"playbook\"",
        "data-guide-choice=\"proof\"",
        "class=\"guide-action-rail\"",
        "data-guide-command",
        "data-guide-boundary",
        "data-guide-copy",
        "tokenbar playbooks copy budget-runway",
        "No settings changed.",
        "data-guide-answer",
        "What should TokenBar help with before your next AI coding run?",
        "data-reminder-state",
        "Budget brief",
        "data-runway-title",
        "data-runway-state",
        "data-runway-material",
        "data-runway-reason",
        "data-runway-prompt",
        "data-runway-copy",
        "Suggested only. No notification scheduled.",
        "data-memory-title",
        "data-memory-pressure-state",
        "data-memory-bubble",
        "data-memory-percent",
        "data-memory-lane",
        "data-memory-detail",
        "data-memory-action",
        "Memory pressure",
        "Explain overload before cleanup.",
        "Approval required before cleanup.",
        "data-cost-title",
        "data-cost-range",
        "data-cost-estimate",
        "data-cost-uncertainty",
        "data-cost-action",
        "Waste lens",
        "data-waste-title",
        "data-waste-meter",
        "data-waste-score",
        "data-waste-label",
        "data-waste-driver",
        "data-waste-levers",
        "data-waste-copy",
        "Spend fewer tokens on the next run.",
        "Prompt vault",
        "data-playbooks-title",
        "data-playbooks-tier",
        "data-playbooks-free-count",
        "data-playbooks-pro-count",
        "data-playbooks-catalog-count",
        "data-playbooks-list",
        "data-playbooks-copy",
        "data-playbooks-marketplace",
        "data-playbooks-boundary",
        "Copy a better operating order.",
        "Open vault",
        "No payments or unlocks from the companion.",
        "data-composition-stack",
        "data-provider-list",
        "Provider truth",
        "data-provider-summary",
        "data-provider-strip",
        "data-provider-detail",
        "data-provider-detail-name",
        "data-provider-detail-status",
        "data-provider-detail-proof",
        "data-provider-detail-action",
        "data-provider-setup-flow",
        "data-provider-detail-copy",
        "provider-setup-flow",
        "Detect",
        "Connect",
        "Review",
        "Measured vs setup",
        "Copy local check",
        "status-setup",
        "Setup needed",
        "No local aggregate token evidence loaded for this provider yet.",
        "Comparison lens",
        "data-comparison-title",
        "data-comparison-state",
        "data-comparison-orbit",
        "data-comparison-metrics",
        "data-comparison-copy",
        "data-comparison-copy-command",
        "Compare the pattern, not the person.",
        "Population percentiles stay locked",
        "Copy comparison command",
        "Proof packet",
        "data-proof-title",
        "data-proof-state",
        "data-proof-fields",
        "data-proof-copy",
        "data-proof-copy-command",
        "Show proof without exposing the work.",
        "Public-ready aggregates only",
        "Copy proof packet command",
        "data-launch-title",
        "data-launch-state",
        "data-launch-steps",
        'class="mac-app-handoff"',
        "TokenBar Mac app handoff",
        "Open the deeper builder studio.",
        'class="handoff-mini-flow"',
        "CLI + app",
        "usage cockpit",
        "127.0.0.1 rail",
        "proof review",
        "https://www.tokenbar.site/#download",
        "Copy install",
        "raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh",
        "data-copy-command=\"tokenbar runway\"",
        "data-copy-command=\"tokenbar launch-kit\"",
        "data-copy-command=\"tokenbar playbooks\"",
        "data-copy-command=\"tokenbar cost-passport --from 2026-06-02 --to 2026-08-02 json\"",
        "Cost passport",
        "Launch coach",
        "No content scripts",
        "Codex",
        "Claude Code",
        "Antigravity",
        "OpenCode",
        "https://www.tokenbar.site/playbooks",
    ]:
        require(marker in popup_html, f"popup HTML missing {marker}")
    require("Gemini" not in popup_html, "popup HTML should not include Gemini")
    require("status-demo" not in popup_html, "popup HTML must not present fallback providers as demo")
    require("<b>preview</b>" not in popup_html, "popup HTML must not present fallback providers as preview")

    popup_css = POPUP_CSS.read_text()
    for marker in [".companion-shell", ".hero-meter", ".budget-ring", ".surface-relay-card", ".surface-relay-head", ".relay-flow", ".relay-flow i.is-selected", ".relay-command", ".relay-tabs", ".signal-grid", ".guide-card", ".guide-options", ".guide-action-rail", ".is-selected", ".runway-brief-card", ".runway-material", ".runway-command", ".cost-passport-card", ".passport-stamp", ".passport-copy", ".waste-lens-card", ".waste-meter", ".waste-levers", ".prompt-vault-card", ".prompt-vault-head", ".vault-counts", ".vault-playbooks", ".vault-actions", ".memory-pressure-card", ".memory-bubble", ".memory-copy", ".composition-card", ".provider-strip", ".provider-truth-head", ".provider-truth-list", ".provider-pill", "button.provider-pill", ".provider-detail", ".provider-detail button", ".provider-setup-flow", ".provider-setup-flow li", ".provider-setup-flow li.is-done", ".status-measured", ".status-setup", ".comparison-lens-card", ".comparison-lens-head", ".comparison-orbit", ".comparison-metrics", ".proof-packet-card", ".proof-packet-head", ".proof-packet-seal", ".proof-fields", ".mac-app-handoff", ".handoff-mini-flow", ".handoff-actions", ".launch-coach", ".command-row", ".is-live"]:
        require(marker in popup_css, f"popup CSS missing {marker}")
    require(".status-demo" not in popup_css, "popup CSS should not keep demo provider styling")

    popup_js = POPUP_JS.read_text()
    for marker in [
        'const API_URL = "http://127.0.0.1:8769/v1/bundle"',
        'const STATS_URL = "http://127.0.0.1:8769/v1/stats"',
        'const REMINDERS_URL = "http://127.0.0.1:8769/v1/reminders"',
        'const MEMORY_URL = "http://127.0.0.1:8769/v1/memory-pressure"',
        'const GUIDE_URL = "http://127.0.0.1:8769/v1/guide"',
        'const WASTE_URL = "http://127.0.0.1:8769/v1/waste-lens"',
        'const PLAYBOOKS_URL = "http://127.0.0.1:8769/v1/playbooks"',
        'const PROVIDERS_URL = "http://127.0.0.1:8769/v1/providers"',
        'const COMPARISON_URL = "http://127.0.0.1:8769/v1/comparison-lens"',
        'const PROOF_PACKET_URL = "http://127.0.0.1:8769/v1/proof-packet"',
        "topReminder",
        "runwayBrief",
        "renderRunwayBrief",
        "fallbackRunwayBrief",
        "riskToPercent",
        "tokenbar playbooks copy budget-runway",
        "renderGuide",
        "fallbackGuide",
        "setGuideChoice",
        "guideChoices",
        "guidePayload",
        "guideCommand.textContent",
        "guideBoundary.textContent",
        "guideCopyButton",
        "approvalRequired",
        "renderWasteLens",
        "fallbackWasteLens",
        "wastePayload",
        "selectedWasteCommand",
        "wasteCopy",
        "tokenbar playbooks copy output-budget",
        "renderPlaybookVault",
        "fallbackPlaybooks",
        "playbooksPayload",
        "selectedPlaybookCommand",
        "playbooksMarketplace.href",
        "playbooksCopy",
        "providerSummary",
        "providerStrip",
        "providerDetailName",
        "providerDetailStatus",
        "providerDetailProof",
        "providerDetailAction",
        "providerSetupFlow",
        "providerDetailCopy",
        "providersPayload",
        "providerChoices",
        "selectedProviderKey",
        "renderProviderTruth",
        "setProviderDetail",
        "inferredProviderPayload",
        "evidenceNeeded",
        "setupFlow",
        "is-done",
        "Detect",
        "Connect",
        "Review",
        "tokenbar providers",
        "tokenbar usage",
        "status-measured",
        "status-setup",
        "Setup needed",
        "No local aggregate token evidence loaded",
        "comparisonTitle",
        "comparisonState",
        "comparisonMetrics",
        "comparisonOrbit",
        "comparisonLens",
        "comparisonPayload",
        "selectedComparisonCommand",
        "renderComparisonLens",
        "fallbackComparisonLens",
        "tokenbar comparison-lens",
        "Population percentiles stay locked until a measured opt-in cohort exists.",
        "top-percentile claims without cohort data",
        "proofTitle",
        "proofState",
        "proofFields",
        "proofPacket",
        "proofPayload",
        "selectedProofCommand",
        "renderProofPacket",
        "fallbackProofPacket",
        "tokenbar proof-packet json",
        "Show proof without exposing the work.",
        "Public-ready aggregates only",
        "renderMemoryPressure",
        "formatMemory",
        "memoryPressure",
        "browser + agent pressure",
        "fetch(url",
        "AbortController",
        "renderFallback",
        "fetchJson",
        "renderComposition",
        "relayChoices",
        "selectedRelayKey",
        "fallbackSurfaceRelay",
        "renderSurfaceRelay",
        "setRelayChoice",
        "surfaceRelay",
        "CLI evidence line",
        "Menu-bar cockpit",
        "Browser context rail",
        "Mac studio archive",
        "Pro proof market",
        "renderCostPassport",
        "formatUncertainty",
        "topProviders",
        "formatCost",
        "renderLaunchCoach",
        "fallbackLaunchCoach",
        "launchCoach",
        "copyCommand",
        "navigator.clipboard.writeText(API_COMMAND)",
        "navigator.clipboard.writeText(command)",
    ]:
        require(marker in popup_js, f"popup JS missing {marker}")
    require("status-demo" not in popup_js, "popup JS should not keep demo provider state")
    require("tokensLabel: \"preview\"" not in popup_js, "popup JS should not label fallback provider tokens as preview")
    require("status: \"demo\"" not in popup_js, "popup JS should not emit demo fallback providers")
    require("Gemini" not in popup_js, "popup JS should not include Gemini")
    for forbidden in ["chrome.tabs", "chrome.scripting", "content_scripts", "document.body", "innerText", "innerHTML", "eval("]:
        require(forbidden not in popup_js, f"popup JS contains forbidden marker {forbidden}")

    src_payload = run_json(SRC_CLI)
    bin_payload = run_json(BIN_CLI)
    validate_payload(src_payload, "src")
    validate_payload(bin_payload, "bin")
    require(src_payload == bin_payload, "src/bin browser companion payload drifted")
    identity_api = load_identity_api()
    validate_guide_payload(identity_api.guide_payload(ROOT / ".tokenbar-empty-test-root"))
    bundle = identity_api.bundle_payload(ROOT / ".tokenbar-empty-test-root")
    bundle_relay = bundle.get("surfaceRelay") or []
    require([row.get("key") for row in bundle_relay] == ["cli", "menu", "companion", "studio", "pro"], "safe bundle surface relay order mismatch")
    require(bundle.get("privacy", {}).get("rawTranscriptsIncluded") is False, "bundle relay must preserve raw transcript privacy")

    homepage = INDEX.read_text()
    for marker in ["tokenbar browser-companion", "tokenbar coach", "browser-companion", "No content scripts"]:
        require(marker in homepage, f"homepage missing {marker}")

    print("browser_companion_contract: PASS")


if __name__ == "__main__":
    main()
