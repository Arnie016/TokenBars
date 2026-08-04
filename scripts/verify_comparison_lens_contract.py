#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
API_PATH = ROOT / "src/tokenbar/identity_api.py"
CLI_PATH = ROOT / "bin/tokenbar"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load_identity_api():
    spec = importlib.util.spec_from_file_location("tokenbar_identity_api", API_PATH)
    require(spec is not None and spec.loader is not None, "could not load identity_api module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_usage_index(root: Path) -> None:
    support = root / "Library/Application Support/CodexLimitBar"
    support.mkdir(parents=True)
    day_tokens = {
        "2026-07-01": 120_000_000,
        "2026-07-02": 0,
        "2026-07-03": 180_000_000,
        "2026-07-04": 240_000_000,
        "2026-07-05": 0,
        "2026-07-06": 310_000_000,
        "2026-07-07": 420_000_000,
        "2026-07-08": 140_000_000,
        "2026-07-09": 0,
        "2026-07-10": 520_000_000,
        "2026-07-11": 210_000_000,
        "2026-07-12": 330_000_000,
        "2026-07-13": 0,
        "2026-07-14": 610_000_000,
    }
    (support / "usage-index.json").write_text(
        json.dumps(
            {
                "updatedAt": "2026-07-14T12:00:00Z",
                "dayTokens": day_tokens,
                "modelTokens": {"gpt-5": sum(day_tokens.values())},
                "sessionPaths": ["session-a", "session-b"],
                "activeFolderPaths": ["project-a"],
            }
        ),
        encoding="utf-8",
    )


def verify_api(temp_home: Path) -> None:
    api = load_identity_api()
    payload = api.comparison_lens_payload(temp_home / "Library/Application Support/CodexLimitBar")
    require(payload["schema"] == "tokenbar.comparison_lens.v1", "api schema mismatch")
    require(payload["summary"]["cohortState"] == "local-only", "api must stay local-only by default")
    require(payload["summary"]["percentile"] is None, "api must not invent a percentile")
    require(payload["claimPolicy"]["minimumCohortForPercentile"] == 10, "api minimum cohort policy missing")
    require("top 1% claims without a measured opt-in cohort" in payload["claimPolicy"]["blocked"], "api missing fake percentile blocker")
    require(len(payload["cards"]) == 4, "api must expose four comparison cards")
    require(payload["privacy"]["rawPromptsIncluded"] is False, "api privacy must exclude raw prompts")
    require(payload["privacy"]["populationClaims"] is False, "api privacy must reject population claims")


def verify_cli(temp_home: Path) -> None:
    env = {**os.environ, "HOME": str(temp_home), "TOKENBAR_SUPPORT_DIR": str(temp_home / "Library/Application Support/CodexLimitBar")}
    result = subprocess.run(
        [str(CLI_PATH), "comparison-lens", "json"],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    require(result.returncode == 0, f"cli comparison-lens json failed: {result.stderr or result.stdout}")
    payload = json.loads(result.stdout)
    require(payload["schema"] == "tokenbar.comparison_lens.v1", "cli schema mismatch")
    require(payload["summary"]["percentileStatus"] == "locked until an opt-in cohort exists", "cli percentile lock missing")
    require(any(card["key"] == "cost-control" for card in payload["cards"]), "cli missing cost-control card")
    require(payload["claimPolicy"]["minimumCohortForPercentile"] == 10, "cli missing cohort policy")
    require(payload["privacy"]["sourceCodeIncluded"] is False, "cli privacy must exclude source code")

    text = subprocess.run(
        [str(CLI_PATH), "comparison-lens"],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    require(text.returncode == 0, f"cli comparison-lens text failed: {text.stderr or text.stdout}")
    require("TokenBar Comparison Lens" in text.stdout, "cli text header missing")
    require("percentile: locked" in text.stdout, "cli text must show locked percentile")
    require("Blocked: top-percentile claims without cohort data" in text.stdout, "cli text must state blocked fake percentile")


def verify_homepage_contract() -> None:
    index = (ROOT / "docs/index.html").read_text(encoding="utf-8")
    styles = (ROOT / "docs/styles.css").read_text(encoding="utf-8")
    for marker in [
        'data-operating-tab="compare"',
        'data-operating-panel="compare"',
        "Comparison lens",
        "Rank the pattern, not the person.",
        "tokenbar comparison-lens json",
    ]:
        require(marker in index, f"homepage missing marker: {marker}")
    require("grid-template-columns: repeat(6, minmax(0, 1fr));" in styles, "operating deck needs six desktop columns")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="tokenbar-comparison-lens-") as raw:
        temp_home = Path(raw)
        write_usage_index(temp_home)
        verify_api(temp_home)
        verify_cli(temp_home)
    verify_homepage_contract()
    print("comparison_lens_contract: PASS")


if __name__ == "__main__":
    main()
