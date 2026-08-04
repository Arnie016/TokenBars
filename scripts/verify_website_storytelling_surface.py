#!/usr/bin/env python3
from pathlib import Path
import re
import json
import subprocess


ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "docs" / "index.html"
CSS = ROOT / "docs" / "styles.css"
CODEX_CSS = ROOT / "docs" / "tokenbar-codex.css"
JS = ROOT / "docs" / "app.js"
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main():
    index = INDEX.read_text()
    css = CSS.read_text() + "\n" + CODEX_CSS.read_text()
    js = JS.read_text()

    required_html = [
        'data-story-console',
        'class="story-console-meta"',
        'class="token-matrix"',
        'class="signal-field"',
        'TokenBar liquid signal field',
        'data-active-story="composition"',
        'data-signal="budget"',
        'data-signal-story',
        'class="story-slide-controls"',
        'data-story-prev',
        'data-story-next',
        'data-story-dots',
        'data-story-dot="6"',
        'class="hero-provider-strip"',
        'Current TokenBar provider lanes',
        '<span>OpenCode</span>',
        'Account</b> arnz',
        'click to cycle week, month, year',
        'reminders before budget pressure',
        'data-story-layer="composition"',
        'data-story-layer="cadence"',
        'data-story-layer="forecast"',
        'data-story-layer="budget"',
        'data-story-layer="costs"',
        'data-story-layer="playbooks"',
        'data-story-layer="memory"',
        'class="story-stack-strip"',
        'TokenBar connected product surfaces',
        'Live cockpit',
        'Evidence engine',
        'Builder studio',
        'Proof market',
        'Context rail',
        'Cost Passport',
        'id="reminder-composer"',
        'Reminder composer',
        'Set the guardrail before the run starts.',
        'tokenbar reminders json',
        'data-reminder-mode="steady"',
        'data-reminder-mode="focus"',
        'data-reminder-mode="strict"',
        'Sound and haptics off by default',
        'Suggested-only. Requires approval.',
        'id="memory-pressure"',
        'Local Automation Relay',
        'Explain overload before asking to clean anything.',
        'tokenbar memory-pressure json',
        'No apps closed',
        'no browser windows restored',
        'no source code',
        'Browse 100 prompt playbooks',
        'memory pressure explained before any approved cleanup',
        'request approval before closing, reopening, or restoring',
        'id="launch-kit"',
        'Draft the launch without posting anything.',
        'Product Hunt',
        'Macapp Supply',
        'tokenbar launch-kit',
        'class="launch-demo-reel"',
        'TokenBar 60-second demo storyboard',
        'Menu-bar opens over Codex',
        'Forecast with error bars',
        'Proof card',
        'No auto-submit. No raw logs. No surprise billing.',
        'id="proof-packet"',
        'Launch proof packet',
        'One safe packet for demos, directories, and investor updates.',
        'tokenbar proof-packet json',
        'cohort locked',
        'no-submit',
        'id="ecosystem"',
        'One signal layer across every AI coding surface.',
        'Browser Companion',
        'Local Automation Relay',
        'tokenbar ecosystem',
        'data-operating-deck',
        'Operating deck',
        'One click changes the layer, not the truth.',
        'data-operating-tab="measure"',
        'data-operating-tab="budget"',
        'data-operating-tab="guide"',
        'data-operating-tab="memory"',
        'data-operating-tab="compare"',
        'data-operating-tab="publish"',
        'data-operating-panel="measure"',
        'Free menu bar',
        'Pro report layer',
        'tokenbar usage json',
        'tokenbar playbooks json',
        'tokenbar comparison-lens json',
        'Rank the pattern, not the person.',
        'id="assembly"',
        'Data-story assembly',
        'Tokens gather into a decision, not a pile of stats.',
        'tokenbar ecosystem json',
        'TokenBar token assembly rail',
        'Account</strong>',
        'MCQ</strong>',
        'Free menu-bar usage',
        'Pro identity report',
        'Premium prompt library',
        'Opt-in public proof',
        'id="token-matrix-lab"',
        'Token Matrix Lab',
        'Watch usage assemble into the next decision.',
        'data-matrix-lab',
        'data-matrix-state="budget"',
        'data-matrix-mode="tokens"',
        'data-matrix-mode="budget"',
        'data-matrix-mode="reminder"',
        'data-matrix-mode="cost"',
        'data-matrix-mode="proof"',
        'class="matrix-truth-rail"',
        'Measured lanes</b><small>Codex, OpenCode when local tokens exist</small>',
        'Setup lanes</b><small>Claude Code, Cursor, Antigravity until connected</small>',
        'class="matrix-signal-stream"',
        'data-matrix-stream="decision"',
        'data-matrix-core',
        'data-matrix-title',
        'data-matrix-primary',
        'id="runway"',
        'See what you can demo, what needs your review, and what still needs polish.',
        'tokenbar runway',
        'data-cost-forecast',
        'data-cost-reminder',
        'data-cost-playbook',
        'data-cost-provider-stamp="codex"',
        'Install handoff',
        'Start in the menu bar. Expand into the studio.',
        'data-surface-relay',
        'data-active-surface="menu"',
        'Surface relay',
        'data-surface-title',
        'data-surface-copy',
        'data-surface-command',
        'data-surface-tier',
        'data-surface-gate',
        'data-surface-tab="cli"',
        'data-surface-tab="menu"',
        'data-surface-tab="companion"',
        'data-surface-tab="studio"',
        'data-surface-tab="pro"',
        'data-surface-step="pro"',
        'Unlock Pro',
        'One-line CLI + app installer',
        'data-copy-install',
        'Install does not sign into providers',
        'Open icon bar',
        'Start local API',
        'Open Mac studio',
        'tokenbar install',
        'tokenbar status',
        'tokenbar api',
        'tokenbar proof-packet',
        'Prompt playbooks',
    ]
    for marker in required_html:
        require(marker in index, f"missing homepage marker: {marker}")

    tabs = re.findall(r'data-story-tab="(\d+)"', index)
    panels = re.findall(r'data-story-panel data-story-layer="([^"]+)"', index)
    require(tabs == [str(index) for index in range(7)], "story tabs must be exactly 0 through 6")
    require(
        panels == ["composition", "cadence", "forecast", "budget", "costs", "playbooks", "memory"],
        "story panels must match the seven launch layers",
    )
    operating_tabs = re.findall(r'data-operating-tab="([^"]+)"', index)
    operating_panels = re.findall(r'data-operating-panel="([^"]+)"', index)
    require(operating_tabs == ["measure", "budget", "guide", "memory", "compare", "publish"], "operating deck tabs must match product layers")
    require(operating_panels == ["measure", "budget", "guide", "memory", "compare", "publish"], "operating deck panels must match product layers")
    require(index.count('data-story-panel') == 7, "each story layer needs a tabpanel")
    require(index.count('data-story-tab') == 7, "each story layer needs a tab")

    required_css = [
        ".story-console-meta",
        ".token-matrix",
        ".signal-field",
        ".signal-field::before",
        ".signal-field i[data-signal=\"tokens\"]",
        ".story-os-stage[data-active-story=\"forecast\"] .signal-field",
        ".story-os-stage[data-active-story=\"memory\"] .signal-field",
        "@keyframes signalPaperFlow",
        ".hero-provider-strip",
        ".memory-surface",
        ".memory-hot",
        ".memory-cool",
        ".story-os-tabs",
        ".story-slide-controls",
        ".story-slide-progress",
        ".story-slide-progress button.is-active",
        ".story-stack-strip",
        ".story-stack-strip article::after",
        ".operating-deck",
        ".operating-deck-tabs",
        ".operating-deck-tabs button.is-active",
        ".operating-deck-panels article:not(.is-active)",
        ".operating-deck-panels code",
        ".ecosystem-band",
        ".ecosystem-map",
        ".ecosystem-lane",
        ".assembly-band",
        ".assembly-stage",
        ".assembly-copy h2",
        ".token-shower",
        ".assembly-rail",
        ".assembly-output",
        ".matrix-lab-band",
        ".matrix-lab-stage",
        ".matrix-mode-switch",
        ".matrix-mode-switch button.is-active",
        ".matrix-orbit",
        ".matrix-orbit::before",
        ".matrix-truth-rail",
        ".matrix-truth-rail span::after",
        ".matrix-signal-stream",
        ".matrix-signal-stream span::before",
        ".matrix-lab-stage[data-matrix-state=\"budget\"]",
        ".matrix-lab-stage[data-matrix-state=\"proof\"] [data-matrix-node=\"proof\"]",
        ".matrix-decision-card",
        ".matrix-proof-row",
        "@keyframes matrixSignalTravel",
        "@keyframes tokenAssemble",
        ".launch-handoff-band",
        ".launch-command-card",
        ".surface-relay-panel",
        ".surface-relay-panel::before",
        ".launch-handoff-stage[data-active-surface=\"cli\"]",
        ".launch-handoff-stage[data-active-surface=\"pro\"]",
        ".surface-relay-meter span.is-active",
        ".surface-relay-facts",
        ".surface-relay-tabs button.is-active",
        ".handoff-flow",
        ".handoff-flow li.is-active",
        ".handoff-orbit",
        ".orbit-cli",
        ".orbit-menu",
        ".orbit-companion",
        ".orbit-studio",
        ".orbit-pro",
        ".runway-band",
        ".runway-board",
        ".runway-ring",
        ".proof-packet-band",
        ".proof-packet-card",
        ".proof-packet-grid",
        ".proof-packet-seal",
        ".reminder-composer-surface",
        ".reminder-mode-switch",
        ".reminder-plan-card",
        ".reminder-question-grid",
        ".reminder-boundary",
        ".memory-pressure-surface",
        ".memory-orbit",
        ".memory-lane-stack",
        ".memory-pressure-boundary",
        ".launch-kit-band",
        ".launch-kit-grid",
        ".launch-kit-copy",
        ".launch-demo-reel",
        ".launch-demo-strip",
        "grid-template-columns: repeat(7, minmax(0, 1fr))",
        "grid-template-columns: repeat(7, minmax(138px, 1fr))",
        "@media (max-width: 980px)",
        "@media (max-width: 560px)",
        "@media (prefers-reduced-motion: reduce)",
    ]
    for marker in required_css:
        require(marker in css, f"missing CSS marker: {marker}")

    required_js = [
        "panel.hidden = !isActive",
        "const storySignalCopy = [",
        "storyConsole?.setAttribute(\"data-active-story\", activeLayer)",
        "storySignal.textContent = storySignalCopy[nextIndex]",
        'tab.setAttribute("aria-selected", String(isActive))',
        "tab.tabIndex = isActive ? 0 : -1",
        "storyDots.forEach",
        "storyTimer = window.setInterval",
        "showStoryPanel(storyIndex + 1)",
        "storyConsole?.addEventListener(\"pointerenter\", pauseStory)",
        "storyConsole?.addEventListener(\"focusin\", pauseStory)",
        "const operatingDeck = document.querySelector(\"[data-operating-deck]\")",
        "function showOperatingLayer(layer)",
        "data-operating-tab",
        '["ArrowLeft", "ArrowRight", "Home", "End"]',
        "restartStoryTimer()",
        "showStoryPanel(0)",
        "function updateReminderMode",
        "updateReminderMode(\"steady\")",
        "No notification is scheduled until you approve it.",
        "const matrixLab = document.querySelector(\"[data-matrix-lab]\")",
        "function updateMatrixMode(modeName)",
        "data-matrix-mode",
        "const matrixStreams",
        "matrixCore.textContent = mode.core",
        "stream.textContent = mode.streams?.[index]",
        "updateMatrixMode(\"budget\")",
        "const surfaceRelay = document.querySelector(\"[data-surface-relay]\")",
        "function updateSurfaceRelay(surfaceName)",
        "data-surface-tab",
        "surfaceTitle.textContent = mode.title",
        "surfaceGate.textContent = mode.gate",
        "updateSurfaceRelay(surfaceRelay.dataset.activeSurface || \"menu\")",
    ]
    for marker in required_js:
        require(marker in js, f"missing JS marker: {marker}")

    forbidden = [
        "Gemini</button>",
        "fake certainty",
    ]
    for marker in forbidden:
        require(marker not in index, f"forbidden stale marker remains: {marker}")

    for cli, label in [(SRC_CLI, "src"), (BIN_CLI, "bin")]:
        result = subprocess.run(
            [str(cli), "ecosystem", "json"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=45,
            check=False,
        )
        require(result.returncode == 0, f"{label} ecosystem json failed: {result.stderr or result.stdout}")
        payload = json.loads(result.stdout)
        require(payload.get("schema") == "tokenbar.ecosystem.v1", f"{label} ecosystem schema mismatch")
        assembly = payload.get("assemblyRail") or []
        require([row.get("step") for row in assembly] == ["Account", "Analyze", "MCQ", "Budget", "Reminder", "Playbook", "Proof"], f"{label} assembly rail order mismatch")
        rail_text = " ".join(row.get("proof", "") for row in assembly)
        for marker in ["active local account", "private aggregate bundle", "interpretation question", "scheduling behind approval", "safe cost passport"]:
            require(marker in rail_text, f"{label} assembly rail missing {marker}")

    print("website_storytelling_surface: PASS")


if __name__ == "__main__":
    main()
