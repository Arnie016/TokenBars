#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIEWS = ROOT / "macos/TokenBarMac/Sources/TokenBarMac/TokenBarViews.swift"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> None:
    source = VIEWS.read_text(encoding="utf-8")
    required_markers = [
        "BuilderActivityHeatMap(",
        "Evidence heat map",
        "Your local build rhythm, not a scoreboard",
        "BuilderHeatWeekSummary",
        "BuilderHeatSignalPill",
        "Cadence",
        "Peak day",
        "Quiet weeks",
        "Aggregate activity only · prompts and code are not read here",
    ]
    for marker in required_markers:
        require(marker in source, f"native profile heatmap missing marker: {marker}")

    profile_index = source.index("private struct ProfileView")
    heatmap_index = source.index("BuilderActivityHeatMap(", profile_index)
    cost_index = source.index("Local cost estimate", profile_index)
    require(heatmap_index < cost_index, "native heatmap should appear before cost estimate details")
    require("raw prompts" in source and "prompts and code are not read here" in source, "privacy boundary missing")
    print("TokenBar native profile heatmap contract passed")


if __name__ == "__main__":
    main()
