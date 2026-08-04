#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INDEX = ROOT / "docs" / "index.html"
CSS = ROOT / "docs" / "styles.css"
JS = ROOT / "docs" / "app.js"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    index = INDEX.read_text(encoding="utf-8")
    css = CSS.read_text(encoding="utf-8")
    js = JS.read_text(encoding="utf-8")

    required_html = [
        'class="cost-passport-surface"',
        'id="cost-passport"',
        "Drag a range. Get a receipt you can act on.",
        'data-cost-passport-demo',
        'data-cost-range-start',
        'data-cost-range-end',
        'data-cost-range-control="start"',
        'data-cost-range-control="end"',
        'data-cost-total',
        'data-cost-story',
        'data-cost-forecast',
        'data-cost-forecast-band',
        'data-cost-reminder',
        'data-cost-playbook',
        'data-cost-provider-stamp="codex"',
        'data-cost-provider-share',
        'data-cost-provider-note',
        "TokenBar Cost Passport",
        "local estimate",
        "Codex",
        "OpenCode",
        "Antigravity",
        "Cursor",
        "Forecast band",
        "Error bars stay visible",
        "Reminder draft",
        "Suggested only",
        "Cheaper next prompt",
        "Verifier First",
        "Raw prompts, transcripts",
        "credentials, and private diffs stay out",
        "tokenbar cost-passport --from 2026-06-02 --to 2026-08-02 json",
    ]
    for marker in required_html:
        require(marker in index, f"missing cost passport HTML marker: {marker}")

    required_css = [
        ".cost-passport-surface",
        ".cost-passport-range",
        ".passport-spread",
        ".passport-cover",
        ".passport-material",
        ".passport-stamps",
        ".passport-decision-grid",
        ".passport-forecast div::before",
        ".passport-boundary",
        "--passport-heat",
        "@media (max-width: 980px)",
        "@media (max-width: 560px)",
        "@media (prefers-reduced-motion: reduce)",
        ".passport-cover::before",
    ]
    for marker in required_css:
        require(marker in css, f"missing cost passport CSS marker: {marker}")

    required_js = [
        'document.querySelector("[data-cost-passport-demo]")',
        "dateForRangeValue",
        "updateCostPassportDemo",
        'querySelector(\'[data-cost-range-control="start"]\')',
        'querySelector(\'[data-cost-range-control="end"]\')',
        "startControl?.addEventListener(\"input\", updateCostPassportDemo)",
        "endControl?.addEventListener(\"input\", updateCostPassportDemo)",
        "passportCover?.style.setProperty(\"--passport-heat\"",
        "providerStamps.forEach",
        "forecastLabel.textContent",
        "reminderLabel.textContent",
        "playbookLabel.textContent",
        "--forecast-mid",
        "budget reminders stay suggested-only",
        "Peak burn around",
    ]
    for marker in required_js:
        require(marker in js, f"missing cost passport JS marker: {marker}")

    section = index.split('class="cost-passport-surface"', 1)[1].split("</section>", 1)[0]
    require("<table" not in section.lower(), "cost passport surface should not be a table of stats")
    require(section.count("<article") >= 8, "cost passport needs passport, stamp, and decision article surfaces")

    print("cost_passport_surface: PASS")


if __name__ == "__main__":
    main()
