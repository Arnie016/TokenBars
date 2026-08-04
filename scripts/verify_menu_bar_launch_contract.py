#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "macos/TokenBarMac/Sources/TokenBarMac/TokenBarMacApp.swift"
MODEL = ROOT / "macos/TokenBarMac/Sources/TokenBarMac/TokenBarModel.swift"

source = APP.read_text()
model_source = MODEL.read_text()

required = {
    "window-style MenuBarExtra": ".menuBarExtraStyle(.window)",
    "popover tabs": "MenuBarSurfaceTabs",
    "launch bridge": "MenuBarLaunchBridge",
    "native surface relay": "MenuBarSurfaceRelay",
    "native relay enum": "enum MenuBarRelaySurface",
    "native relay label": '"SURFACE RELAY"',
    "native relay CLI": 'case cli = "CLI"',
    "native relay menu": 'case menu = "Menu bar"',
    "native relay companion": 'case companion = "Companion"',
    "native relay studio": 'case studio = "Mac studio"',
    "native relay pro": 'case pro = "Pro"',
    "native relay command usage": '"tokenbar usage"',
    "native relay command status": '"tokenbar status"',
    "native relay command api": '"tokenbar api"',
    "native relay command proof packet": '"tokenbar proof-packet"',
    "native relay command playbooks": '"tokenbar playbooks"',
    "native relay local read only": '"Local read only"',
    "native relay no provider sign in": '"No provider sign-in"',
    "native relay localhost only": '"127.0.0.1 only"',
    "native relay review before share": '"Review before share"',
    "native relay no auto billing": '"No auto-billing"',
    "native relay paid playbooks": "Paid prompt playbooks, public proof cards, cohort comparison, and premium reports after account review.",
    "download Mac app button": '"Download Mac app"',
    "download Mac app URL": '"https://www.tokenbar.site/#download"',
    "proof packet bridge button": '"Proof packet"',
    "proof packet bridge command": '"tokenbar proof-packet json"',
    "proof packet bridge confirmation": '"Proof packet command copied"',
    "menu bar to full app copy": "Menu bar now. Full Mac app when you want reports.",
    "free pro bridge copy": "Free tracking stays here. Pro playbooks, reports, and comparison proofs open in the larger surface.",
    "token window cycling": "tokenScope = tokenScope.next",
    "local account label": "AccountLabel.current",
    "account shown before usage": "Account shown before usage",
    "provider account field": "let accountLabel: String",
    "provider source field": "let sourceLabel: String",
    "codex account evidence": "Codex local evidence",
    "unconnected account copy": "No account connected",
    "OpenCode connector lane": 'title: "OpenCode"',
    "cost passport": 'MenuSectionHeader("Cost passport"',
    "native cost selected range": '"SELECTED RANGE"',
    "native cost range copy": '"tokenbar cost-passport --from YYYY-MM-DD --to YYYY-MM-DD json"',
    "native cost reminder copy": '"tokenbar reminders json"',
    "native cost peak day": '"Peak day"',
    "native cost forecast band": '"Forecast band"',
    "native cost estimate boundary": '"Estimate only. Not a provider invoice."',
    "native cost aggregate boundary": '"Aggregate totals only"',
    "native cost privacy boundary": '"Raw prompts, paths, source, credentials stay out."',
    "native cost passport facts": "PassportFact",
    "comparison tab": 'case compare = "Compare"',
    "comparison lens": '"Comparison lens"',
    "comparison command": '"tokenbar comparison-lens json"',
    "comparison cohort lock": "Percentiles unlock only with opt-in proof cohorts.",
    "comparison no top percentile": "No top-percentile claim without opt-in data.",
    "comparison self over time": "SELF-OVER-TIME",
    "comparison surface": "MenuComparisonSurface",
    "prompt playbooks": '"Prompt playbooks"',
    "playbook command strip": "PlaybookCommandStrip",
    "playbook real JSON bridge": "copyPlaybookJSON",
    "playbook waste matrix": '"Token waste matrix"',
    "playbook Free Pro selector": "PlaybookTierFilter",
    "playbook marketplace link": '"https://www.tokenbar.site/playbooks"',
    "playbook catalog link": '"https://www.tokenbar.site/prompt-playbooks.md"',
    "playbook privacy flags": "No raw transcripts, source code, or credentials. External actions stay approval-gated.",
    "system prompt hardener": 'title: "System Prompt Hardener"',
    "pro playbook tier": 'tier: "Pro"',
    "cost passport playbook": 'title: "Cost Passport"',
    "launch draft playbook": 'title: "No-Submit Launch Draft"',
    "budget reminders": 'MenuSectionHeader("Budgets and reminders"',
    "native runway brief": '"RUNWAY BRIEF"',
    "native runway brief title": '"Prepare the next run before it expands."',
    "native runway no schedule": '"No notification scheduled"',
    "native runway surface": "RunwayBriefCard",
    "native runway suggested only": '"Suggested only"',
    "budget coach": '"AI BUDGET COACH"',
    "budget coach presets": "enum BudgetCoachPreset",
    "budget setup prompt": '"Copy setup prompt"',
    "budget reminder command": '"tokenbar reminders json"',
    "budget approval gate": '"Approval-gated"',
    "memory guard": 'MenuSectionHeader("Memory guard"',
    "approval-gated system copy": "Automatic app closing remains approval-gated",
    "measured provider flag": "isMeasured",
    "measured-only chart filter": "providerRows.filter { $0.isMeasured && $0.tokens > 0 }",
}

for name, needle in required.items():
    if needle not in source:
        raise SystemExit(f"FAIL: missing {name}: {needle}")

model_required = {
    "copy playbook catalog json method": "func copyPlaybookCatalogJSON()",
    "playbooks json CLI call": 'Self.runTokenBar(arguments: ["playbooks", "json"], timeout: 15)',
    "playbook JSON command": '"tokenbar playbooks json"',
    "playbook JSON copied confirmation": '"Playbook JSON copied"',
    "playbook JSON fallback command": '"tokenbar playbooks json"',
}

for name, needle in model_required.items():
    if needle not in model_source:
        raise SystemExit(f"FAIL: missing {name}: {needle}")

for forbidden in [
    'case gemini',
    'title: "Gemini"',
    "Double(total) * 0.52",
    "Double(total) * 0.24",
    "Double(total) * 0.13",
    "Double(total) * 0.07",
    ".menuBarExtraStyle(.menu)",
]:
    if forbidden in source:
        raise SystemExit(f"FAIL: forbidden speculative or stale menu-bar marker remains: {forbidden}")

print("PASS: TokenBar menu-bar popover uses measured evidence, connector-safe provider lanes, budgets, costs, memory guard, and window presentation.")
