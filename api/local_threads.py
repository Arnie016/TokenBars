"""Read-only local Codex thread snapshot for the TokenBar localhost UI."""

from __future__ import annotations

import json
import os
import re
import sqlite3
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


LANE_ORDER = ("active", "attention", "paused", "recent", "done")
LOCAL_PATH_PATTERN = re.compile(r"(?:/Users|/home|/private|/var|/tmp|/Volumes)/[^\s,;)\]}]+")


def _clean(value: object, limit: int) -> str:
    return " ".join(str(value or "").split())[:limit]


def _safe_text(value: object, limit: int) -> str:
    return LOCAL_PATH_PATTERN.sub("[local path]", _clean(value, limit))


def _iso_time(value: object) -> str:
    try:
        raw = int(value or 0)
    except (TypeError, ValueError):
        return ""
    if raw <= 0:
        return ""
    seconds = raw / 1000 if raw > 10_000_000_000 else raw
    return datetime.fromtimestamp(seconds, timezone.utc).isoformat()


def _lane(goal_status: str, archived: bool, updated_ms: int, now_ms: int) -> str:
    if archived or goal_status == "complete":
        return "done"
    if goal_status == "active":
        return "active"
    if goal_status in {"blocked", "usage_limited", "budget_limited"}:
        return "attention"
    if goal_status == "paused":
        return "paused"
    if updated_ms >= now_ms - (72 * 60 * 60 * 1000):
        return "recent"
    return "paused"


def build_snapshot(limit: int = 80) -> dict:
    home = Path.home()
    state_path = Path(os.environ.get("TOKENBAR_CODEX_STATE_PATH", home / ".codex" / "state_5.sqlite")).expanduser()
    goals_path = Path(os.environ.get("TOKENBAR_CODEX_GOALS_PATH", home / ".codex" / "goals_1.sqlite")).expanduser()
    if not state_path.is_file():
        raise FileNotFoundError("Codex state database was not found. Open Codex once, then refresh this page.")

    connection = sqlite3.connect(f"file:{state_path}?mode=ro", uri=True, timeout=3)
    connection.row_factory = sqlite3.Row
    try:
        if goals_path.is_file():
            connection.execute("ATTACH DATABASE ? AS goals_db", (f"file:{goals_path}?mode=ro",))
            goal_join = "LEFT JOIN goals_db.thread_goals g ON g.thread_id = t.id"
            goal_status = "COALESCE(g.status, '')"
            goal_objective = "COALESCE(g.objective, '')"
            goal_tokens = "COALESCE(g.tokens_used, 0)"
        else:
            goal_join = ""
            goal_status = "''"
            goal_objective = "''"
            goal_tokens = "0"
        rows = connection.execute(
            f"""
            SELECT
              t.id,
              t.title,
              t.cwd,
              t.tokens_used,
              t.archived,
              MAX(COALESCE(t.recency_at_ms, 0), COALESCE(t.updated_at_ms, 0), COALESCE(t.updated_at, 0) * 1000) AS updated_ms,
              {goal_status} AS goal_status,
              {goal_objective} AS objective,
              {goal_tokens} AS goal_tokens_used
            FROM threads t
            {goal_join}
            WHERE COALESCE(t.title, '') != ''
            ORDER BY updated_ms DESC
            LIMIT ?
            """,
            (max(1, min(250, int(limit))),),
        ).fetchall()
    finally:
        connection.close()

    now_ms = int(time.time() * 1000)
    threads = []
    for row in rows:
        updated_ms = int(row["updated_ms"] or 0)
        goal_status = _clean(row["goal_status"], 32).lower()
        lane = _lane(goal_status, bool(row["archived"]), updated_ms, now_ms)
        threads.append(
            {
                "id": _clean(row["id"], 64),
                "title": _safe_text(row["title"], 110),
                "project": _clean(Path(row["cwd"] or "").name or "No project", 60),
                "tokens": int(row["tokens_used"] or 0),
                "goalTokens": int(row["goal_tokens_used"] or 0),
                "goalStatus": goal_status or "none",
                "objective": _safe_text(row["objective"], 180),
                "lane": lane,
                "updatedAt": _iso_time(updated_ms),
            }
        )

    counts = Counter(thread["lane"] for thread in threads)
    return {
        "ok": True,
        "schema": "tokenbar.local_threads.v1",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "privacy": {
            "scope": "localhost only",
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "fullPathsIncluded": False,
            "uploaded": False,
        },
        "source": {"threads": state_path.name, "goals": goals_path.name if goals_path.is_file() else "state fallback"},
        "laneOrder": list(LANE_ORDER),
        "counts": {lane: counts.get(lane, 0) for lane in LANE_ORDER},
        "threads": threads,
    }


def handler(request) -> None:
    if request.command == "OPTIONS":
        request.send_response(204)
        request.send_header("Allow", "GET, OPTIONS")
        request.end_headers()
        return
    if request.command != "GET":
        request.send_error(405, "method not allowed")
        return
    try:
        payload = build_snapshot()
        status = 200
    except (FileNotFoundError, sqlite3.Error) as error:
        payload = {"ok": False, "error": str(error), "schema": "tokenbar.local_threads.v1"}
        status = 503
    data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    request.send_response(status)
    request.send_header("Content-Type", "application/json; charset=utf-8")
    request.send_header("Cache-Control", "no-store")
    request.send_header("Content-Length", str(len(data)))
    request.end_headers()
    request.wfile.write(data)
