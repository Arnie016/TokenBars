from __future__ import annotations

import argparse
from collections import defaultdict
import json
import os
import re
import subprocess
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


IDENTITY_FIELDS = {
    "schema",
    "generatedAt",
    "title",
    "subtitle",
    "primaryArchetype",
    "npcClass",
    "identityLabel",
    "labelRationale",
    "archetypeDistribution",
    "modifierDistribution",
    "stanceDistribution",
    "labelDistribution",
    "labelModel",
    "specificityScore",
    "estimatedRarityPercent",
    "proofScore",
    "loopMaturity",
    "loopScore",
    "loopScale",
    "dimensions",
    "signatureMoves",
    "curiousFacts",
    "growthEdge",
    "usage",
    "sessionAnalysis",
    "shippingAnalysis",
    "leaderboard",
}

BLOCKED_KEY_PARTS = (
    "path",
    "transcript",
    "sourcecode",
    "source_code",
    "secret",
    "credential",
    "rawcontent",
    "raw_content",
)
BLOCKED_KEYS = {
    "token",
    "email",
    "prompt",
    "prompts",
    "prompttext",
    "prompt_text",
    "promptcontent",
    "prompt_content",
    "signaturephrases",
    "signature_phrases",
    "excerpts",
    "rawexcerpts",
    "raw_excerpts",
}
LOCAL_PATH_RE = re.compile(
    r"(?:/Users/[^/\s]+|/home/[^/\s]+|/private/var|/var/folders|/tmp)(?:/[^\s\"']*)?"
)
SECRET_RE = re.compile(r"\b(?:sk|whsec|ghp|github_pat|xox[baprs])[-_][A-Za-z0-9_-]{8,}\b")


def support_dir() -> Path:
    override = os.environ.get("TOKENBAR_SUPPORT_DIR")
    if override:
        return Path(override).expanduser()
    return Path.home() / "Library/Application Support/CodexLimitBar"


def latest_identity(root: Path) -> Path | None:
    candidates = list((root / "profiles").glob("*.identity.json"))
    return max(candidates, key=lambda item: item.stat().st_mtime) if candidates else None


def _blocked_key(key: str) -> bool:
    normalized = key.replace("-", "_").lower()
    return normalized in BLOCKED_KEYS or any(part in normalized for part in BLOCKED_KEY_PARTS)


def sanitize(value: Any, *, key: str = "", depth: int = 0) -> Any:
    if depth > 8:
        return None
    if key and _blocked_key(key):
        return None
    if value is None or isinstance(value, (bool, int, float)):
        return value
    if isinstance(value, str):
        text = LOCAL_PATH_RE.sub("[local path]", value.replace("\x00", ""))
        text = SECRET_RE.sub("[redacted secret]", text)
        return text[:1200]
    if isinstance(value, list):
        cleaned = [sanitize(item, depth=depth + 1) for item in value[:100]]
        return [item for item in cleaned if item is not None]
    if isinstance(value, dict):
        cleaned: dict[str, Any] = {}
        for child_key, child_value in list(value.items())[:100]:
            name = str(child_key)[:100]
            safe_value = sanitize(child_value, key=name, depth=depth + 1)
            if safe_value is not None:
                cleaned[name] = safe_value
        return cleaned
    return str(value)[:1200]


def privacy_receipt() -> dict[str, Any]:
    return {
        "schema": "tokenbar.safe_local_api.v1",
        "localOnlyByDefault": True,
        "rawTranscriptsIncluded": False,
        "sourceCodeIncluded": False,
        "localPathsIncluded": False,
        "secretsIncluded": False,
        "material": "generated identity fields and aggregate usage only",
    }


def identity_payload(root: Path) -> dict[str, Any] | None:
    path = latest_identity(root)
    if not path:
        return None
    try:
        source = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if not isinstance(source, dict):
        return None
    privacy = source.get("privacy") if isinstance(source.get("privacy"), dict) else {}
    if privacy.get("rawTranscriptsIncluded") or privacy.get("sourceCodeIncluded"):
        return None
    selected = {name: source[name] for name in IDENTITY_FIELDS if name in source}
    return {
        "ok": True,
        "identity": sanitize(selected),
        "privacy": privacy_receipt(),
    }


def _safe_number(value: Any) -> int:
    try:
        return max(0, int(float(value or 0)))
    except (TypeError, ValueError):
        return 0


def _compact_tokens(value: Any) -> str:
    numeric = _safe_number(value)
    if numeric >= 1_000_000_000:
        return f"{numeric / 1_000_000_000:.2f}B".replace(".00B", "B")
    if numeric >= 1_000_000:
        return f"{numeric / 1_000_000:.1f}M".replace(".0M", "M")
    if numeric >= 1_000:
        return f"{numeric / 1_000:.1f}K".replace(".0K", "K")
    return str(numeric)


def _run_local(args: list[str]) -> str:
    try:
        return subprocess.run(
            args,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=1.2,
            check=False,
        ).stdout
    except Exception:
        return ""


def _total_memory_mb() -> int | None:
    raw = _run_local(["sysctl", "-n", "hw.memsize"]).strip()
    try:
        return round(int(raw) / 1024 / 1024)
    except Exception:
        return None


def _memory_category(name: str) -> str:
    lower = name.lower()
    if any(marker in lower for marker in ["chrome", "chromium", "arc", "safari", "brave", "firefox"]):
        return "browser"
    if any(marker in lower for marker in ["codex", "chatgpt", "claude", "cursor", "antigravity", "opencode", "code helper", "electron"]):
        return "agent_workspace"
    if any(marker in lower for marker in ["node", "python", "ruby", "java", "uvicorn", "vite", "next-server"]):
        return "local_runtime"
    if any(marker in lower for marker in ["blender", "unreal", "xcode", "simulator", "figma"]):
        return "creative_runtime"
    return "other"


def memory_pressure_payload() -> dict[str, Any]:
    output = _run_local(["ps", "-axo", "pid=,rss=,comm="])
    rows: list[dict[str, Any]] = []
    for line in output.splitlines():
        parts = line.strip().split(None, 2)
        if len(parts) != 3:
            continue
        pid_raw, rss_raw, command = parts
        try:
            rss_mb = int(rss_raw) / 1024
            pid = int(pid_raw)
        except (TypeError, ValueError):
            continue
        if rss_mb < 20:
            continue
        rows.append({"pid": pid, "name": (Path(command).name or command)[:72], "rssMb": round(rss_mb, 1)})

    category_totals: defaultdict[str, float] = defaultdict(float)
    category_counts: defaultdict[str, int] = defaultdict(int)
    top_by_name: dict[str, dict[str, Any]] = {}
    for row in rows:
        category = _memory_category(str(row["name"]))
        category_totals[category] += float(row["rssMb"])
        category_counts[category] += 1
        current = top_by_name.get(str(row["name"]), {"name": row["name"], "rssMb": 0.0, "count": 0})
        current["rssMb"] += float(row["rssMb"])
        current["count"] += 1
        top_by_name[str(row["name"])] = current

    total_rss = sum(float(row["rssMb"]) for row in rows)
    memory_total = _total_memory_mb()
    observed_percent = round((total_rss / memory_total) * 100) if memory_total else None
    browser_agent_mb = category_totals["browser"] + category_totals["agent_workspace"]

    if observed_percent is None:
        pressure = "unknown"
    elif observed_percent >= 72 or browser_agent_mb >= 8192:
        pressure = "high"
    elif observed_percent >= 48 or browser_agent_mb >= 4096:
        pressure = "watch"
    else:
        pressure = "clear"

    categories = [
        {
            "name": name,
            "rssMb": round(value, 1),
            "processes": category_counts[name],
            "sharePercent": round((value / total_rss) * 100) if total_rss else 0,
        }
        for name, value in sorted(category_totals.items(), key=lambda item: item[1], reverse=True)
    ]
    top_apps = [
        {"name": row["name"], "rssMb": round(float(row["rssMb"]), 1), "processes": row["count"]}
        for row in sorted(top_by_name.values(), key=lambda item: float(item["rssMb"]), reverse=True)[:6]
    ]

    actions: list[dict[str, Any]] = []
    if browser_agent_mb >= 4096:
        actions.append(
            {
                "title": "Review browser plus agent pressure",
                "why": "Browser and AI-agent workspaces are the largest combined lane.",
                "approvalRequired": True,
                "safeNext": "Open TokenBar, review windows, then approve any close/reopen/restore plan manually.",
            }
        )
    if category_totals["local_runtime"] >= 2048:
        actions.append(
            {
                "title": "Check local dev servers",
                "why": "Local runtimes are using enough memory to matter.",
                "approvalRequired": True,
                "safeNext": "List the relevant servers first; do not stop a process without naming it and getting approval.",
            }
        )
    if not actions:
        actions.append(
            {
                "title": "No cleanup suggested",
                "why": "Observed app memory is below TokenBar's review threshold.",
                "approvalRequired": True,
                "safeNext": "Keep tracking. If the Mac feels slow, rerun this command before opening more heavy tools.",
            }
        )

    return {
        "ok": True,
        "schema": "tokenbar.memory_pressure.v1",
        "generatedAt": time.time(),
        "source": "local-ps-aggregate",
        "summary": {
            "pressure": pressure,
            "observedAppMemoryMb": round(total_rss, 1),
            "systemMemoryMb": memory_total,
            "observedPercent": observed_percent,
            "browserAgentMemoryMb": round(browser_agent_mb, 1),
            "basis": "process names and RSS only; no browser tabs, prompts, source files, command arguments, or credentials",
        },
        "categories": categories,
        "topApps": top_apps,
        "actions": actions[:4],
        "privacy": {
            **privacy_receipt(),
            "rawPromptsIncluded": False,
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "localPathsIncluded": False,
            "commandArgumentsIncluded": False,
            "credentialsIncluded": False,
            "browserTabsIncluded": False,
            "processKill": False,
            "browserRestore": False,
            "externalActions": False,
        },
        "disclaimer": "Read-only memory pressure explanation. No apps are closed, no browser windows are restored, and no external actions are taken.",
    }


def _parse_token_limit(raw: Any) -> int | None:
    if raw in {None, ""}:
        return None
    text = str(raw).strip().lower().replace(",", "")
    multiplier = 1
    if text.endswith("b"):
        multiplier = 1_000_000_000
        text = text[:-1]
    elif text.endswith("m"):
        multiplier = 1_000_000
        text = text[:-1]
    elif text.endswith("k"):
        multiplier = 1_000
        text = text[:-1]
    try:
        return max(0, int(float(text) * multiplier))
    except (TypeError, ValueError):
        return None


def _load_controls(root: Path) -> dict[str, Any]:
    try:
        controls = json.loads((root / "user-controls.json").read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return controls if isinstance(controls, dict) else {}


def stats_payload(root: Path) -> dict[str, Any]:
    index_path = root / "usage-index.json"
    try:
        index = json.loads(index_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        index = {}
    if not isinstance(index, dict):
        index = {}

    day_tokens = index.get("dayTokens") if isinstance(index.get("dayTokens"), dict) else {}
    model_tokens = index.get("modelTokens") if isinstance(index.get("modelTokens"), dict) else {}
    sessions = index.get("sessionPaths") if isinstance(index.get("sessionPaths"), list) else []
    folders = index.get("activeFolderPaths") if isinstance(index.get("activeFolderPaths"), list) else []
    safe_days = {str(day)[:32]: _safe_number(tokens) for day, tokens in list(day_tokens.items())[-90:]}
    safe_models = {str(model)[:100]: _safe_number(tokens) for model, tokens in list(model_tokens.items())[:50]}
    total_tokens = sum(safe_models.values()) or sum(safe_days.values())
    return {
        "ok": True,
        "stats": {
            "updatedAt": index.get("updatedAt"),
            "totalTokens": total_tokens,
            "sessionCount": len(sessions),
            "activeDayCount": sum(1 for value in safe_days.values() if value > 0),
            "activeFolderCount": len(folders),
            "dayTokens": safe_days,
            "modelTokens": safe_models,
        },
        "privacy": privacy_receipt(),
    }


def reminders_payload(root: Path) -> dict[str, Any]:
    stats = stats_payload(root)["stats"]
    controls = _load_controls(root)
    day_tokens = stats.get("dayTokens") if isinstance(stats.get("dayTokens"), dict) else {}
    values = [_safe_number(value) for value in day_tokens.values()]
    today_tokens = values[-1] if values else 0
    last7_tokens = sum(values[-7:])
    last30_tokens = sum(values[-30:])
    active_days = sum(1 for value in values[-30:] if value > 0)
    projected_next7 = int((last7_tokens / max(1, min(7, len(values)))) * 7) if values else 0

    daily_limit = _parse_token_limit(controls.get("dailyGuardrailTokens"))
    weekly_limit = _parse_token_limit(controls.get("weeklyGuardrailTokens"))
    month_limit = _parse_token_limit(controls.get("thirtyDayGuardrailTokens"))
    reminders: list[dict[str, Any]] = []

    def add(kind: str, title: str, trigger: str, reason: str, action: str, severity: str = "info") -> None:
        reminders.append(
            {
                "kind": kind,
                "title": title,
                "trigger": trigger,
                "reason": reason,
                "action": action,
                "severity": severity,
                "delivery": "suggested-only",
                "requiresApproval": True,
            }
        )

    def pressure(numerator: int, denominator: int | None) -> int | None:
        if not denominator:
            return None
        return max(0, round((numerator / denominator) * 100))

    daily_pressure = pressure(today_tokens, daily_limit)
    if daily_pressure is not None and daily_pressure >= 80:
        add(
            "budget",
            "Daily token cap is close",
            f"{'>999%' if daily_pressure > 999 else str(daily_pressure) + '%'} of daily token guardrail",
            f"Today has used {_compact_tokens(today_tokens)} against a {_compact_tokens(daily_limit)} daily guardrail.",
            "Open a cost-saver playbook before the next long agent run.",
            "danger" if daily_pressure >= 100 else "warning",
        )

    weekly_pressure = pressure(projected_next7, weekly_limit)
    if weekly_pressure is not None and weekly_pressure >= 70:
        add(
            "forecast",
            "Projected week is heavy",
            f"{'>999%' if weekly_pressure > 999 else str(weekly_pressure) + '%'} of weekly token guardrail",
            f"The next 7 days project to {_compact_tokens(projected_next7)} against a {_compact_tokens(weekly_limit)} weekly guardrail.",
            "Use a verifier-first prompt and shorten the next autonomous loop.",
            "warning",
        )

    month_pressure = pressure(last30_tokens, month_limit)
    if month_pressure is not None and month_pressure >= 75:
        add(
            "runway",
            "Monthly usage is pressurized",
            f"{'>999%' if month_pressure > 999 else str(month_pressure) + '%'} of 30-day token guardrail",
            f"The current 30-day window has used {_compact_tokens(last30_tokens)} against a {_compact_tokens(month_limit)} guardrail.",
            "Switch the menu-bar scope to month before starting another broad task.",
            "warning",
        )

    if not controls.get("dailyGuardrailTokens") and not controls.get("weeklyGuardrailTokens"):
        add(
            "setup",
            "Budget reminders need limits",
            "Before relying on reminders",
            "The local API has aggregate usage, but no daily or weekly token guardrail is configured.",
            "Run `tokenbar limits` to set token and cost guardrails.",
        )

    if not controls.get("activitySignalsEnabled"):
        add(
            "cadence",
            "Activity cadence is history-only",
            "When forecasts feel stale",
            "Optional activity signals are off, so reminders use strict token history only.",
            "Run `tokenbar --activity reminders` for a session-specific cadence forecast.",
        )

    if not reminders:
        add(
            "ready",
            "No urgent reminder",
            "Before the next run",
            "Token pressure is below configured thresholds in the current aggregate window.",
            "Use `tokenbar playbooks copy mission-lock` to keep the next task bounded.",
            "success",
        )

    top_reminder = reminders[0]
    budget_pressure = max(
        value
        for value in [
            daily_pressure or 0,
            weekly_pressure or 0,
            month_pressure or 0,
        ]
    )
    risk_level = "calm"
    if budget_pressure >= 100:
        risk_level = "over"
    elif budget_pressure >= 80:
        risk_level = "high"
    elif budget_pressure >= 55:
        risk_level = "watch"

    recommended_limit = "Set a daily or weekly guardrail"
    if weekly_limit:
        recommended_limit = f"Keep the next 7 days under {_compact_tokens(weekly_limit)}"
    elif daily_limit:
        recommended_limit = f"Keep today under {_compact_tokens(daily_limit)}"

    runway_brief = {
        "title": "Runway brief before the next run",
        "state": risk_level,
        "window": "next agent run",
        "trigger": top_reminder.get("trigger"),
        "reason": top_reminder.get("reason"),
        "recommendedLimit": recommended_limit,
        "reminderDraft": (
            "Start with budget, route, timebox, context cap, verifier, and stop. "
            "Ask before scheduling, publishing, spending, credentials, or cleanup."
        ),
        "setupPrompt": "Budget: Focus | Route: one bounded implementation | Timebox: one verifier | Context cap: touched files only | Stop: approval-gated external actions.",
        "commands": {
            "copyPrompt": "tokenbar playbooks copy budget-runway",
            "setLimits": "tokenbar limits",
            "reviewCost": "tokenbar cost-passport --from YYYY-MM-DD --to YYYY-MM-DD json",
            "openReminders": "tokenbar reminders json",
        },
        "approvalRequired": True,
        "delivery": "suggested-only",
        "scheduledNotifications": False,
    }

    return {
        "ok": True,
        "schema": "tokenbar.reminders.v1",
        "generatedAt": time.time(),
        "source": "local-usage-index",
        "summary": {
            "today": _compact_tokens(today_tokens),
            "last7": _compact_tokens(last7_tokens),
            "last30": _compact_tokens(last30_tokens),
            "activeDays": active_days,
            "projectedNext7": _compact_tokens(projected_next7),
        },
        "topReminder": top_reminder,
        "runwayBrief": runway_brief,
        "reminders": reminders[:8],
        "privacy": {
            **privacy_receipt(),
            "rawPromptsIncluded": False,
            "networkActions": False,
            "scheduledNotifications": False,
        },
        "disclaimer": "Suggested reminder plan only. No notifications are scheduled and no accounts or providers are changed.",
    }


def guide_payload(
    root: Path,
    stats: dict[str, Any] | None = None,
    reminders: dict[str, Any] | None = None,
    memory: dict[str, Any] | None = None,
) -> dict[str, Any]:
    stats = stats or stats_payload(root)["stats"]
    reminders = reminders or reminders_payload(root)
    memory = memory or memory_pressure_payload()
    day_tokens = stats.get("dayTokens") if isinstance(stats.get("dayTokens"), dict) else {}
    values = [_safe_number(value) for value in day_tokens.values()]
    total_tokens = _safe_number(stats.get("totalTokens"))
    active_days = _safe_number(stats.get("activeDayCount"))
    top_reminder = reminders.get("topReminder") if isinstance(reminders.get("topReminder"), dict) else {}
    memory_summary = memory.get("summary") if isinstance(memory.get("summary"), dict) else {}
    memory_pressure = str(memory_summary.get("pressure") or "unknown")

    choices: list[dict[str, Any]] = [
        {
            "key": "install",
            "label": "Install",
            "title": "Install or refresh the menu-bar cockpit.",
            "why": "Use this when the icon bar, CLI, or local API is not ready on this Mac.",
            "command": "curl -fsSL https://raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh | bash",
            "approvalRequired": False,
            "writesByDefault": False,
        },
        {
            "key": "analyze",
            "label": "Analyze",
            "title": "Refresh the local usage story.",
            "why": "Build the aggregate token, cadence, cost, and provider picture before changing settings.",
            "command": "tokenbar usage",
            "approvalRequired": False,
            "writesByDefault": False,
        },
        {
            "key": "budget",
            "label": "Budget",
            "title": "Set a runway before the next long run.",
            "why": top_reminder.get("reason") or "TokenBar can guide better once token and cost limits are explicit.",
            "command": "tokenbar reminders",
            "approvalRequired": True,
            "writesByDefault": False,
        },
        {
            "key": "playbook",
            "label": "Playbook",
            "title": "Copy a cheaper operating prompt.",
            "why": "A scoped system prompt lowers wasted output tokens and makes verification cheaper.",
            "command": "tokenbar playbooks copy budget-runway",
            "approvalRequired": False,
            "writesByDefault": False,
        },
        {
            "key": "proof",
            "label": "Proof",
            "title": "Review the launch proof packet.",
            "why": "Package safe public proof from generated aggregates before directory or launch submissions.",
            "command": "tokenbar proof-packet",
            "approvalRequired": True,
            "writesByDefault": False,
        },
    ]

    priority = "playbook"
    if top_reminder.get("kind") in {"budget", "forecast", "runway", "setup"}:
        priority = "budget"
    if memory_pressure in {"watch", "high"}:
        priority = "analyze"
    if not values or total_tokens == 0:
        priority = "install"

    question = "What should TokenBar help with before your next AI coding run?"
    if active_days >= 7:
        question = "You have enough local history. What should TokenBar optimize next?"
    if memory_pressure in {"watch", "high"}:
        question = "Your Mac has visible pressure. Which safe next step should TokenBar prepare?"

    return {
        "ok": True,
        "schema": "tokenbar.guide.v1",
        "generatedAt": time.time(),
        "source": "local-aggregate-guide",
        "question": question,
        "priority": priority,
        "choices": choices,
        "privacy": {
            **privacy_receipt(),
            "rawPromptsIncluded": False,
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "localPathsIncluded": False,
            "credentialsIncluded": False,
            "writesSettings": False,
            "providerCalls": False,
            "accountMutation": False,
            "scheduledNotifications": False,
            "externalActions": False,
        },
        "disclaimer": "Guide choices are suggested-only. TokenBar does not write settings, schedule reminders, close apps, post, upload, or contact providers from this guide.",
    }


def waste_lens_payload(
    root: Path,
    stats: dict[str, Any] | None = None,
    reminders: dict[str, Any] | None = None,
) -> dict[str, Any]:
    stats = stats or stats_payload(root)["stats"]
    reminders = reminders or reminders_payload(root)
    day_tokens = stats.get("dayTokens") if isinstance(stats.get("dayTokens"), dict) else {}
    values = [_safe_number(value) for value in day_tokens.values()]
    recent = values[-14:]
    last7 = values[-7:]
    today_tokens = values[-1] if values else 0
    last7_tokens = sum(last7)
    last30_tokens = sum(values[-30:])
    active_last7 = [value for value in last7 if value > 0]
    active_last30 = [value for value in values[-30:] if value > 0]
    average_active_day = int(sum(active_last7) / max(1, len(active_last7))) if active_last7 else 0
    peak_recent = max(recent or [0])
    burst_ratio = today_tokens / max(1, average_active_day) if average_active_day else 0
    burst_score = min(34, round(max(0, burst_ratio - 1) * 18))
    volume_score = min(34, round(last7_tokens / 1_000_000_000 * 9))
    consistency_score = 0 if len(active_last30) >= 4 else 14
    reminder_kind = str((reminders.get("topReminder") or {}).get("kind") or "")
    guardrail_score = 18 if reminder_kind in {"budget", "forecast", "runway", "setup"} else 0
    score = max(0, min(100, 18 + burst_score + volume_score + consistency_score + guardrail_score))
    label = "Clear"
    if score >= 72:
        label = "High"
    elif score >= 42:
        label = "Watch"

    drivers: list[str] = []
    if burst_score:
        drivers.append(f"Today is {_compact_tokens(today_tokens)} against a {_compact_tokens(average_active_day)} active-day baseline.")
    if volume_score:
        drivers.append(f"The last 7 days used {_compact_tokens(last7_tokens)} aggregate tokens.")
    if guardrail_score:
        drivers.append((reminders.get("topReminder") or {}).get("title") or "A local guardrail needs attention.")
    if not drivers:
        drivers.append("Aggregate usage is below the current waste lens threshold.")

    levers = [
        {
            "key": "mission-lock",
            "title": "Scope before run",
            "copy": "Start with budget, route, timebox, context cap, and stop conditions.",
            "impact": "Prevents runaway context and vague delegation.",
            "command": "tokenbar playbooks copy mission-lock",
        },
        {
            "key": "output-budget",
            "title": "Shorten output",
            "copy": "Ask for proof, blockers, and one next action before long prose.",
            "impact": "Cuts answer spillover while preserving review signal.",
            "command": "tokenbar playbooks copy output-budget",
        },
        {
            "key": "cost-passport",
            "title": "Review cost",
            "copy": "Open the cost passport before another broad autonomous loop.",
            "impact": "Turns token volume into a budget decision.",
            "command": "tokenbar cost-passport",
        },
    ]

    return {
        "ok": True,
        "schema": "tokenbar.waste_lens.v1",
        "generatedAt": time.time(),
        "source": "local-aggregate-usage-shape",
        "score": score,
        "label": label,
        "summary": {
            "today": _compact_tokens(today_tokens),
            "last7": _compact_tokens(last7_tokens),
            "last30": _compact_tokens(last30_tokens),
            "activeDays30": len(active_last30),
            "peakRecent": _compact_tokens(peak_recent),
            "basis": "Aggregate token shape only; TokenBar does not judge output quality or read raw prompts.",
        },
        "drivers": drivers[:3],
        "primaryDriver": drivers[0],
        "levers": levers,
        "privacy": {
            **privacy_receipt(),
            "rawPromptsIncluded": False,
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "localPathsIncluded": False,
            "credentialsIncluded": False,
            "providerCalls": False,
            "accountMutation": False,
            "externalActions": False,
            "qualityJudgment": False,
        },
        "disclaimer": "Waste lens is a local aggregate heuristic. It does not read prompt text, source code, transcripts, credentials, provider accounts, or output quality.",
    }


def comparison_lens_payload(root: Path, stats: dict[str, Any] | None = None) -> dict[str, Any]:
    stats = stats or stats_payload(root)["stats"]
    day_tokens = stats.get("dayTokens") if isinstance(stats.get("dayTokens"), dict) else {}
    values = [_safe_number(value) for value in day_tokens.values()]
    recent = values[-30:]
    active = [value for value in recent if value > 0]
    last7 = sum(values[-7:])
    previous7 = sum(values[-14:-7])
    last30 = sum(recent)
    active_days = len(active)
    peak = max(recent or [0])
    avg_active = int(sum(active) / max(1, len(active))) if active else 0
    quiet_days = max(0, len(recent) - active_days)
    consistency = 0
    if active:
        variance = sum(abs(value - avg_active) for value in active) / max(1, len(active))
        consistency = max(0, min(100, round(100 - (variance / max(1, avg_active)) * 45)))
    momentum = 50
    if previous7:
        momentum = max(0, min(100, round(50 + ((last7 - previous7) / max(1, previous7)) * 35)))
    elif last7:
        momentum = 68
    efficiency = max(0, min(100, 84 - round((peak / max(1, avg_active) - 1) * 18))) if avg_active else 50
    scope_discipline = max(0, min(100, 45 + active_days * 2 - min(25, quiet_days)))

    cards = [
        {
            "key": "cadence",
            "label": "Cadence",
            "value": f"{active_days}/30 active days",
            "score": consistency,
            "basis": "Compares active days and burstiness inside this local 30-day window.",
        },
        {
            "key": "momentum",
            "label": "Momentum",
            "value": f"{_compact_tokens(last7)} last 7d",
            "score": momentum,
            "basis": "Compares the latest 7 days with the previous 7 days.",
        },
        {
            "key": "cost-control",
            "label": "Cost control",
            "value": f"{_compact_tokens(avg_active)} active-day baseline",
            "score": efficiency,
            "basis": "Rewards steadier usage over one-day spikes. It does not judge output quality.",
        },
        {
            "key": "scope",
            "label": "Scope discipline",
            "value": f"{_compact_tokens(last30)} in 30d",
            "score": scope_discipline,
            "basis": "A local proxy from active days, quiet days, and aggregate token shape only.",
        },
    ]

    return {
        "ok": True,
        "schema": "tokenbar.comparison_lens.v1",
        "generatedAt": time.time(),
        "source": "local-aggregate-self-comparison",
        "headline": "Compare the work pattern, not the person.",
        "summary": {
            "cohortState": "local-only",
            "localWindows": min(4, max(1, len(recent) // 7)),
            "optInCohortSize": 0,
            "percentile": None,
            "percentileStatus": "locked until an opt-in cohort exists",
            "basis": "Self-over-time comparison from aggregate token counts only.",
        },
        "cards": cards,
        "claimPolicy": {
            "allowed": [
                "compare your own usage windows",
                "compare opt-in public proof cards",
                "rank specific metrics such as cadence, cost control, verification, and scope discipline",
            ],
            "blocked": [
                "top 1% claims without a measured opt-in cohort",
                "identity worth rankings",
                "raw transcript or source-code comparisons",
                "provider billing claims without official invoice data",
            ],
            "minimumCohortForPercentile": 10,
        },
        "proPreview": {
            "title": "Pro comparison engine",
            "description": "Team and community benchmarks unlock only after users opt in with safe proof cards.",
            "upgradeMoment": "Show the paywall when a user asks for population percentiles or team benchmarks.",
        },
        "privacy": {
            **privacy_receipt(),
            "rawPromptsIncluded": False,
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "localPathsIncluded": False,
            "credentialsIncluded": False,
            "providerCalls": False,
            "externalActions": False,
            "populationClaims": False,
        },
        "disclaimer": "Comparison Lens is local self-comparison until the user opts into public proof cards or a team cohort. It cannot claim top-percentile status from local data alone.",
    }


def playbooks_payload() -> dict[str, Any]:
    free_playbooks = [
        {
            "key": "mission-lock",
            "title": "Mission Lock",
            "category": "Launch and scope",
            "command": "tokenbar playbooks copy mission-lock",
            "copy": "Budget, route, context cap, stop condition, and verifier in the first line.",
            "wastePrevented": "Broad exploration before the finish line is clear.",
        },
        {
            "key": "budget-runway",
            "title": "Budget Runway Brief",
            "category": "Cost and budget",
            "command": "tokenbar playbooks copy budget-runway",
            "copy": "Name budget pressure, expected proof, and the pause condition before a high-token run.",
            "wastePrevented": "Letting an expensive run expand without an explicit runway decision.",
        },
        {
            "key": "cost-saver",
            "title": "Cost Saver Header",
            "category": "Cost and budget",
            "command": "tokenbar playbooks copy cost-saver",
            "copy": "Start cheap, cap context, and stop on secrets, paid services, or broad refactors.",
            "wastePrevented": "Needless context loading and oversized answers.",
        },
        {
            "key": "verifier-first",
            "title": "Verifier First",
            "category": "Verification",
            "command": "tokenbar playbooks copy verifier-first",
            "copy": "Name the proof before changing code, then run the closest check.",
            "wastePrevented": "Polishing untested behavior.",
        },
        {
            "key": "connector-truth",
            "title": "Connector Truth Table",
            "category": "Connectors",
            "command": "tokenbar playbooks copy connector-truth",
            "copy": "Separate measured, connected, demo, setup, and unsupported providers.",
            "wastePrevented": "Fake certainty from unmeasured providers.",
        },
    ]
    pro_preview = [
        {"key": "system-prompt-hardener", "title": "System Prompt Hardener", "category": "System prompt"},
        {"key": "no-submit-launch-draft", "title": "No-Submit Launch Draft", "category": "Launch"},
        {"key": "cost-passport", "title": "Cost Passport", "category": "Costs"},
        {"key": "thread-handoff", "title": "Thread Handoff", "category": "Threads"},
        {"key": "comparison-engine", "title": "Comparison Engine", "category": "Team"},
        {"key": "memory-pressure-story", "title": "Memory Pressure Story", "category": "System"},
    ]
    return {
        "ok": True,
        "schema": "tokenbar.playbooks.v1",
        "generatedAt": time.time(),
        "source": "local-playbook-catalog",
        "summary": {
            "freeCount": len(free_playbooks),
            "proPreviewCount": len(pro_preview),
            "catalogCount": 100,
            "primaryCommand": "tokenbar playbooks copy mission-lock",
            "marketplaceUrl": "https://www.tokenbar.site/playbooks",
            "catalogUrl": "https://www.tokenbar.site/prompt-playbooks.md",
            "businessState": "Freemium preview only; payment and entitlement checks are not performed by the local API.",
        },
        "tiers": [
            {
                "name": "Free",
                "description": "Starter prompts for budget, scope, verification, and connector truth.",
                "playbooks": free_playbooks,
            },
            {
                "name": "Pro",
                "description": "Premium prompts for system prompts, launch prep, cost passports, handoffs, comparisons, and memory recovery.",
                "playbooks": pro_preview,
                "requiresSubscription": True,
            },
        ],
        "connectorTargets": ["Codex", "Claude Code", "Cursor", "Antigravity", "OpenCode"],
        "links": {
            "marketplace": "https://www.tokenbar.site/playbooks",
            "catalog": "https://www.tokenbar.site/prompt-playbooks.md",
        },
        "privacy": {
            **privacy_receipt(),
            "rawPromptsIncluded": False,
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "localPathsIncluded": False,
            "credentialsIncluded": False,
            "providerCalls": False,
            "paymentActions": False,
            "entitlementMutation": False,
            "externalActions": False,
        },
        "disclaimer": "Playbooks are copy-ready prompt templates. The local API does not process payments, unlock paid content, upload private work, or contact providers.",
    }


PROVIDER_TARGETS = (
    {
        "key": "codex",
        "name": "Codex",
        "aliases": ("codex", "gpt", "openai"),
        "setupAction": "Run `tokenbar usage` or refresh the local Codex usage index.",
    },
    {
        "key": "claude-code",
        "name": "Claude Code",
        "aliases": ("claude", "sonnet", "opus"),
        "setupAction": "Connect a Claude Code export or official usage API when available.",
    },
    {
        "key": "cursor",
        "name": "Cursor",
        "aliases": ("cursor",),
        "setupAction": "Add a user-approved Cursor usage export before showing measured tokens.",
    },
    {
        "key": "antigravity",
        "name": "Antigravity",
        "aliases": ("antigravity", "anti-gravity"),
        "setupAction": "Add Antigravity as a connector once reliable local usage evidence exists.",
    },
    {
        "key": "opencode",
        "name": "OpenCode",
        "aliases": ("opencode", "open code", "open-code"),
        "setupAction": "Connect an OpenCode local usage export for open-source IDE tracking.",
    },
)


def _provider_tokens(model_tokens: dict[str, Any], aliases: tuple[str, ...]) -> int:
    total = 0
    lowered_aliases = tuple(alias.lower() for alias in aliases)
    for raw_name, raw_tokens in model_tokens.items():
        name = str(raw_name).lower()
        if any(alias in name for alias in lowered_aliases):
            total += _safe_number(raw_tokens)
    return total


def providers_payload(root: Path, stats: dict[str, Any] | None = None) -> dict[str, Any]:
    stats = stats or stats_payload(root)["stats"]
    model_tokens = stats.get("modelTokens") if isinstance(stats.get("modelTokens"), dict) else {}
    provider_totals = [
        {
            "target": target,
            "tokens": _provider_tokens(model_tokens, target["aliases"]),
        }
        for target in PROVIDER_TARGETS
    ]
    measured_total = sum(row["tokens"] for row in provider_totals)
    providers: list[dict[str, Any]] = []
    for row in provider_totals:
        target = row["target"]
        tokens = row["tokens"]
        measured = tokens > 0
        providers.append(
            {
                "key": target["key"],
                "name": target["name"],
                "status": "measured" if measured else "setup",
                "tokens": tokens,
                "tokensLabel": _compact_tokens(tokens),
                "sharePercent": round((tokens / measured_total) * 100) if measured_total and measured else 0,
                "source": "local-model-token-aggregate" if measured else "connector-not-measured",
                "proof": "usage-index modelTokens matched this provider" if measured else "No local aggregate token evidence yet",
                "evidenceNeeded": "Already measured from aggregate local modelTokens." if measured else "A user-approved local usage export or official usage API that exposes aggregate tokens.",
                "action": "Review local aggregate trend before changing budget." if measured else target["setupAction"],
                "command": "tokenbar usage" if measured else "tokenbar providers",
                "setupFlow": [
                    {
                        "label": "Detect",
                        "copy": "Read only aggregate local usage evidence.",
                        "done": measured,
                    },
                    {
                        "label": "Connect",
                        "copy": "Use a user-approved export or official API; no cookies or account scraping.",
                        "done": measured,
                    },
                    {
                        "label": "Review",
                        "copy": "Mark measured only after TokenBar can show aggregate tokens and source.",
                        "done": measured,
                    },
                ],
                "approvalRequired": not measured,
            }
        )
    measured = [provider for provider in providers if provider["status"] == "measured"]
    return {
        "ok": True,
        "schema": "tokenbar.providers.v1",
        "generatedAt": time.time(),
        "source": "local-model-token-aggregate",
        "summary": {
            "measuredCount": len(measured),
            "setupCount": len(providers) - len(measured),
            "primary": measured[0]["name"] if measured else "No measured provider yet",
            "basis": "Provider status comes only from aggregate modelTokens. No browser cookies, account pages, invoices, prompts, or provider APIs are read.",
        },
        "providers": providers,
        "privacy": {
            **privacy_receipt(),
            "rawPromptsIncluded": False,
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "localPathsIncluded": False,
            "credentialsIncluded": False,
            "providerCalls": False,
            "accountMutation": False,
            "externalActions": False,
        },
        "disclaimer": "Measured means TokenBar found local aggregate token evidence. Setup means TokenBar has not measured that provider yet.",
    }


def proof_packet_payload(root: Path) -> dict[str, Any]:
    stats = stats_payload(root)["stats"]
    reminders = reminders_payload(root)
    providers = providers_payload(root, stats=stats)
    waste_lens = waste_lens_payload(root, stats=stats, reminders=reminders)
    comparison_lens = comparison_lens_payload(root, stats=stats)
    playbooks = playbooks_payload()

    day_tokens = stats.get("dayTokens") if isinstance(stats.get("dayTokens"), dict) else {}
    values = [_safe_number(value) for value in day_tokens.values()]
    last7 = sum(values[-7:])
    last30 = sum(values[-30:])
    peak_day = max(day_tokens.items(), key=lambda item: _safe_number(item[1]), default=("", 0))
    measured_providers = [
        provider for provider in providers.get("providers", [])
        if isinstance(provider, dict) and provider.get("status") == "measured"
    ]
    top_reminder = reminders.get("topReminder") if isinstance(reminders.get("topReminder"), dict) else {}
    comparison_summary = comparison_lens.get("summary") if isinstance(comparison_lens.get("summary"), dict) else {}

    return {
        "ok": True,
        "schema": "tokenbar.launch_proof_packet.v1",
        "generatedAt": time.time(),
        "title": "TokenBar Launch Proof Packet",
        "headline": "Show the generated proof, not the private work.",
        "source": "local-aggregate-launch-proof",
        "summary": {
            "sessionCount": _safe_number(stats.get("sessionCount")),
            "activeDayCount": _safe_number(stats.get("activeDayCount")),
            "totalTokens": _safe_number(stats.get("totalTokens")),
            "last7Tokens": last7,
            "last30Tokens": last30,
            "peakDay": str(peak_day[0])[:32] if peak_day[0] else None,
            "peakDayTokens": _safe_number(peak_day[1]),
            "measuredProviderCount": len(measured_providers),
            "setupProviderCount": _safe_number((providers.get("summary") or {}).get("setupCount")),
            "topReminder": str(top_reminder.get("title") or "Open a verifier-first playbook before the next long run.")[:120],
            "wasteScore": _safe_number(waste_lens.get("score")),
            "comparisonState": str(comparison_summary.get("percentileStatus") or "locked until an opt-in cohort exists")[:80],
            "playbookCount": _safe_number((playbooks.get("summary") or {}).get("catalogCount")),
        },
        "cards": [
            {
                "key": "usage",
                "title": "Usage evidence",
                "value": _compact_tokens(stats.get("totalTokens")),
                "copy": f"{_safe_number(stats.get('sessionCount'))} sessions across {_safe_number(stats.get('activeDayCount'))} active days.",
                "command": "tokenbar usage",
            },
            {
                "key": "cost",
                "title": "Cost passport",
                "value": _compact_tokens(last30),
                "copy": "Range cost story is estimate-only until a price assumption or invoice source is reviewed.",
                "command": "tokenbar cost-passport json",
            },
            {
                "key": "waste",
                "title": "Waste lens",
                "value": str(_safe_number(waste_lens.get("score"))),
                "copy": str(waste_lens.get("primaryDriver") or "Aggregate usage shape points to the next saver playbook.")[:140],
                "command": "tokenbar waste json",
            },
            {
                "key": "comparison",
                "title": "Comparison lens",
                "value": "locked",
                "copy": "Population percentile claims stay locked until measured opt-in cohorts exist.",
                "command": "tokenbar comparison-lens json",
            },
            {
                "key": "playbooks",
                "title": "Prompt playbooks",
                "value": str(_safe_number((playbooks.get("summary") or {}).get("catalogCount"))),
                "copy": "Free starters are copy-ready; Pro templates require the account/subscription layer later.",
                "command": "tokenbar playbooks json",
            },
        ],
        "approvalGates": [
            "No Product Hunt or Macapp Supply submission from this packet.",
            "No Stripe, subscription, or entitlement changes from this packet.",
            "No account switching, provider calls, browser scraping, cleanup, posting, or uploads.",
            "Public proof requires explicit review and approval of the generated artifact.",
        ],
        "blockedFields": [
            "raw prompts",
            "transcripts",
            "source code",
            "private diffs",
            "local paths",
            "credentials",
            "provider cookies",
            "official invoice claims",
            "top-percentile claims without opt-in cohorts",
        ],
        "commands": [
            "tokenbar proof-packet json",
            "tokenbar launch-kit",
            "tokenbar runway",
            "tokenbar browser-companion",
            "tokenbar playbooks",
        ],
        "privacy": {
            **privacy_receipt(),
            "rawPromptsIncluded": False,
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "localPathsIncluded": False,
            "credentialsIncluded": False,
            "providerCalls": False,
            "paymentActions": False,
            "externalActions": False,
            "publicPosting": False,
        },
        "disclaimer": "This proof packet is safe local launch evidence. It is not a submission, billing record, provider invoice, or public ranking.",
    }


def surface_relay_payload() -> list[dict[str, str]]:
    return [
        {
            "key": "cli",
            "surface": "CLI evidence line",
            "command": "tokenbar usage",
            "tier": "Free",
            "gate": "Local read only",
            "value": "Scriptable usage, cost passport, reminders, playbooks, launch kit, and local JSON.",
        },
        {
            "key": "menu",
            "surface": "Menu-bar cockpit",
            "command": "tokenbar status",
            "tier": "Free",
            "gate": "No provider sign-in",
            "value": "Active account, measured providers, time-window tokens, budget pressure, and next suggested action.",
        },
        {
            "key": "companion",
            "surface": "Browser context rail",
            "command": "tokenbar api",
            "tier": "Free preview",
            "gate": "127.0.0.1 only",
            "value": "Budget, reminders, memory pressure, and prompt playbooks beside Codex, GitHub, Product Hunt, and provider pages.",
        },
        {
            "key": "studio",
            "surface": "Mac studio archive",
            "command": "tokenbar proof-packet",
            "tier": "Free app",
            "gate": "Review before share",
            "value": "Story, Timeline, Threads, Profile, Report, Storage, and proof packets from aggregate evidence.",
        },
        {
            "key": "pro",
            "surface": "Pro proof market",
            "command": "tokenbar playbooks",
            "tier": "Pro",
            "gate": "No auto-billing",
            "value": "Paid prompt playbooks, public proof cards, cohort comparison, and premium reports after account review.",
        },
    ]


def bundle_payload(root: Path) -> dict[str, Any]:
    identity = identity_payload(root)
    stats = stats_payload(root)["stats"]
    reminders = reminders_payload(root)
    memory = memory_pressure_payload()
    providers = providers_payload(root, stats=stats)
    waste_lens = waste_lens_payload(root, stats=stats, reminders=reminders)
    comparison_lens = comparison_lens_payload(root, stats=stats)
    playbooks = playbooks_payload()
    proof_packet = proof_packet_payload(root)
    return {
        "ok": bool(identity),
        "schema": "tokenbar.builder_bundle.v1",
        "generatedAt": time.time(),
        "identity": identity.get("identity") if identity else None,
        "stats": stats,
        "reminders": reminders,
        "memoryPressure": memory,
        "guide": guide_payload(root, stats=stats, reminders=reminders, memory=memory),
        "providers": providers,
        "wasteLens": waste_lens,
        "comparisonLens": comparison_lens,
        "playbooks": playbooks,
        "proofPacket": proof_packet,
        "surfaceRelay": surface_relay_payload(),
        "privacy": privacy_receipt(),
    }


class IdentityApiHandler(BaseHTTPRequestHandler):
    root: Path = support_dir()
    allowed_origin: str = ""
    server_version = "TokenBarIdentityAPI/0.1"

    def log_message(self, fmt: str, *args: object) -> None:
        if os.environ.get("TOKENBAR_API_QUIET") == "1":
            return
        super().log_message(fmt, *args)

    def do_OPTIONS(self) -> None:
        self._respond(204, None)

    def do_GET(self) -> None:
        path = urlparse(self.path).path.rstrip("/") or "/"
        if path in {"/", "/v1"}:
            self._respond(
                200,
                {
                    "ok": True,
                    "service": "tokenbar-safe-local-api",
                    "resources": ["/v1/identity", "/v1/stats", "/v1/reminders", "/v1/memory-pressure", "/v1/guide", "/v1/waste-lens", "/v1/comparison-lens", "/v1/playbooks", "/v1/providers", "/v1/proof-packet", "/v1/bundle", "/health"],
                    "privacy": privacy_receipt(),
                },
            )
        elif path == "/health":
            self._respond(200, {"ok": True, "service": "tokenbar-safe-local-api"})
        elif path == "/v1/identity":
            payload = identity_payload(self.root)
            self._respond(200 if payload else 404, payload or {"ok": False, "error": "no safe identity report found"})
        elif path == "/v1/stats":
            self._respond(200, stats_payload(self.root))
        elif path == "/v1/reminders":
            self._respond(200, reminders_payload(self.root))
        elif path == "/v1/memory-pressure":
            self._respond(200, memory_pressure_payload())
        elif path == "/v1/guide":
            self._respond(200, guide_payload(self.root))
        elif path == "/v1/waste-lens":
            self._respond(200, waste_lens_payload(self.root))
        elif path == "/v1/comparison-lens":
            self._respond(200, comparison_lens_payload(self.root))
        elif path == "/v1/playbooks":
            self._respond(200, playbooks_payload())
        elif path == "/v1/providers":
            self._respond(200, providers_payload(self.root))
        elif path == "/v1/proof-packet":
            self._respond(200, proof_packet_payload(self.root))
        elif path == "/v1/bundle":
            payload = bundle_payload(self.root)
            self._respond(200 if payload["ok"] else 404, payload)
        else:
            self._respond(404, {"ok": False, "error": "not found"})

    def _respond(self, status: int, body: dict[str, Any] | None) -> None:
        payload = b"" if body is None else json.dumps(body, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        if self.allowed_origin:
            self.send_header("Access-Control-Allow-Origin", self.allowed_origin)
            self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Accept, Content-Type")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        if payload:
            self.wfile.write(payload)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Expose TokenBar's safe generated identity and aggregate stats locally.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=int(os.environ.get("TOKENBAR_API_PORT", "8769")))
    parser.add_argument("--allow-remote", action="store_true", help="Allow a non-loopback bind. Use only on a trusted network.")
    parser.add_argument("--snapshot", action="store_true", help="Print the safe combined bundle and exit.")
    parser.add_argument("--output", help="Write --snapshot JSON to this file instead of stdout.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = support_dir()
    if args.snapshot:
        payload = json.dumps(bundle_payload(root), indent=2, sort_keys=True) + "\n"
        if args.output:
            target = Path(args.output).expanduser()
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(payload, encoding="utf-8")
            print(f"TokenBar safe identity bundle: {target}")
        else:
            print(payload, end="")
        return 0

    if args.host not in {"127.0.0.1", "localhost", "::1"} and not args.allow_remote:
        raise SystemExit("Refusing a remote bind. Use --allow-remote only on a trusted network.")
    IdentityApiHandler.root = root
    IdentityApiHandler.allowed_origin = os.environ.get("TOKENBAR_API_ALLOWED_ORIGIN", "").strip()
    server = ThreadingHTTPServer((args.host, args.port), IdentityApiHandler)
    print(f"TokenBar safe local API: http://{args.host}:{args.port}/v1")
    print("Resources: /v1/identity, /v1/stats, /v1/reminders, /v1/memory-pressure, /v1/guide, /v1/waste-lens, /v1/comparison-lens, /v1/playbooks, /v1/providers, /v1/proof-packet, /v1/bundle, /health")
    print("Privacy: generated identity fields + aggregate usage only; no raw logs, source code, paths, or secrets")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
