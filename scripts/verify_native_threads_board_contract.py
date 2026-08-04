#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "macos/TokenBarMac/Sources/TokenBarMac/TokenBarModel.swift"
VIEWS = ROOT / "macos/TokenBarMac/Sources/TokenBarMac/TokenBarViews.swift"
TESTS = ROOT / "macos/TokenBarMac/Tests/TokenBarMacTests/ThreadBoardConfigurationTests.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    model = MODEL.read_text(encoding="utf-8")
    views = VIEWS.read_text(encoding="utf-8")
    tests = TESTS.read_text(encoding="utf-8")

    for marker in [
        'name: "Project Finish Line"',
        'queuedTitle: "Waiting"',
        'focusTitle: "Working"',
        'recentTitle: "Next"',
        'reviewTitle: "Check"',
        'doneTitle: "Complete"',
        'accentName: "cyan"',
        '?? "Waiting"',
        '?? "Complete"',
    ]:
        require(marker in model, f"thread board model missing marker: {marker}")

    for stale in [
        'queuedTitle: "Queue"',
        'focusTitle: "Now"',
        'recentTitle: "Fresh"',
        'reviewTitle: "Revisit"',
    ]:
        require(stale not in model, f"thread board model still contains stale default: {stale}")

    for marker in [
        'Text(isDropTarget ? "Drop to place in \\(title)" : "Drag a thread here")',
        "plannedLaneTitle: title",
        "let plannedLaneTitle: String",
        'Text("-> \\(plannedLaneTitle)")',
        "Codex's database is never rewritten",
    ]:
        require(marker in views, f"thread board view missing marker: {marker}")

    require('#expect(board.queuedTitle == "Waiting")' in tests, "legacy migration test does not expect Waiting")
    require('#expect(board.doneTitle == "Complete")' in tests, "legacy migration test does not expect Complete")
    print("TokenBar native threads board contract passed")


if __name__ == "__main__":
    main()
