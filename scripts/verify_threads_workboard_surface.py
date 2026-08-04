#!/usr/bin/env python3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
THREADS_HTML = ROOT / "docs" / "threads.html"
APP_JS = ROOT / "docs" / "app.js"
STYLES_CSS = ROOT / "docs" / "styles.css"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def main() -> None:
    threads_html = THREADS_HTML.read_text(encoding="utf-8")
    app_js = APP_JS.read_text(encoding="utf-8")
    styles_css = STYLES_CSS.read_text(encoding="utf-8")

    html_markers = [
        "thread-board-tools",
        "Plan locally",
        "never rewrites Codex's database",
        "data-thread-reset-board",
        "data-thread-board",
        "localhost bridge",
        "No transcripts, source files, or full paths leave this Mac",
    ]
    for marker in html_markers:
        require(marker in threads_html, f"threads page missing marker: {marker}")

    js_markers = [
        'THREAD_BOARD_STORAGE_KEY = "tokenbar:localThreadBoard:v1"',
        "THREAD_LANE_META",
        'active: { label: "Now"',
        'attention: { label: "Decide"',
        'paused: { label: "Later"',
        'recent: { label: "Review"',
        'done: { label: "Archive"',
        "function bindThreadBoardDrag",
        'draggable="true"',
        "data-thread-id",
        "data-thread-lane-list",
        "data-thread-lane-count",
        "updateLaneCounts();",
        "saveThreadBoardPlan(plan)",
        "localStorage.removeItem(THREAD_BOARD_STORAGE_KEY)",
    ]
    for marker in js_markers:
        require(marker in app_js, f"threads renderer missing marker: {marker}")

    css_markers = [
        ".thread-board-tools",
        ".thread-lane.is-drop-target",
        ".thread-card.is-dragging",
        ".thread-card-plan",
        "cursor: grab",
    ]
    for marker in css_markers:
        require(marker in styles_css, f"threads styles missing marker: {marker}")

    require(
        app_js.index("loadThreadBoardPlan") < app_js.index("renderLocalThreads") < app_js.index("bindThreadBoardDrag();"),
        "thread board should load local plan before rendering and bind drag after render",
    )
    print("Threads workboard surface verified")


if __name__ == "__main__":
    main()
