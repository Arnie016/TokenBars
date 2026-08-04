#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "docs" / "index.html"
CSS = ROOT / "docs" / "styles.css"
JS = ROOT / "docs" / "app.js"


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def section_between(html, start, end):
    begin = html.find(start)
    require(begin != -1, f"missing section start: {start}")
    finish = html.find(end, begin)
    require(finish != -1, f"missing section end after {start}: {end}")
    return html[begin:finish]


def main():
    index = INDEX.read_text()
    css = CSS.read_text()
    js = JS.read_text()

    section = section_between(index, 'class="reminder-composer-surface"', 'id="how"')

    required_html = [
        'class="reminder-composer-surface"',
        "data-reminder-composer",
        "Reminder composer",
        "Set the guardrail before the run starts.",
        "tokenbar reminders json",
        'data-reminder-mode="steady"',
        'data-reminder-mode="focus"',
        'data-reminder-mode="strict"',
        'data-reminder-preview-title',
        'data-reminder-preview-copy',
        'data-reminder-preview-threshold',
        "Suggested-only",
        "Requires approval",
        "does not schedule notifications",
        "contact providers",
        "close apps",
        "raw prompts",
        "source code",
        "credentials",
        "private diffs",
        "Sound and haptics off by default",
    ]
    for marker in required_html:
        require(marker in section, f"missing reminder composer marker: {marker}")

    require("<table" not in section.lower(), "reminder composer must not fall back to a table")
    require("Stripe" not in section, "reminder composer must not sell before explaining the guardrail")
    require("schedule" in section and "approve" in section, "composer needs explicit schedule and approval language")

    required_css = [
        ".reminder-composer-surface",
        ".reminder-mode-switch",
        ".reminder-plan-card",
        ".reminder-threshold-meter",
        ".reminder-question-grid",
        ".reminder-boundary",
        "--threshold",
        "grid-template-columns: repeat(4, minmax(0, 1fr))",
    ]
    for marker in required_css:
        require(marker in css, f"missing reminder composer CSS marker: {marker}")

    required_js = [
        'document.querySelector("[data-reminder-composer]")',
        "const reminderModes",
        "function updateReminderMode",
        "reminderThreshold.style.setProperty",
        "warning threshold",
        "No notification is scheduled until you approve it.",
        "require a checkpoint question",
        "updateReminderMode(\"steady\")",
    ]
    for marker in required_js:
        require(marker in js, f"missing reminder composer JS marker: {marker}")

    forbidden_js = [
        "new Notification(",
        "Notification.requestPermission",
        "fetch(\"https://",
        "fetch('https://",
    ]
    composer_js = js[js.find("const reminderComposer"):]
    composer_js = composer_js[:composer_js.find("const personaCards")]
    for marker in forbidden_js:
        require(marker not in composer_js, f"forbidden live action in composer JS: {marker}")

    print("reminder_composer_surface: PASS")


if __name__ == "__main__":
    main()
