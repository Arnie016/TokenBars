#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROFILE_HTML = ROOT / "docs" / "profile.html"
STYLES_CSS = ROOT / "docs" / "styles.css"
APP_JS = ROOT / "docs" / "app.js"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    profile_html = PROFILE_HTML.read_text(encoding="utf-8")
    styles_css = STYLES_CSS.read_text(encoding="utf-8")
    app_js = APP_JS.read_text(encoding="utf-8")

    html_markers = [
        "profile-identity-chronicle",
        "Profile chronicle",
        "Your identity is assigned by the evidence",
        "No form is better than another.",
        "Revenue Engine Pilot",
        "Prototype Cartographer",
        "Launch Trialsmith",
        "local aggregate evidence only",
        "identity-heatmap-grid",
        "identity-era-strip",
        "data-profile-chronicle",
        "data-profile-chronicle-title",
        "data-profile-chronicle-copy",
        "data-profile-chronicle-proof-days",
        "data-profile-chronicle-boundary",
        "data-profile-chronicle-heatmap",
        "data-profile-chronicle-eras",
        'aria-label="Explain TokenBar identity categories"',
    ]
    for marker in html_markers:
        require(marker in profile_html, f"profile chronicle missing HTML marker: {marker}")

    css_markers = [
        ".profile-identity-chronicle",
        ".identity-heatmap-card",
        ".identity-heatmap-grid",
        ".identity-heatmap-grid i[data-level=\"5\"]",
        ".identity-era-strip",
        "@media (max-width: 980px)",
        "@media (max-width: 560px)",
    ]
    for marker in css_markers:
        require(marker in styles_css, f"profile chronicle missing CSS marker: {marker}")

    require(
        profile_html.index('<section class="profile-proof-strip"')
        < profile_html.index('<section class="profile-identity-chronicle"')
        < profile_html.index('<section class="token-dock"'),
        "profile chronicle should sit between privacy contract and token dock",
    )
    require(
        "Raw logs stay local" in profile_html and "local aggregate evidence only" in profile_html,
        "profile chronicle must preserve the raw-local and aggregate-only boundary",
    )
    js_markers = [
        "const profileChronicle = document.querySelector(\"[data-profile-chronicle]\")",
        "function profileChronicleCells",
        "function profileChronicleEras",
        "function renderProfileChronicle",
        "profile?.selfComparison?.cards",
        "No identity is better than another.",
        "safe profile aggregates only; raw prompts, source code, credentials, and local paths stay local",
        "renderProfileChronicle(profile);",
    ]
    for marker in js_markers:
        require(marker in app_js, f"profile chronicle missing JS marker: {marker}")

    print("Profile chronicle surface verified")


if __name__ == "__main__":
    main()
