#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
BIN_CLI = ROOT / "bin" / "tokenbar"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def run_json(cli: Path, env: dict[str, str], *extra_args: str) -> dict:
    result = subprocess.run(
        [str(cli), "cost-passport", *extra_args, "json"],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=45,
        check=False,
    )
    require(result.returncode == 0, f"{cli} cost-passport json failed: {result.stderr or result.stdout}")
    return json.loads(result.stdout)


def validate_payload(payload: dict, label: str) -> None:
    require(payload.get("schema") == "tokenbar.cost_passport.v1", f"{label} schema mismatch")
    require(payload.get("source") == "local-usage-index", f"{label} source mismatch")
    summary = payload.get("summary") or {}
    limits = payload.get("limits") or {}
    privacy = payload.get("privacy") or {}
    require(summary.get("last30Tokens") == 950_000_000, f"{label} last30 token total mismatch")
    require(summary.get("estimated30dCost") == "$2,375", f"{label} estimated 30d cost mismatch")
    require(summary.get("selectedRangeTokens") == 950_000_000, f"{label} default selected range token total mismatch")
    require(summary.get("selectedRangeCost") == "$2,375", f"{label} default selected range cost mismatch")
    require(summary.get("projectedWeeklyCost"), f"{label} missing projected weekly cost")
    range_passport = payload.get("rangePassport") or {}
    require(range_passport.get("command") == "tokenbar cost-passport --from YYYY-MM-DD --to YYYY-MM-DD json", f"{label} range command mismatch")
    require(isinstance(range_passport.get("selectedRows"), list), f"{label} selected rows should be a list")
    require(range_passport.get("copy") == "Use this selected-range passport for planning; do not call it an invoice.", f"{label} range copy mismatch")
    require(limits.get("dailyCost") == "$25.00", f"{label} daily cost limit mismatch")
    require(limits.get("weeklyCost") == "$100", f"{label} weekly cost limit mismatch")
    require(limits.get("dailyTokens") == "100M", f"{label} daily token limit mismatch")
    require(payload.get("nextAction"), f"{label} missing next action")
    require(isinstance(payload.get("wasteFlags"), list), f"{label} waste flags should be a list")
    for key in ["rawReportIncluded", "rawTranscriptsIncluded", "sourceCodeIncluded", "localPathsIncluded", "credentialsIncluded"]:
        require(privacy.get(key) is False, f"{label} privacy {key} should be false")
    require(privacy.get("safeForSelectiveShare") is True, f"{label} should be share-safe")
    serialized = json.dumps(payload, sort_keys=True)
    for forbidden in ["/Users/", "session-a.jsonl", "session-b.jsonl", "sk-", "PRIVATE_PROMPT"]:
        require(forbidden not in serialized, f"{label} leaked forbidden marker {forbidden}")


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="tokenbar-cost-passport-") as temp:
        home = Path(temp) / "home"
        support = home / "Library" / "Application Support" / "CodexLimitBar"
        support.mkdir(parents=True)
        (support / "usage-index.json").write_text(
            json.dumps(
                {
                    "updatedAt": 1780000000,
                    "dayTokens": {
                        "2026-07-20": 100_000_000,
                        "2026-07-21": 250_000_000,
                        "2026-07-22": 0,
                        "2026-07-23": 600_000_000,
                    },
                    "modelTokens": {"gpt-5.4": 700_000_000, "opencode": 250_000_000},
                    "folderTokens": {
                        "/Users/example/private/agent-lab": 650_000_000,
                        "/Users/example/private/app-studio": 300_000_000,
                    },
                    "folderSessionPaths": {
                        "/Users/example/private/agent-lab": ["/Users/example/private/session-a.jsonl"],
                        "/Users/example/private/app-studio": ["/Users/example/private/session-b.jsonl"],
                    },
                    "activeFolderPaths": ["/Users/example/private/agent-lab"],
                    "sessionPaths": ["/Users/example/private/session-a.jsonl", "/Users/example/private/session-b.jsonl"],
                }
            ),
            encoding="utf-8",
        )
        (support / "user-controls.json").write_text(
            json.dumps(
                {
                    "logTrackingEnabled": True,
                    "activitySignalsEnabled": True,
                    "dailyGuardrailTokens": "100M",
                    "weeklyGuardrailTokens": "1B",
                    "thirtyDayGuardrailTokens": "5B",
                    "dailyCostLimitUSD": "25",
                    "weeklyCostLimitUSD": "100",
                }
            ),
            encoding="utf-8",
        )

        env = os.environ.copy()
        env["HOME"] = str(home)
        env["TOKENBAR_SUPPORT_DIR"] = str(support)
        env["TOKENBAR_PRICE_PER_MILLION"] = "2.5"

        src_payload = run_json(SRC_CLI, env)
        bin_payload = run_json(BIN_CLI, env)
        validate_payload(src_payload, "src")
        validate_payload(bin_payload, "bin")
        require(src_payload["summary"]["last30Tokens"] == bin_payload["summary"]["last30Tokens"], "src/bin cost-passport totals drifted")

        range_payload = run_json(SRC_CLI, env, "--from", "2026-07-21", "--to", "2026-07-23")
        range_summary = range_payload.get("summary") or {}
        range_window = range_payload.get("window") or {}
        range_passport = range_payload.get("rangePassport") or {}
        require(range_window.get("label") == "selected local cost range", "range passport label mismatch")
        require(range_window.get("start") == "2026-07-21", "range start mismatch")
        require(range_window.get("end") == "2026-07-23", "range end mismatch")
        require(range_window.get("activeDays") == 2, "range active days mismatch")
        require(range_summary.get("selectedRangeTokens") == 850_000_000, "range selected token total mismatch")
        require(range_summary.get("selectedRange") == "850M", "range selected compact mismatch")
        require(range_summary.get("selectedRangeCost") == "$2,125", "range selected cost mismatch")
        require(range_summary.get("selectedPeakDay") == "2026-07-23", "range peak day mismatch")
        require(range_summary.get("selectedPeak") == "600M", "range peak compact mismatch")
        selected_rows = range_passport.get("selectedRows") or []
        require(len(selected_rows) == 3, "range selected rows should include three dated rows")
        require(all("date" in row and "tokens" in row and "compact" in row for row in selected_rows), "range rows missing safe aggregate fields")

    launch_payload = json.loads(
        subprocess.run(
            [str(BIN_CLI), "launch-kit", "json"],
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=45,
            check=True,
        ).stdout
    )
    require(launch_payload["product"].get("costCommand") == "tokenbar cost-passport", "launch kit missing cost command")
    checklist = " ".join(item.get("proof", "") for item in launch_payload.get("checklist") or [])
    require("tokenbar cost-passport json" in checklist, "launch checklist missing cost passport proof")

    print("cost_passport_contract: PASS")


if __name__ == "__main__":
    main()
