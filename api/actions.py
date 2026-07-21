from __future__ import annotations

import hashlib
import hmac
import html
import json
import math
import os
import re
import time
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse
import urllib.error
import urllib.request


STORE_PATH = Path(os.environ.get("TOKENBAR_ACTION_STORE_PATH", "/tmp/tokenbar-action-store.json"))
MAX_BODY_BYTES = 256_000
ACTION_NAME = "builder_identity.proof_card.v1"
ACTION_WRITE_TOKEN = (os.environ.get("TOKENBAR_ACTION_WRITE_TOKEN") or "").strip()
ACTION_OWNER_ID = (os.environ.get("TOKENBAR_ACTION_OWNER_ID") or "").strip()


def now_epoch() -> int:
    return int(time.time())


def supabase_config() -> tuple[str, str] | None:
    url = (os.environ.get("SUPABASE_URL") or "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if not url or not key:
        return None
    return url, key


def supabase_enabled() -> bool:
    return bool(supabase_config()) and (os.environ.get("TOKENBAR_ACTION_STORE") == "supabase")


def _request_owner_id(request: BaseHTTPRequestHandler) -> str | None:
    if not ACTION_WRITE_TOKEN:
        return ACTION_OWNER_ID or None
    provided = (request.headers.get("Authorization") or request.headers.get("X-TokenBar-Owner-Token") or "").strip()
    if provided.lower().startswith("bearer "):
        provided = provided[7:].strip()
    if not hmac.compare_digest(provided, ACTION_WRITE_TOKEN):
        raise RuntimeError("missing or invalid TOKENBAR_ACTION_WRITE_TOKEN")
    return ACTION_OWNER_ID or "authenticated-owner"


def supabase_request(path: str, method: str = "GET", body: dict | None = None) -> object:
    config = supabase_config()
    if not config:
        raise RuntimeError("Supabase is not configured")

    url, key = config
    headers = {
        "Authorization": f"Bearer {key}",
        "apikey": key,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }
    if method in {"POST", "PATCH"}:
        headers["Prefer"] = "resolution=merge-duplicates,return=minimal"

    request = urllib.request.Request(
        f"{url}/rest/v1/{path.lstrip('/')}",
        data=json.dumps(body).encode("utf-8") if body is not None else None,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            payload = response.read()
            if not payload:
                return None
            return json.loads(payload.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"Supabase HTTP {exc.code}: {detail}") from exc


def action_run_to_row(run: dict) -> dict:
    return {
        "run_id": run["runId"],
        "token": run["token"],
        "action": run.get("action") or ACTION_NAME,
        "status": run.get("status") or "complete",
        "owner_id": run.get("ownerId"),
        "run": run,
        "proof": run.get("proof") if isinstance(run.get("proof"), dict) else {},
        "created_at_epoch": run.get("createdAt") or now_epoch(),
    }


def read_supabase_store() -> dict:
    rows = supabase_request(
        "tokenbar_action_runs?select=run_id,token,run,proof&order=created_at_epoch.desc&limit=1000"
    )
    runs = {}
    proofs = {}
    for row in rows or []:
        if not isinstance(row, dict):
            continue
        run = row.get("run")
        proof = row.get("proof")
        run_id = str(row.get("run_id") or "")
        token = str(row.get("token") or "")
        if run_id and isinstance(run, dict):
            runs[run_id] = run
        if token and isinstance(proof, dict):
            proofs[token] = proof
    return {"runs": runs, "proofCards": proofs, "storage": "supabase-postgres"}


def read_store() -> dict:
    if supabase_enabled():
        return read_supabase_store()
    try:
        data = json.loads(STORE_PATH.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            data.setdefault("runs", {})
            data.setdefault("proofCards", {})
            data.setdefault("storage", "ephemeral-json-file")
            return data
    except Exception:
        pass
    return {"runs": {}, "proofCards": {}, "storage": "ephemeral-json-file"}


def write_store(store: dict) -> None:
    STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = STORE_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(store, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(STORE_PATH)


def save_action_run(run: dict) -> str:
    if supabase_enabled():
        supabase_request(
            "tokenbar_action_runs?on_conflict=run_id",
            method="POST",
            body=action_run_to_row(run),
        )
        return "supabase-postgres"

    store = read_store()
    store.setdefault("runs", {})[run["runId"]] = run
    store.setdefault("proofCards", {})[run["token"]] = run["proof"]
    write_store(store)
    return "ephemeral-json-file"


def storage_health() -> dict:
    config = supabase_config()
    requested = os.environ.get("TOKENBAR_ACTION_STORE") == "supabase"
    enabled = supabase_enabled()
    result = {
        "storage": "supabase-postgres" if enabled else "ephemeral-json-file",
        "durable": enabled,
        "supabaseConfigured": bool(config),
        "actionStoreRequested": requested,
        "supabaseExplicitlyEnabled": enabled,
        "actionWriteTokenConfigured": bool(ACTION_WRITE_TOKEN),
        "actionOwnerIdConfigured": bool(ACTION_OWNER_ID),
        "enableWith": "TOKENBAR_ACTION_STORE=supabase",
        "table": "tokenbar_action_runs",
        "setupSql": "docs/tokenbar_actions_supabase.sql",
        "uploadBoundary": "tokenbar.identity.v1 aggregate proof only; no raw transcripts or source code",
        "maxPayloadBytes": MAX_BODY_BYTES,
    }
    if enabled:
        try:
            supabase_request("tokenbar_action_runs?select=run_id&limit=1")
            result["reachable"] = True
            result["status"] = "durable proof-action storage ready"
        except Exception as exc:
            result["reachable"] = False
            result["status"] = "supabase enabled but table/query failed"
            result["error"] = str(exc)
    elif requested:
        result["reachable"] = True
        result["status"] = "supabase action store requested but SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing"
    else:
        result["reachable"] = True
        result["status"] = "using local ephemeral fallback"
    return result


def respond_json(handler: BaseHTTPRequestHandler, status: int, body: dict) -> None:
    payload = json.dumps(body, sort_keys=True).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type, Accept")
    handler.send_header("Cache-Control", "no-store")
    handler.send_header("Content-Length", str(len(payload)))
    handler.end_headers()
    handler.wfile.write(payload)


def respond_html(handler: BaseHTTPRequestHandler, status: int, body: str) -> None:
    payload = body.encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "text/html; charset=utf-8")
    handler.send_header("Cache-Control", "public, max-age=60")
    handler.send_header("Content-Length", str(len(payload)))
    handler.end_headers()
    handler.wfile.write(payload)


def public_base(handler: BaseHTTPRequestHandler) -> str:
    configured = os.environ.get("TOKENBAR_PUBLIC_BASE_URL")
    if configured:
        return configured.rstrip("/")
    host = handler.headers.get("host", "tokenbar-umber.vercel.app")
    proto = handler.headers.get("x-forwarded-proto")
    if not proto:
        proto = "http" if host.startswith(("127.0.0.1", "localhost")) else "https"
    return f"{proto}://{host}".rstrip("/")


def safe_number(value: object, default: float = 0) -> float:
    try:
        return float(value)
    except Exception:
        return default


def clean_public_url(value: object) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    if not text.startswith(("https://", "http://")):
        text = "https://" + text
    parsed = urlparse(text)
    if parsed.scheme not in {"https", "http"} or not parsed.netloc:
        return ""
    return text[:240]


def clean_owner_profile(value: object, fallback_name: str = "builder") -> dict:
    raw = value if isinstance(value, dict) else {}
    links_raw = raw.get("links") if isinstance(raw.get("links"), dict) else {}
    links = {}
    for key in ("github", "linkedin", "website", "x"):
        url = clean_public_url(links_raw.get(key))
        if url:
            links[key] = url
    nickname = re.sub(r"[^A-Za-z0-9_. -]", "", str(raw.get("nickname") or raw.get("handle") or fallback_name))[:64].strip()
    handle = re.sub(r"[^A-Za-z0-9_.-]", "", str(raw.get("handle") or nickname or fallback_name))[:48].strip(".-_ ")
    region = re.sub(r"[^A-Za-z0-9, ._-]", "", str(raw.get("region") or "Global"))[:80].strip() or "Global"
    bio = str(raw.get("bio") or "").replace("\x00", "").strip()[:220]
    visibility = str(raw.get("visibility") or "public").lower()
    if visibility not in {"public", "listed", "unlisted", "private"}:
        visibility = "public"
    return {
        "handle": handle or "builder",
        "nickname": nickname or handle or "builder",
        "region": region,
        "bio": bio,
        "links": links,
        "visibility": visibility,
        "ownerRedacted": bool(raw.get("ownerRedacted")),
        "rawLogsShared": False,
        "sourceCodeShared": False,
    }


def clean_submission_metadata(value: object, fallback_title: str = "") -> dict:
    raw = value if isinstance(value, dict) else {}
    privacy = raw.get("privacy") if isinstance(raw.get("privacy"), dict) else {}
    if privacy.get("rawRepoUploaded") or privacy.get("sourceCodeUploaded") or privacy.get("rawTranscriptsUploaded"):
        return {}

    def text(key: str, default: str = "", limit: int = 120) -> str:
        return str(raw.get(key) or default or "").replace("\x00", "").strip()[:limit]

    project_title = text("projectTitle", fallback_title or "Untitled project", 120) or "Untitled project"
    return {
        "schema": "tokenbar.hackathon_submission.v1",
        "event": text("event", "Independent build", 100) or "Independent build",
        "projectTitle": project_title,
        "tagline": text("tagline", "", 220),
        "track": text("track", "Builder identity", 80) or "Builder identity",
        "repoUrl": clean_public_url(raw.get("repoUrl") or raw.get("repositoryUrl")),
        "demoUrl": clean_public_url(raw.get("demoUrl") or raw.get("websiteUrl") or raw.get("productUrl")),
        "submittedAt": text("submittedAt", "", 64),
        "privacy": {
            "rawRepoUploaded": False,
            "sourceCodeUploaded": False,
            "rawTranscriptsUploaded": False,
            "publicMetadataOnly": True,
        },
    }


def redact_owner_profile(owner_profile: dict, hide_region: bool = False) -> dict:
    region = "Hidden by owner" if hide_region else str(owner_profile.get("region") or "Global")
    return {
        "handle": "anonymous-builder",
        "nickname": "Anonymous Builder",
        "region": region,
        "bio": "Owner metadata redacted by the builder.",
        "links": {},
        "visibility": str(owner_profile.get("visibility") or "public"),
        "ownerRedacted": True,
        "rawLogsShared": False,
        "sourceCodeShared": False,
    }


def parse_tokenish(value: object) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    text = str(value or "").strip().replace(",", "")
    if not text:
        return 0.0
    multiplier = 1.0
    suffix = text[-1:].lower()
    if suffix == "b":
        multiplier = 1_000_000_000.0
        text = text[:-1]
    elif suffix == "m":
        multiplier = 1_000_000.0
        text = text[:-1]
    elif suffix == "k":
        multiplier = 1_000.0
        text = text[:-1]
    return safe_number(text) * multiplier


def format_tokens(value: object) -> str:
    number = safe_number(value)
    if number >= 1_000_000_000:
        return f"{number / 1_000_000_000:.2f}B"
    if number >= 1_000_000:
        return f"{number / 1_000_000:.1f}M"
    if number >= 1_000:
        return f"{number / 1_000:.1f}K"
    return str(int(number))


def build_self_comparison(identity: dict, proof_score: float, loop_maturity: float) -> dict:
    usage = identity.get("usage") if isinstance(identity.get("usage"), dict) else {}
    session = identity.get("sessionAnalysis") if isinstance(identity.get("sessionAnalysis"), dict) else {}
    total_tokens = parse_tokenish(usage.get("totalTokens") or usage.get("last30") or 0)
    last7_tokens = parse_tokenish(usage.get("last7Tokens") or usage.get("last7") or 0)
    projected_next7 = parse_tokenish(usage.get("projectedNext7") or 0)
    active_days = int(safe_number(usage.get("activeDaysLast30")))
    sessions = int(safe_number(session.get("sessionCount") or usage.get("sessionCount") or usage.get("sessionsIndexed")))
    intensity = (last7_tokens / total_tokens * 100.0) if total_tokens > 0 else 0.0
    projection_delta = ((projected_next7 - last7_tokens) / last7_tokens * 100.0) if last7_tokens > 0 else 0.0
    direction = "accelerating" if projection_delta > 10 else "cooling" if projection_delta < -10 else "steady"
    return {
        "schema": "tokenbar.self_comparison.v1",
        "basis": "safe aggregate windows only; no raw transcripts or source code",
        "window": "current proof vs recent local usage windows",
        "current": {
            "proofScore": round(proof_score, 1),
            "loopMaturity": round(loop_maturity, 1),
            "sessionCount": sessions,
            "totalTokens": round(total_tokens),
        },
        "cards": [
            {
                "label": "Recent intensity",
                "value": f"{intensity:.0f}% of tracked tokens in the last 7 days",
                "note": f"{format_tokens(last7_tokens)} recent tokens against {format_tokens(total_tokens)} total tracked in this profile.",
            },
            {
                "label": "History depth",
                "value": f"{active_days}/30 active days",
                "note": f"{sessions} indexed sessions give this identity more context than a one-off resume snapshot.",
            },
            {
                "label": "Next 7 day pace",
                "value": f"{format_tokens(projected_next7)} projected",
                "note": f"Current forecast is {direction} relative to the last 7 day window.",
            },
            {
                "label": "Loop direction",
                "value": f"{loop_maturity:.0f}/100 loop maturity",
                "note": "Improve by proving one finished artifact, then writing the uncertainty and next bottleneck.",
            },
        ],
        "uncertainty": "A richer trend needs multiple dated identity claims; this view uses the current claim's safe aggregate windows.",
    }


def dimension_map(identity: dict) -> dict[str, float]:
    dimensions = identity.get("dimensions") if isinstance(identity.get("dimensions"), list) else []
    result: dict[str, float] = {}
    for item in dimensions:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip().lower()
        if not name:
            continue
        result[name] = safe_number(item.get("score"))
    return result


def pick_score(scores: dict[str, float], names: list[str], fallback: float = 0) -> float:
    values = [scores[name] for name in names if name in scores]
    if values:
        return sum(values) / len(values)
    return fallback


def confidence_from(evidence_count: int, score: float) -> str:
    if evidence_count >= 4 and score > 0:
        return "high"
    if evidence_count >= 2 and score > 0:
        return "medium"
    return "low"


def safe_basename(value: object) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    return Path(text.rstrip("/")).name or text


def build_shipped_work(identity: dict, total_tokens: float, session_count: int, redactions: dict) -> list[dict]:
    usage = identity.get("usage") if isinstance(identity.get("usage"), dict) else {}
    session = identity.get("sessionAnalysis") if isinstance(identity.get("sessionAnalysis"), dict) else {}
    shipping = identity.get("shippingAnalysis") if isinstance(identity.get("shippingAnalysis"), dict) else {}
    top_workspaces = session.get("topWorkspaces") if isinstance(session.get("topWorkspaces"), list) else []
    operating_mode = str(session.get("operatingMode") or "local agent workflow").strip()
    items: list[dict] = []

    if redactions.get("sessions"):
        session_value = "Hidden by owner"
        session_note = "The builder shared the identity pattern while redacting session volume."
    else:
        session_value = f"{int(safe_number(session_count))} sessions"
        session_note = f"Local session metadata shows a {operating_mode} pattern."
    items.append(
        {
            "label": "Agent-session surface",
            "value": session_value,
            "note": session_note,
            "provenance": "sessionAnalysis aggregate; no raw transcripts",
        }
    )

    if redactions.get("tokens"):
        token_value = "Hidden by owner"
        token_note = "Token volume was intentionally removed from this share view."
    else:
        token_value = f"{format_tokens(total_tokens)} tokens"
        token_note = f"Recent 7-day pace: {usage.get('last7') or format_tokens(usage.get('last7Tokens') or 0)}; next 7-day forecast: {usage.get('projectedNext7') or 'not available'}."
    items.append(
        {
            "label": "Workload scale",
            "value": token_value,
            "note": token_note,
            "provenance": "safe usage index aggregate",
        }
    )

    if shipping.get("available"):
        repo = safe_basename(shipping.get("repo") or shipping.get("repoRoot") or shipping.get("source")) or "local repo"
        commits = int(safe_number(shipping.get("commitCount")))
        net_loc = int(safe_number(shipping.get("netLoc")))
        if commits > 0:
            shipping_note = f"Git metadata shows {commits} commits and {net_loc:+} net LOC in the last {shipping.get('windowDays') or '?'} days."
        else:
            shipping_note = "No commits were captured in this window; treat this as workflow proof, not shipped-code proof."
        items.append(
            {
                "label": "Repo evidence",
                "value": repo,
                "note": shipping_note,
                "provenance": "git shortstat metadata only; no diffs or source code",
            }
        )

    workspace_names = []
    for item in top_workspaces[:4]:
        if not isinstance(item, dict):
            continue
        name = safe_basename(item.get("name"))
        if name:
            workspace_names.append(name)
    if workspace_names:
        items.append(
            {
                "label": "Project range",
                "value": f"{len(workspace_names)} active surfaces",
                "note": ", ".join(workspace_names),
                "provenance": "workspace names only; no file contents",
            }
        )

    return items[:4]


def validate_identity(raw: dict) -> dict:
    if raw.get("schema") != "tokenbar.identity.v1":
        raise ValueError("expected tokenbar.identity.v1")
    token = str(raw.get("token") or "").strip()
    if not token.startswith("TBAR-") or len(token) < 10:
        raise ValueError("missing TokenBar identity token")

    privacy = raw.get("privacy") if isinstance(raw.get("privacy"), dict) else {}
    if privacy.get("rawTranscriptsIncluded") is not False:
        raise ValueError("identity must declare rawTranscriptsIncluded=false")
    if privacy.get("sourceCodeIncluded") not in (False, None):
        raise ValueError("identity must not include source code")

    session = raw.get("sessionAnalysis")
    if isinstance(session, dict) and session.get("rawTranscriptsIncluded") is not False:
        raise ValueError("session analysis must not include raw transcripts")

    shipping = raw.get("shippingAnalysis")
    if isinstance(shipping, dict):
        if shipping.get("sourceCodeIncluded") is not False:
            raise ValueError("shipping analysis must not include source code")
        if shipping.get("rawDiffsIncluded") is not False:
            raise ValueError("shipping analysis must not include raw diffs")

    serialized = json.dumps(raw, sort_keys=True)
    if re.search(r"(?<![A-Za-z0-9])(sk|whsec|rk|pk)_[A-Za-z0-9_\-=]{12,}", serialized):
        raise ValueError("identity payload appears to contain a secret")
    return raw


def build_builder_story(
    identity: dict,
    title: str,
    archetype: str,
    npc_class: str,
    proof_score: float,
    loop_maturity: float,
    total_tokens: float,
    session_count: int,
    redactions: dict | None = None,
) -> dict:
    redactions = redactions if isinstance(redactions, dict) else {}
    scores = dimension_map(identity)
    usage = identity.get("usage") if isinstance(identity.get("usage"), dict) else {}
    label = identity.get("identityLabel") if isinstance(identity.get("identityLabel"), dict) else {}
    shipping = identity.get("shippingAnalysis") if isinstance(identity.get("shippingAnalysis"), dict) else {}

    dimension_count = len(scores)
    provenance_base = [
        "tokenbar.identity.v1 schema",
        "safe aggregate usage index",
        "server action stages",
    ]
    if dimension_count:
        provenance_base.append(f"{dimension_count} local identity dimensions")
    if shipping.get("available"):
        provenance_base.append("safe shipping summary")

    axes = [
        {
            "key": "craftTaste",
            "label": "Craft and taste",
            "score": round(pick_score(scores, ["product instinct", "engineering", "quality"], proof_score), 1),
            "confidence": confidence_from(len(provenance_base), proof_score),
            "claim": "Turns rough product intent into a shaped artifact with a clear buyer/user promise.",
            "provenance": provenance_base[:3],
        },
        {
            "key": "systemsThinking",
            "label": "Systems thinking",
            "score": round(pick_score(scores, ["planning", "engineering", "depth"], loop_maturity), 1),
            "confidence": confidence_from(len(provenance_base), loop_maturity),
            "claim": "Frames work as constraints, contracts, checkpoints, and repeatable surfaces.",
            "provenance": ["local identity dimensions", "loop maturity proxy", "action-stage evidence"],
        },
        {
            "key": "completion",
            "label": "Completion",
            "score": round((pick_score(scores, ["execution", "delivery"], proof_score) + proof_score) / 2, 1),
            "confidence": confidence_from(len(provenance_base), proof_score),
            "claim": "Can push an idea to a shareable proof surface, but the proof score still decides how loudly it should be shown.",
            "provenance": ["proof score", "server proof card", "reloadable action run"],
        },
        {
            "key": "ambition",
            "label": "Ambition",
            "score": round(min(100, 35 + (total_tokens / 1_000_000_000) * 1.1 + min(session_count, 300) * 0.08), 1),
            "confidence": confidence_from(3 if total_tokens else 1, total_tokens),
            "claim": "Works at unusual scale; the signal is volume plus repeated attempts, not token spend alone.",
            "provenance": ["aggregate token count", "indexed session count", "local usage index"],
        },
        {
            "key": "learningVelocity",
            "label": "Learning velocity",
            "score": round(min(100, pick_score(scores, ["iteration", "velocity", "steering"], 45) + min(session_count, 250) * 0.08), 1),
            "confidence": confidence_from(3 if session_count else 1, session_count),
            "claim": "Learns through fast steering loops and repeated agent feedback, not static repo snapshots.",
            "provenance": ["indexed session count", "steering dimension", "safe aggregate metadata"],
        },
        {
            "key": "discernment",
            "label": "Discernment",
            "score": round((pick_score(scores, ["steering", "control", "verification"], loop_maturity) + loop_maturity) / 2, 1),
            "confidence": confidence_from(len(provenance_base), loop_maturity),
            "claim": "The next leap is better evidence selection: fewer claims, stronger verification, clearer uncertainty.",
            "provenance": ["loop maturity proxy", "privacy boundary", "proof score"],
        },
    ]

    strongest = max(axes, key=lambda item: item["score"])
    weakest = min(axes, key=lambda item: item["score"])
    summary = str(label.get("summary") or identity.get("subtitle") or "").strip()
    if not summary:
        summary = f"{title} reads as {archetype} / {npc_class}: high agency with proof still gated by evidence quality."
    shipped_work = build_shipped_work(identity, total_tokens, session_count, redactions)
    session_claim = (
        "Session volume was hidden by the owner for this share view."
        if redactions.get("sessions")
        else f"Generated a reloadable proof card from {session_count} indexed local sessions."
    )
    token_claim = (
        "Token volume was hidden by the owner while preserving the privacy and provenance receipt."
        if redactions.get("tokens")
        else f"Carried {format_tokens(total_tokens)} aggregate local token activity into a safe public artifact."
    )

    return {
        "schema": "tokenbar.builder_story.v1",
        "headline": f"{title} is becoming a {archetype}.",
        "summary": summary,
        "axes": axes,
        "whatProved": [
            session_claim,
            token_claim,
            "Completed a server-side action loop with request, validation, proof build, persistence, and reload.",
        ],
        "shippedWork": shipped_work,
        "tradeoffs": [
            "Public claims are intentionally conservative until shipping evidence is richer.",
            "Identity is based on aggregate session telemetry and generated labels, not private raw transcripts.",
        ],
        "recovery": "If a claim feels wrong, rerun locally, inspect the action stages, and publish only the corrected identity artifact.",
        "nextFrontier": f"Raise {weakest['label'].lower()} with one tighter loop: define the contract, ship proof, verify it, then write the uncertainty down.",
        "strongestSignal": strongest["label"],
        "weakestSignal": weakest["label"],
        "uncertainties": [
            "No raw transcript review is exposed in this public proof.",
            "Self-over-time comparison needs multiple dated identity actions.",
            "Shipping quality is safer to claim after commit/deploy evidence is attached.",
        ],
        "shareViews": {
            "private": ["all axes", "uncertainties", "next frontier", "safe provenance"],
            "public": ["headline", "summary", "top facts", "privacy boundary"],
            "selective": ["chosen axes", "share copy", "redacted proof card"],
        },
        "provenance": provenance_base,
    }


def identity_digest(identity: dict) -> str:
    payload = json.dumps(identity, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def stage(name: str, note: str, status: str = "complete") -> dict:
    return {"name": name, "status": status, "note": note, "at": now_epoch()}


def normalize_share_controls(value: object) -> dict:
    controls = value if isinstance(value, dict) else {}
    visibility = str(controls.get("visibility") or "public").strip().lower()
    if visibility in {"listed"}:
        visibility = "public"
    if visibility not in {"public", "unlisted", "private"}:
        visibility = "public"
    raw_redactions = controls.get("redactions") if isinstance(controls.get("redactions"), dict) else {}
    redactions = {
        "owner": bool(raw_redactions.get("owner")),
        "tokens": bool(raw_redactions.get("tokens")),
        "sessions": bool(raw_redactions.get("sessions")),
        "region": bool(raw_redactions.get("region")),
    }
    return {"visibility": visibility, "redactions": redactions}


def proof_token_for_share(identity_token: str, share_controls: dict) -> str:
    """Derive a stable public proof token without reusing the private identity token.

    One local identity can produce multiple share variants. The token must include
    share controls so an unlisted/redacted proof cannot overwrite a public proof.
    """
    payload = json.dumps(
        {
            "identityToken": identity_token,
            "shareControls": share_controls,
            "action": ACTION_NAME,
        },
        sort_keys=True,
        separators=(",", ":"),
    )
    return "TBAR-" + hashlib.sha256(payload.encode("utf-8")).hexdigest()[:12].upper()


def proof_share_mode(proof: dict) -> str:
    privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
    share_controls = proof.get("shareControls") if isinstance(proof.get("shareControls"), dict) else {}
    visibility = str(
        proof.get("publicVisibility")
        or privacy.get("shareMode")
        or share_controls.get("visibility")
        or "public"
    ).strip().lower()
    return "public" if visibility == "listed" else visibility


def proof_is_private(proof: dict) -> bool:
    return proof_share_mode(proof) == "private"


def proof_is_publicly_listed(proof: dict) -> bool:
    return proof_share_mode(proof) in {"public", "listed"}


def build_surface_bundle(
    token: str,
    proof_url: str = "",
    profile_url: str = "",
    social_url: str = "",
    rankings_url: str = "",
    loop_rankings_url: str = "",
    trailer_url: str = "",
    visibility: str = "public",
    share_copy: str = "",
) -> dict:
    surfaces = [
        {
            "key": "proofCard",
            "label": "Proof card",
            "description": "60-second evidence surface",
            "url": proof_url,
        },
        {
            "key": "publicProfile",
            "label": "Public profile",
            "description": "identity narrative and verification receipt",
            "url": profile_url,
        },
        {
            "key": "socialFeed",
            "label": "For You feed",
            "description": "shipped-work story card",
            "url": social_url,
        },
        {
            "key": "rankings",
            "label": "Rankings",
            "description": "proof, craft, completion, ambition, and discernment boards",
            "url": rankings_url,
        },
        {
            "key": "loopRankings",
            "label": "Loop rankings",
            "description": "repeatable agent-loop maturity board",
            "url": loop_rankings_url,
        },
        {
            "key": "identityTrailer",
            "label": "Identity trailer",
            "description": "30-second storyboard from safe proof anchors",
            "url": trailer_url,
        },
    ]
    return {
        "schema": "tokenbar.surface_bundle.v1",
        "token": token,
        "visibility": visibility,
        "shareCopy": share_copy,
        "surfaces": [surface for surface in surfaces if str(surface.get("url") or "").strip()],
        "privacyBoundary": {
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "neverPublic": ["rawTranscripts", "sourceCode", "privateDiffs", "credentials", "envFiles"],
        },
    }


def clean_builder_signal_summary(value: object) -> dict:
    raw = value if isinstance(value, dict) else {}
    privacy = raw.get("privacy") if isinstance(raw.get("privacy"), dict) else {}
    if raw.get("schema") != "tokenbar.builder_signal_summary.v1":
        return {}
    if privacy.get("rawTranscriptsIncluded") is not False or privacy.get("sourceCodeIncluded") is not False:
        return {}
    if privacy.get("urlsIncluded") is not False or privacy.get("titlesIncluded") is not False or privacy.get("notesIncluded") is not False:
        return {}

    def ranked(items: object) -> list[dict]:
        rows: list[dict] = []
        if not isinstance(items, list):
            return rows
        for item in items[:8]:
            if not isinstance(item, dict):
                continue
            name = str(item.get("name") or "").strip()
            if not name:
                continue
            name = name.replace("https://", "").replace("http://", "")[:80]
            rows.append({"name": name, "count": int(safe_number(item.get("count")))})
        return rows

    signal_count = int(safe_number(raw.get("signalCount")))
    return {
        "schema": "tokenbar.builder_signal_summary.v1",
        "available": bool(raw.get("available")) and signal_count > 0,
        "signalCount": signal_count,
        "topHosts": ranked(raw.get("topHosts")),
        "topTags": ranked(raw.get("topTags")),
        "story": str(raw.get("story") or "Local saved links are summarized as aggregate builder taste signals.").strip()[:280],
        "privacy": {
            "networkUploaded": False,
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "urlsIncluded": False,
            "titlesIncluded": False,
            "notesIncluded": False,
        },
    }


def clean_spotlight_sources(value: object) -> dict:
    raw = value if isinstance(value, dict) else {}
    privacy = raw.get("privacy") if isinstance(raw.get("privacy"), dict) else {}
    if privacy.get("rawTranscriptsIncluded") or privacy.get("sourceCodeIncluded"):
        return {}

    def clean_items(items: object, limit: int, item_limit: int) -> list[str]:
        rows: list[str] = []
        if not isinstance(items, list):
            return rows
        for item in items:
            text = str(item or "").replace("\x00", "").strip()
            if not text:
                continue
            text = re.sub(r"[\r\n\t]+", " ", text)
            rows.append(text[:item_limit])
            if len(rows) >= limit:
                break
        return rows

    sessions = clean_items(raw.get("sessions"), 8, 96)
    projects = clean_items(raw.get("projects"), 8, 120)
    notes = clean_items(raw.get("notes"), 8, 240)
    raw_story = raw.get("story") if isinstance(raw.get("story"), dict) else {}
    raw_beats = raw.get("storyBeats") if isinstance(raw.get("storyBeats"), list) else []

    def clean_story_field(key: str, fallback: str) -> str:
        text = str(raw_story.get(key) or "").replace("\x00", "").strip()
        text = re.sub(r"[\r\n\t]+", " ", text)
        return (text[:280] if text else fallback)

    project_text = ", ".join(projects[:2]) if projects else "the selected work"
    session_text = ", ".join(sessions[:2]) if sessions else "the selected session trail"
    note_text = notes[0] if notes else ""
    story = {
        "insight": clean_story_field("insight", f"{project_text} is tied to a visible proof trail instead of an unstructured chat history."),
        "struggle": clean_story_field("struggle", "The hard part was compressing scattered agent work into public evidence without exposing private context."),
        "features": clean_story_field("features", note_text or f"{session_text} became a public-safe anchor for the builder profile."),
        "progress": clean_story_field("progress", f"TokenBar can turn {project_text} into a proof card, profile surface, social feed item, and trailer storyboard."),
    }
    if not (sessions or projects or notes or any(story.values())):
        return {}
    story_beats: list[dict] = []
    for beat in raw_beats[:6]:
        if not isinstance(beat, dict):
            continue
        label = re.sub(r"[\r\n\t]+", " ", str(beat.get("label") or "").replace("\x00", "").strip())[:80]
        text = re.sub(r"[\r\n\t]+", " ", str(beat.get("text") or "").replace("\x00", "").strip())[:240]
        if label and text:
            story_beats.append({"label": label, "text": text})
    if not story_beats:
        story_beats = [
            {
                "label": "Key insight",
                "text": story["insight"],
            },
            {
                "label": "Struggle",
                "text": story["struggle"],
            },
            {
                "label": "Feature shipped",
                "text": story["features"],
            },
            {
                "label": "Progress",
                "text": story["progress"],
            },
        ]
    def safe_int(value: object) -> int:
        try:
            return int(value or 0)
        except Exception:
            return 0

    return {
        "schema": "tokenbar.spotlight_sources.v1",
        "sessions": sessions,
        "projects": projects,
        "notes": notes,
        "story": story,
        "storyBeats": story_beats,
        "privacy": {
            "userProvidedOnly": privacy.get("userProvidedOnly", True) is True,
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "sessionFilesRead": privacy.get("sessionFilesRead") is True,
            "localInference": privacy.get("localInference") is True,
            "storedRawExcerpts": False,
            "maxSessionBytesRead": safe_int(privacy.get("maxSessionBytesRead")),
            "matchedSessionFiles": safe_int(privacy.get("matchedSessionFiles")),
        },
    }


def build_proof_card(identity: dict, base_url: str, share_controls: object = None) -> dict:
    share_controls = normalize_share_controls(share_controls)
    visibility = share_controls["visibility"]
    redactions = share_controls["redactions"]
    identity_token = str(identity["token"])
    token = proof_token_for_share(identity_token, share_controls)
    label = identity.get("identityLabel") if isinstance(identity.get("identityLabel"), dict) else {}
    public_profile = identity.get("publicProfile") if isinstance(identity.get("publicProfile"), dict) else {}
    usage = identity.get("usage") if isinstance(identity.get("usage"), dict) else {}
    session = identity.get("sessionAnalysis") if isinstance(identity.get("sessionAnalysis"), dict) else {}
    shipping = identity.get("shippingAnalysis") if isinstance(identity.get("shippingAnalysis"), dict) else {}
    leaderboard = identity.get("leaderboard") if isinstance(identity.get("leaderboard"), dict) else {}
    builder_signals = clean_builder_signal_summary(identity.get("builderSignalInbox") or identity.get("socialLearningSignals"))
    spotlight = clean_spotlight_sources(identity.get("spotlightSources"))

    title = (
        str(identity.get("title") or "").strip()
        or str(label.get("title") or "").strip()
        or str(identity.get("primaryArchetype") or "Builder Identity").strip()
    )
    submission = clean_submission_metadata(
        identity.get("hackathonSubmission") or identity.get("submittedProject"),
        fallback_title=title,
    )
    owner_profile = clean_owner_profile(public_profile, fallback_name=title)
    if redactions["region"]:
        owner_profile["region"] = "Hidden by owner"
    if redactions["owner"]:
        owner_profile = redact_owner_profile(owner_profile, hide_region=redactions["region"])
    archetype = str(identity.get("primaryArchetype") or label.get("archetype") or title)
    npc_class = str(identity.get("npcClass") or label.get("npcClass") or "builder")
    dimensions = identity.get("dimensions") if isinstance(identity.get("dimensions"), list) else []
    dimension_scores = [
        safe_number(item.get("score"))
        for item in dimensions
        if isinstance(item, dict) and item.get("score") is not None
    ]
    dimension_average = sum(dimension_scores) / len(dimension_scores) if dimension_scores else 0
    loop_maturity = safe_number(identity.get("loopMaturity") or identity.get("loopScore") or dimension_average)
    specificity = safe_number(identity.get("specificityScore"))
    proof_score = safe_number(identity.get("proofScore") or specificity)
    private_total_tokens = usage.get("totalTokens") or leaderboard.get("tokenCount") or usage.get("last30") or 0
    private_session_count = session.get("sessionCount") or usage.get("sessionCount") or usage.get("sessionsIndexed") or 0
    total_tokens = 0 if redactions["tokens"] else private_total_tokens
    session_count = 0 if redactions["sessions"] else private_session_count

    if proof_score >= 85:
        verdict = "Portfolio-grade proof card ready."
    elif proof_score >= 65:
        verdict = "Strong public proof, with a few closure gaps still visible."
    else:
        verdict = "Useful private reflection; improve verification before making it loud."

    usage_value = "Hidden by owner" if redactions["tokens"] else f"{format_tokens(total_tokens)} tokens"
    usage_note = (
        "Session count hidden by owner."
        if redactions["sessions"]
        else f"{int(safe_number(session_count))} sessions shaped this proof card."
    )
    facts = [
        {
            "label": "Local boundary",
            "value": "Raw sessions stayed on device",
            "note": "Only the generated tokenbar.identity.v1 artifact powered this action.",
        },
        {
            "label": "Builder read",
            "value": f"{archetype} / {npc_class}",
            "note": str(label.get("summary") or identity.get("subtitle") or "A safe public identity label was generated locally."),
        },
        {
            "label": "Usage signal",
            "value": usage_value,
            "note": usage_note,
        },
        {
            "label": "Loop maturity",
            "value": f"{loop_maturity:.0f}/100",
            "note": "Measures planning, contracts, verification, traces, and restart discipline.",
        },
        {
            "label": "Public score",
            "value": f"{proof_score:.0f}/100",
            "note": verdict,
        },
    ]
    if redactions["owner"]:
        facts.insert(
            3,
            {
                "label": "Owner metadata",
                "value": "Hidden by owner",
                "note": "Handle, nickname, bio, and links were removed from this share variant.",
            },
        )
    if spotlight:
        facts.append(
            {
                "label": "Spotlight anchors",
                "value": f"{len(spotlight.get('sessions') or [])} sessions / {len(spotlight.get('projects') or [])} projects",
                "note": "Builder-selected public anchors only; no raw transcripts, source files, or private diffs were read.",
            }
        )

    story = build_builder_story(
        identity,
        title,
        archetype,
        npc_class,
        proof_score,
        loop_maturity,
        safe_number(total_tokens),
        int(safe_number(session_count)),
        redactions,
    )
    self_comparison = build_self_comparison(identity, proof_score, loop_maturity)
    proof_url = f"{base_url}/api/actions?token={quote(token)}"
    profile_url = f"{base_url}/api/profiles?token={quote(token)}"
    social_url = f"{base_url}/social?token={quote(token)}"
    rankings_url = f"{base_url}/rankings?token={quote(token)}"
    loop_rankings_url = f"{base_url}/rankings?token={quote(token)}#loop"
    trailer_url = f"{proof_url}&view=trailer"
    share_copy = (
        f"My {'unlisted ' if visibility == 'unlisted' else 'private ' if visibility == 'private' else ''}TokenBar builder identity is {title}: {archetype} / {npc_class}. "
        f"Proof {proof_score:.0f}/100, loop maturity {loop_maturity:.0f}/100. "
        f"Built from safe aggregate TokenBar evidence only; no raw transcripts or source code uploaded"
        f"{'; selected fields redacted' if any(redactions.values()) else ''}. "
        f"{profile_url}"
    )
    surface_bundle = build_surface_bundle(
        token=token,
        proof_url=proof_url,
        profile_url=profile_url,
        social_url=social_url,
        rankings_url=rankings_url,
        loop_rankings_url=loop_rankings_url,
        trailer_url=trailer_url,
        visibility=visibility,
        share_copy=share_copy,
    )
    return {
        "schema": "tokenbar.proof_card.v1",
        "token": token,
        "identityToken": identity_token,
        "title": title,
        "primaryArchetype": archetype,
        "npcClass": npc_class,
        "specificityScore": round(specificity, 1),
        "proofScore": round(proof_score, 1),
        "loopMaturity": round(loop_maturity, 1),
        "ownerProfile": owner_profile,
        "hackathonSubmission": submission,
        "submittedProject": submission,
        "publicVisibility": visibility,
        "shareControls": share_controls,
        "totalTokens": safe_number(total_tokens),
        "tokenCountHidden": bool(redactions["tokens"]),
        "sessionCount": int(safe_number(session_count)),
        "sessionCountHidden": bool(redactions["sessions"]),
        "verdict": verdict,
        "facts": facts,
        "builderStory": story,
        "builderSignalInbox": builder_signals,
        "socialLearningSignals": builder_signals,
        "spotlightSources": spotlight,
        "selfComparison": self_comparison,
        "proofCardUrl": proof_url,
        "profileUrl": profile_url,
        "socialUrl": social_url,
        "rankingsUrl": rankings_url,
        "loopRankingsUrl": loop_rankings_url,
        "trailerUrl": trailer_url,
        "shareCopy": share_copy,
        "surfaceBundle": surface_bundle,
        "createdAt": now_epoch(),
        "privacy": {
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "uploadedArtifact": "generated identity JSON only; selected fields redacted" if any(redactions.values()) else "generated identity JSON only",
            "shareMode": visibility,
            "redactions": redactions,
        },
    }


def build_verification_receipt(proof: dict, run_id: str, stages: list[dict]) -> dict:
    privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
    share_controls = proof.get("shareControls") if isinstance(proof.get("shareControls"), dict) else normalize_share_controls({})
    redactions = privacy.get("redactions") if isinstance(privacy.get("redactions"), dict) else share_controls.get("redactions") if isinstance(share_controls.get("redactions"), dict) else {}
    completed_stages = [
        str(item.get("name") or "")
        for item in stages
        if isinstance(item, dict) and str(item.get("status") or "") == "complete"
    ]
    share_mode = proof_share_mode(proof)
    if share_mode == "private":
        public_material = "private run receipt only; token, profile, feed, and ranking lookups are disabled"
    elif share_mode == "unlisted":
        public_material = "direct-link proof card and profile only; excluded from public feed and rankings"
    else:
        public_material = "generated proof card, profile summary, feed row, and ranking row"
    return {
        "schema": "tokenbar.verification_receipt.v1",
        "runId": run_id,
        "token": proof.get("token"),
        "action": ACTION_NAME,
        "shareMode": share_mode,
        "redactions": redactions,
        "uploadedArtifact": privacy.get("uploadedArtifact") or "generated identity JSON only",
        "publicMaterial": public_material,
        "notIncluded": ["raw transcripts", "source code", "raw diffs", ".env files", "credentials"],
        "privacyBoundary": {
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
        },
        "rankingPolicy": {
            "tokensWeight": 0.06,
            "outcomesWeight": 0.14,
            "tokenVolumeCapped": True,
            "basis": "proof score, loop maturity, specificity, verified outcomes, range, and a capped token safety signal",
            "antiPayToWin": "Token volume is capped at 6% and treated as a safety signal; verified outcomes and execution quality rank first.",
        },
        "stageCount": len(completed_stages),
        "completedStages": completed_stages,
        "reproduceWith": ["tokenbar claim", "tokenbar publish-proof", "paste the returned TBAR token"],
        "createdAt": now_epoch(),
    }


def build_next_action_plan(proof: dict) -> dict:
    story = proof.get("builderStory") if isinstance(proof.get("builderStory"), dict) else {}
    self_comparison = proof.get("selfComparison") if isinstance(proof.get("selfComparison"), dict) else {}
    receipt = proof.get("verificationReceipt") if isinstance(proof.get("verificationReceipt"), dict) else {}
    weakest = str(story.get("weakestSignal") or "verification").strip()
    strongest = str(story.get("strongestSignal") or "proof").strip()
    frontier = str(story.get("nextFrontier") or "").strip()
    proof_score = safe_number(proof.get("proofScore"))
    loop_maturity = safe_number(proof.get("loopMaturity"))
    share_mode = proof_share_mode(proof)
    stage_count = safe_number(receipt.get("stageCount"))
    if not frontier:
        frontier = f"Raise {weakest.lower()} with one bounded build loop and a visible proof artifact."
    if proof_score >= 75 and loop_maturity >= 70:
        focus = "turn the strongest proof into a public case study"
    elif loop_maturity < proof_score:
        focus = "make the next loop more repeatable before adding more surface area"
    else:
        focus = "attach sharper execution evidence to the existing identity story"
    actions = [
        {
            "key": "act",
            "label": "Run one bounded builder loop",
            "command": "tokenbar claim",
            "why": frontier,
            "evidenceNeeded": f"One completed artifact that exercises {weakest.lower()} without exposing raw logs.",
        },
        {
            "key": "verify",
            "label": "Attach a visible receipt",
            "command": "tokenbar publish-proof --unlisted",
            "why": f"Keep {strongest.lower()} visible while testing whether the next claim is defensible.",
            "evidenceNeeded": "Reloadable run id, proof card, safe-evidence receipt, and uncertainty note.",
        },
        {
            "key": "share",
            "label": "Promote only the safe proof",
            "command": "tokenbar social",
            "why": "Share the public profile or direct token only after the receipt proves what was used and what was excluded.",
            "evidenceNeeded": "Public or unlisted TBAR token with raw transcripts/source code excluded.",
        },
    ]
    return {
        "schema": "tokenbar.next_action_plan.v1",
        "focus": focus,
        "weakestSignal": weakest,
        "strongestSignal": strongest,
        "shareMode": share_mode,
        "confidence": "high" if stage_count >= 6 and proof_score >= 60 else "medium" if stage_count >= 6 else "low",
        "basis": [
            "builderStory.nextFrontier",
            "proofScore",
            "loopMaturity",
            "verificationReceipt.stageCount",
            "selfComparison" if self_comparison.get("cards") else "single-snapshot comparison",
        ],
        "actions": actions,
        "privacyBoundary": {
            "rawTranscriptsRequired": False,
            "sourceCodeRequired": False,
            "publicSharingOptional": True,
        },
    }


def build_safe_evidence_receipt(proof: dict, run_id: str = "", stages: list[dict] | None = None) -> dict:
    privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
    share_controls = proof.get("shareControls") if isinstance(proof.get("shareControls"), dict) else {}
    redactions = privacy.get("redactions") if isinstance(privacy.get("redactions"), dict) else share_controls.get("redactions") if isinstance(share_controls.get("redactions"), dict) else {}
    surface_bundle = proof.get("surfaceBundle") if isinstance(proof.get("surfaceBundle"), dict) else {}
    builder_signals = clean_builder_signal_summary(proof.get("builderSignalInbox") or proof.get("socialLearningSignals"))
    surfaces = [
        {
            "key": str(surface.get("key") or ""),
            "label": str(surface.get("label") or surface.get("key") or ""),
            "url": str(surface.get("url") or ""),
        }
        for surface in (surface_bundle.get("surfaces") if isinstance(surface_bundle.get("surfaces"), list) else [])
        if isinstance(surface, dict) and surface.get("url")
    ]
    completed_stages = [
        str(item.get("name") or "")
        for item in (stages or [])
        if isinstance(item, dict) and str(item.get("status") or "") == "complete"
    ]
    share_mode = proof_share_mode(proof)
    if share_mode == "private":
        public_material = "owner-only audit receipt; public token/profile/feed/ranking lookups are disabled"
    elif share_mode == "unlisted":
        public_material = "direct-link proof surfaces only; excluded from feed and rankings"
    else:
        public_material = "public proof card, profile, feed row, and ranking row"
    used_evidence = [
        "tokenbar.identity.v1 aggregate profile",
        "builder-story dimensions and claims",
        "usage/session counts after selected redactions",
        "completed proof-action stages",
        "verification receipt",
    ]
    if builder_signals.get("available"):
        used_evidence.append("aggregate builder-signal hosts and tags")
    return {
        "schema": "tokenbar.safe_evidence_receipt.v1",
        "token": proof.get("token"),
        "runId": run_id,
        "shareMode": share_mode,
        "summary": "Shareable TokenBar claims are generated from safe aggregate identity evidence only.",
        "usedEvidence": used_evidence,
        "builderSignalInbox": builder_signals,
        "neverUsed": ["raw transcripts", "source code", "raw diffs", ".env files", "credentials", "browser cookies"],
        "publicMaterial": public_material,
        "publicClaims": ["builder identity", "proof score", "loop maturity", "shipped-work receipt", "self-over-time comparison", "next-action plan"],
        "surfaces": surfaces,
        "redactions": redactions,
        "stageCount": len(completed_stages),
        "completedStages": completed_stages,
        "privacyBoundary": {
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "sourceCodeUploaded": False,
            "rawLogsUploaded": False,
        },
    }


def build_share_receipt(proof: dict, run_id: str = "", stages: list[dict] | None = None) -> dict:
    privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
    share_controls = proof.get("shareControls") if isinstance(proof.get("shareControls"), dict) else normalize_share_controls({})
    redactions = privacy.get("redactions") if isinstance(privacy.get("redactions"), dict) else share_controls.get("redactions") if isinstance(share_controls.get("redactions"), dict) else {}
    surface_bundle = proof.get("surfaceBundle") if isinstance(proof.get("surfaceBundle"), dict) else {}
    surfaces = [
        {
            "key": str(surface.get("key") or ""),
            "label": str(surface.get("label") or surface.get("key") or ""),
            "url": str(surface.get("url") or ""),
        }
        for surface in (surface_bundle.get("surfaces") if isinstance(surface_bundle.get("surfaces"), list) else [])
        if isinstance(surface, dict) and surface.get("url")
    ]
    completed_stages = [
        str(item.get("name") or "")
        for item in (stages or [])
        if isinstance(item, dict) and str(item.get("status") or "") == "complete"
    ]
    share_mode = proof_share_mode(proof)
    if share_mode == "private":
        public_material = "private audit receipt only; no public proof, profile, feed, or ranking lookup is enabled"
    elif share_mode == "unlisted":
        public_material = "direct-link proof and profile only; excluded from public feed and leaderboards"
    else:
        public_material = "public proof card, profile, For You feed row, and ranking/loop-board rows"
    redacted_fields = [str(name) for name, enabled in redactions.items() if enabled]
    title = str(proof.get("title") or "Builder Identity").strip()
    archetype = str(proof.get("primaryArchetype") or "Builder").strip()
    npc_class = str(proof.get("npcClass") or "local identity").strip()
    copy_safe_summary = (
        f"TokenBar proof {proof.get('token')}: {title} ({archetype} / {npc_class}); "
        f"proof {safe_number(proof.get('proofScore')):.0f}/100, loop {safe_number(proof.get('loopMaturity')):.0f}/100. "
        f"{public_material}. Raw transcripts, source code, private diffs, env files, and credentials were not uploaded"
        f"{'; redacted ' + ', '.join(redacted_fields) if redacted_fields else ''}."
    )
    return {
        "schema": "tokenbar.share_receipt.v1",
        "token": proof.get("token"),
        "runId": run_id,
        "shareMode": share_mode,
        "headline": f"{title} share receipt",
        "copySafeSummary": copy_safe_summary,
        "publicMaterial": public_material,
        "redactedFields": redacted_fields,
        "neverPublic": ["raw transcripts", "source code", "raw diffs", ".env files", "credentials", "browser cookies"],
        "surfaces": surfaces,
        "stageCount": len(completed_stages),
        "completedStages": completed_stages,
        "privacyBoundary": {
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "sourceCodeUploaded": False,
            "rawLogsUploaded": False,
            "publicSharingOptional": True,
        },
        "createdAt": now_epoch(),
    }


def create_action_run(
    identity: dict,
    base_url: str,
    idempotency_key: str = "",
    share_controls: object = None,
    owner_id: str | None = None,
) -> dict:
    identity = validate_identity(identity)
    digest = identity_digest(identity)
    normalized_share_controls = normalize_share_controls(share_controls)
    share_digest = hashlib.sha256(json.dumps(normalized_share_controls, sort_keys=True).encode("utf-8")).hexdigest()[:8]
    seed = f"{ACTION_NAME}:{identity['token']}:{idempotency_key or digest}:{share_digest}"
    run_id = "run_" + hashlib.sha256(seed.encode("utf-8")).hexdigest()[:16]
    proof = build_proof_card(identity, base_url, normalized_share_controls)
    stages = [
        stage("request-received", "Accepted one explicit Builder Identity proof action."),
        stage("local-boundary-check", "Confirmed the uploaded artifact declares no raw transcripts or source code."),
        stage("identity-validation", "Validated tokenbar.identity.v1 schema and token shape."),
        stage("proof-card-built", "Built a shareable proof card from safe aggregate fields and selected redactions."),
        stage("persisted", "Saved run metadata and proof card for reload."),
        stage("ready", "Proof card can now be opened or shared."),
    ]
    proof["verificationReceipt"] = build_verification_receipt(proof, run_id, stages)
    proof["safeEvidenceReceipt"] = build_safe_evidence_receipt(proof, run_id, stages)
    proof["nextActionPlan"] = build_next_action_plan(proof)
    proof["shareReceipt"] = build_share_receipt(proof, run_id, stages)
    return {
        "schema": "tokenbar.action_run.v1",
        "runId": run_id,
        "action": ACTION_NAME,
        "status": "complete",
        "ownerId": owner_id,
        "token": proof["token"],
        "identityDigest": digest,
        "stages": stages,
        "result": {
            "summary": f"{proof['title']} proof card ready.",
            "nextAction": "Open the proof card, profile, social feed, or rankings page. No raw transcripts or source code were uploaded.",
            "proofCardUrl": proof["proofCardUrl"],
            "profileUrl": proof["profileUrl"],
            "auditRunUrl": f"{base_url}/api/actions?run={run_id}",
            "socialUrl": proof["socialUrl"],
            "rankingsUrl": proof["rankingsUrl"],
            "loopRankingsUrl": proof["loopRankingsUrl"],
            "trailerUrl": proof["trailerUrl"],
            "surfaceBundle": proof.get("surfaceBundle"),
        },
        "proof": proof,
        "createdAt": now_epoch(),
    }


def axis_score(proof: dict, key: str) -> float:
    story = proof.get("builderStory") if isinstance(proof.get("builderStory"), dict) else {}
    axes = story.get("axes") if isinstance(story.get("axes"), list) else []
    for axis in axes:
        if isinstance(axis, dict) and axis.get("key") == key:
            return safe_number(axis.get("score"))
    return 0


def ranking_breakdown_for_proof(proof: dict) -> dict:
    proof_score = safe_number(proof.get("proofScore"))
    loop_maturity = safe_number(proof.get("loopMaturity"))
    specificity = safe_number(proof.get("specificityScore"))
    total_tokens = safe_number(proof.get("totalTokens"))
    session_count = safe_number(proof.get("sessionCount"))
    verification_receipt = proof.get("verificationReceipt")
    completed_stages = verification_receipt.get("completedStages", []) if isinstance(verification_receipt, dict) else []
    outcomes_component = min(100.0, max(0, len(completed_stages)) * 100.0 / 6.0) if isinstance(completed_stages, list) else 0.0
    try:
        token_component = min(100.0, math.log10(max(1.0, total_tokens)) * 10.0)
    except Exception:
        token_component = 0.0
    try:
        range_component = min(100.0, math.log10(max(1.0, session_count)) * 24.0)
    except Exception:
        range_component = 0.0
    weights = {
        "proof": 0.34,
        "loop": 0.26,
        "specificity": 0.18,
        "outcomes": 0.14,
        "range": 0.06,
        "tokens": 0.06,
    }
    return {
        "proof": round(proof_score, 1),
        "loop": round(loop_maturity, 1),
        "specificity": round(specificity, 1),
        "outcomes": round(outcomes_component, 1),
        "range": round(range_component, 1),
        "tokens": round(token_component, 1),
        "weights": weights,
        "note": "Token volume is capped at 6% of the composite ranking score and treated as a safety signal.",
    }


def composite_ranking_score(breakdown: dict) -> float:
    weights = breakdown.get("weights") if isinstance(breakdown.get("weights"), dict) else {}
    return (
        safe_number(breakdown.get("proof")) * safe_number(weights.get("proof"))
        + safe_number(breakdown.get("loop")) * safe_number(weights.get("loop"))
        + safe_number(breakdown.get("specificity")) * safe_number(weights.get("specificity"))
        + safe_number(breakdown.get("outcomes")) * safe_number(weights.get("outcomes"))
        + safe_number(breakdown.get("range")) * safe_number(weights.get("range"))
        + safe_number(breakdown.get("tokens")) * safe_number(weights.get("tokens"))
    )


def proof_to_feed_item(proof: dict, base_url: str = "") -> dict:
    story = proof.get("builderStory") if isinstance(proof.get("builderStory"), dict) else {}
    facts = proof.get("facts") if isinstance(proof.get("facts"), list) else []
    usage_fact = next((item for item in facts if isinstance(item, dict) and item.get("label") == "Usage signal"), {})
    proof_facts = []
    for item in facts[:5]:
        if not isinstance(item, dict):
            continue
        proof_facts.append(
            {
                "label": str(item.get("label") or "").strip(),
                "value": str(item.get("value") or "").strip(),
                "note": str(item.get("note") or "").strip(),
            }
        )
    what_proved = [
        str(item).strip()
        for item in (story.get("whatProved") if isinstance(story.get("whatProved"), list) else [])
        if str(item).strip()
    ][:3]
    tradeoffs = [
        str(item).strip()
        for item in (story.get("tradeoffs") if isinstance(story.get("tradeoffs"), list) else [])
        if str(item).strip()
    ][:2]
    uncertainties = [
        str(item).strip()
        for item in (story.get("uncertainties") if isinstance(story.get("uncertainties"), list) else [])
        if str(item).strip()
    ][:2]
    shipped_work = [
        {
            "label": str(item.get("label") or "").strip(),
            "value": str(item.get("value") or "").strip(),
            "note": str(item.get("note") or "").strip(),
            "provenance": str(item.get("provenance") or "").strip(),
        }
        for item in (story.get("shippedWork") if isinstance(story.get("shippedWork"), list) else [])
        if isinstance(item, dict) and str(item.get("label") or "").strip()
    ][:4]
    title = str(proof.get("title") or "Builder Identity").strip()
    owner_profile = clean_owner_profile(proof.get("ownerProfile"), fallback_name=title)
    archetype = str(proof.get("primaryArchetype") or "Builder").strip()
    npc_class = str(proof.get("npcClass") or "private proof").strip()
    proof_score = safe_number(proof.get("proofScore"))
    loop_maturity = safe_number(proof.get("loopMaturity"))
    total_tokens = safe_number(proof.get("totalTokens"))
    session_count = int(safe_number(proof.get("sessionCount")))
    token = str(proof.get("token") or "")
    submission = clean_submission_metadata(
        proof.get("hackathonSubmission") or proof.get("submittedProject"),
        fallback_title=title,
    )
    proof_url = proof.get("proofCardUrl")
    profile_url = proof.get("profileUrl")
    social_url = proof.get("socialUrl")
    rankings_url = proof.get("rankingsUrl")
    loop_rankings_url = proof.get("loopRankingsUrl")
    trailer_url = proof.get("trailerUrl")
    if base_url and token:
        proof_url = f"{base_url}/api/actions?token={quote(token)}"
        profile_url = f"{base_url}/api/profiles?token={quote(token)}"
        social_url = f"{base_url}/social?token={quote(token)}"
        rankings_url = f"{base_url}/rankings?token={quote(token)}"
        loop_rankings_url = f"{base_url}/rankings?token={quote(token)}#loop"
        trailer_url = f"{proof_url}&view=trailer"
    share_url = profile_url or proof_url or social_url or rankings_url
    share_copy = str(proof.get("shareCopy") or "").strip()
    if not share_copy:
        share_copy = (
            f"My TokenBar builder identity is {title}: {archetype} / {npc_class}. "
            f"Proof {proof_score:.0f}/100, loop maturity {loop_maturity:.0f}/100. "
            f"No raw transcripts or source code uploaded. {share_url or ''}"
        ).strip()
    ranking_breakdown = ranking_breakdown_for_proof(proof)
    composite = composite_ranking_score(ranking_breakdown)
    privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
    share_controls = proof.get("shareControls") if isinstance(proof.get("shareControls"), dict) else normalize_share_controls({})
    visibility = str(proof.get("publicVisibility") or share_controls.get("visibility") or privacy.get("shareMode") or "public").lower()
    redactions = share_controls.get("redactions") if isinstance(share_controls.get("redactions"), dict) else privacy.get("redactions") if isinstance(privacy.get("redactions"), dict) else {}
    surface_bundle = build_surface_bundle(
        token=token,
        proof_url=str(proof_url or ""),
        profile_url=str(profile_url or ""),
        social_url=str(social_url or ""),
        rankings_url=str(rankings_url or ""),
        loop_rankings_url=str(loop_rankings_url or ""),
        trailer_url=str(trailer_url or ""),
        visibility=visibility,
        share_copy=share_copy,
    )
    self_comparison = proof.get("selfComparison") if isinstance(proof.get("selfComparison"), dict) else {}
    verification_receipt = proof.get("verificationReceipt") if isinstance(proof.get("verificationReceipt"), dict) else {}
    safe_evidence_receipt = proof.get("safeEvidenceReceipt") if isinstance(proof.get("safeEvidenceReceipt"), dict) else build_safe_evidence_receipt(proof)
    next_action_plan = proof.get("nextActionPlan") if isinstance(proof.get("nextActionPlan"), dict) else build_next_action_plan(proof)
    share_receipt = proof.get("shareReceipt") if isinstance(proof.get("shareReceipt"), dict) else build_share_receipt(proof)
    builder_signals = clean_builder_signal_summary(proof.get("builderSignalInbox") or proof.get("socialLearningSignals"))
    spotlight = clean_spotlight_sources(proof.get("spotlightSources"))
    spotlight_note = (spotlight.get("notes") or [""])[0] if spotlight else ""
    spotlight_story = spotlight.get("story") if isinstance(spotlight.get("story"), dict) else {}
    spotlight_feature = str(spotlight_story.get("features") or "").strip()
    feed_story = {
        "whatShipped": spotlight_note or spotlight_feature or (what_proved[0] if what_proved else story.get("headline") or f"{title} proof card"),
        "whyItMatters": story.get("summary") or proof.get("verdict") or "A safe public builder identity proof was generated from local TokenBar analysis.",
        "tradeoff": tradeoffs[0] if tradeoffs else (uncertainties[0] if uncertainties else "Public claims stay bounded to safe aggregate evidence."),
        "nextFrontier": story.get("nextFrontier") or "",
        "provenance": "safe aggregate proof-card action; no raw transcripts or source code",
    }
    return {
        "schema": "tokenbar.action_feed_item.v1",
        "token": token,
        "title": title,
        "projectTitle": submission.get("projectTitle") if submission else None,
        "event": submission.get("event") if submission else None,
        "track": submission.get("track") if submission else None,
        "repoUrl": submission.get("repoUrl") if submission else None,
        "demoUrl": submission.get("demoUrl") if submission else None,
        "hackathonSubmission": submission,
        "submittedProject": submission,
        "nickname": owner_profile.get("nickname") or title,
        "handle": owner_profile.get("handle"),
        "region": owner_profile.get("region") or "Global",
        "ownerProfile": owner_profile,
        "profileLinks": owner_profile.get("links") or {},
        "primaryArchetype": archetype,
        "npcClass": npc_class,
        "bio": owner_profile.get("bio") or story.get("summary") or proof.get("verdict") or f"{title} proof card from local TokenBar analysis.",
        "headline": story.get("headline") or f"{title} proof card",
        "proofFacts": proof_facts,
        "feedStory": feed_story,
        "whatProved": what_proved,
        "shippedWork": shipped_work,
        "tradeoffs": tradeoffs,
        "uncertainties": uncertainties,
        "whatRemainsUncertain": uncertainties,
        "nextFrontier": story.get("nextFrontier") or "",
        "strongestSignal": story.get("strongestSignal") or "",
        "weakestSignal": story.get("weakestSignal") or "",
        "proofScore": round(proof_score, 1),
        "score": round(composite, 1),
        "loopMaturity": round(loop_maturity, 1),
        "specificityScore": round(safe_number(proof.get("specificityScore")), 1),
        "tokenCount": total_tokens,
        "sessionCount": session_count,
        "rankingBreakdown": ranking_breakdown,
        "usageFact": usage_fact.get("value") or format_tokens(total_tokens),
        "proofCardUrl": proof_url,
        "profileUrl": profile_url,
        "shareUrl": share_url,
        "socialUrl": social_url,
        "rankingsUrl": rankings_url,
        "loopRankingsUrl": loop_rankings_url,
        "trailerUrl": trailer_url,
        "shareCopy": share_copy,
        "surfaceBundle": surface_bundle,
        "publicVisibility": visibility,
        "shareControls": normalize_share_controls({"visibility": visibility, "redactions": redactions}),
        "createdAt": proof.get("createdAt") or 0,
        "rankSignals": {
            "proof": round(proof_score, 1),
            "loop": round(loop_maturity, 1),
            "craftTaste": round(axis_score(proof, "craftTaste"), 1),
            "completion": round(axis_score(proof, "completion"), 1),
            "ambition": round(axis_score(proof, "ambition"), 1),
            "discernment": round(axis_score(proof, "discernment"), 1),
        },
        "selfComparison": self_comparison,
        "verificationReceipt": verification_receipt,
        "safeEvidenceReceipt": safe_evidence_receipt,
        "builderSignalInbox": builder_signals,
        "socialLearningSignals": builder_signals,
        "spotlightSources": spotlight,
        "nextActionPlan": next_action_plan,
        "shareReceipt": share_receipt,
        "privacy": {
            "rawTranscriptsIncluded": bool(privacy.get("rawTranscriptsIncluded")),
            "sourceCodeIncluded": bool(privacy.get("sourceCodeIncluded")),
            "uploadedArtifact": privacy.get("uploadedArtifact") or "generated identity JSON only",
            "shareMode": visibility,
            "redactions": redactions,
        },
    }


def aggregate_action_feed(store: dict, base_url: str = "") -> dict:
    proofs = [
        proof
        for proof in (store.get("proofCards") or {}).values()
        if isinstance(proof, dict)
    ]

    def proof_visibility(proof: dict) -> str:
        privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
        return str(proof.get("publicVisibility") or privacy.get("shareMode") or "public").lower()

    public_proofs = [proof for proof in proofs if proof_visibility(proof) in {"public", "listed"}]
    unlisted_proofs = [proof for proof in proofs if proof_visibility(proof) == "unlisted"]
    private_proofs = [proof for proof in proofs if proof_visibility(proof) == "private"]
    feed = [proof_to_feed_item(proof, base_url) for proof in public_proofs]
    feed.sort(key=lambda item: (safe_number(item.get("score")), safe_number(item.get("createdAt"))), reverse=True)
    submission_events: dict[str, int] = {}
    submission_tracks: dict[str, int] = {}
    for item in feed:
        submission = item.get("hackathonSubmission") if isinstance(item.get("hackathonSubmission"), dict) else {}
        event = str(submission.get("event") or item.get("event") or "").strip()
        track = str(submission.get("track") or item.get("track") or "").strip()
        if event:
            submission_events[event] = submission_events.get(event, 0) + 1
        if track:
            submission_tracks[track] = submission_tracks.get(track, 0) + 1
    loop_rankings = sorted(
        feed,
        key=lambda item: (
            safe_number(item.get("loopMaturity")),
            safe_number(item.get("proofScore")),
            safe_number(item.get("createdAt")),
        ),
        reverse=True,
    )

    def by_signal(signal: str) -> list[dict]:
        return sorted(
            feed,
            key=lambda item: (
                safe_number((item.get("rankSignals") or {}).get(signal)),
                safe_number(item.get("proofScore")),
                safe_number(item.get("createdAt")),
            ),
            reverse=True,
        )[:12]

    def board(label: str, description: str, items: list[dict], score_key: str = "score") -> dict:
        return {
            "label": label,
            "description": description,
            "scoreKey": score_key,
            "items": items[:12],
        }

    def region_keys(region_value: object) -> list[str]:
        region = str(region_value or "Global").strip() or "Global"
        normalized = region.lower()
        keys = [region]
        southeast_asia = {
            "singapore",
            "sg",
            "malaysia",
            "indonesia",
            "thailand",
            "vietnam",
            "philippines",
            "brunei",
            "cambodia",
            "laos",
            "myanmar",
            "timor-leste",
            "southeast asia",
            "south east asia",
        }
        europe = {
            "europe",
            "uk",
            "united kingdom",
            "ireland",
            "france",
            "germany",
            "spain",
            "italy",
            "netherlands",
            "switzerland",
            "sweden",
            "norway",
            "denmark",
            "finland",
            "poland",
            "portugal",
        }
        north_america = {
            "north america",
            "usa",
            "us",
            "united states",
            "canada",
            "mexico",
        }
        if normalized in southeast_asia and "Southeast Asia" not in keys:
            keys.append("Southeast Asia")
        if normalized in europe and "Europe" not in keys:
            keys.append("Europe")
        if normalized in north_america and "North America" not in keys:
            keys.append("North America")
        return keys

    regional_leaderboards: dict[str, list[dict]] = {"Global": feed[:12]}
    for item in feed:
        for key in region_keys(item.get("region")):
            regional_leaderboards.setdefault(key, []).append(item)
    regional_leaderboards = {
        key: sorted(rows, key=lambda item: (safe_number(item.get("score")), safe_number(item.get("createdAt"))), reverse=True)[:12]
        for key, rows in sorted(regional_leaderboards.items())
        if key != "Global" or rows
    }

    def add_rank_badge(item: dict, key: str, label: str, rank: int, total: int, score_key: str = "score") -> None:
        score_source = item.get(score_key) if item.get(score_key) is not None else (item.get("rankSignals") or {}).get(score_key)
        score_value = safe_number(score_source)
        if not score_value:
            score_value = safe_number(item.get("score") or item.get("proofScore"))
        placement = {
            "key": key,
            "label": label,
            "rank": rank,
            "total": total,
            "scoreKey": score_key,
            "score": round(score_value, 1),
        }
        placements = item.setdefault("rankPlacements", {})
        if isinstance(placements, dict):
            placements[key] = placement
        badges = item.setdefault("rankBadges", [])
        if isinstance(badges, list) and not any(isinstance(badge, dict) and badge.get("key") == key for badge in badges):
            badges.append(placement)

    for index, item in enumerate(feed):
        add_rank_badge(item, "global", f"Global #{index + 1}", index + 1, len(feed), "score")
    for index, item in enumerate(loop_rankings):
        add_rank_badge(item, "loop", f"Loop #{index + 1}", index + 1, len(loop_rankings), "loopMaturity")
    for region, rows in regional_leaderboards.items():
        if region == "Global":
            continue
        for index, item in enumerate(rows):
            add_rank_badge(item, f"region:{region}", f"{region} #{index + 1}", index + 1, len(rows), "score")

    leaderboards = {
        "overall": board(
            "Overall proof",
            "Composite ranking from proof, loop maturity, specificity, verified outcomes, range, and capped token signal.",
            feed,
            "score",
        ),
        "loop": board(
            "Loop maturity",
            "Builders who turn prompts into repeatable agent loops with visible proof and recovery.",
            loop_rankings,
            "loopMaturity",
        ),
        "craftTaste": board(
            "Craft and taste",
            "Evidence of product judgment, presentation quality, and human-readable output.",
            by_signal("craftTaste"),
            "craftTaste",
        ),
        "completion": board(
            "Completion",
            "Builders who close loops with shipped artifacts, verification, and clean next steps.",
            by_signal("completion"),
            "completion",
        ),
        "ambition": board(
            "Ambition",
            "Big surface area, multi-agent orchestration, and willingness to attempt difficult systems.",
            by_signal("ambition"),
            "ambition",
        ),
        "discernment": board(
            "Discernment",
            "Good judgment around privacy, uncertainty, tradeoffs, and what not to overclaim.",
            by_signal("discernment"),
            "discernment",
        ),
    }
    return {
        "schema": "tokenbar.action_feed.v1",
        "proofCardCount": len(feed),
        "storedProofCardCount": len(proofs),
        "feed": feed[:20],
        "loopRankings": loop_rankings[:12],
        "leaderboards": leaderboards,
        "regionalLeaderboards": regional_leaderboards,
        "submissionEvents": dict(sorted(submission_events.items(), key=lambda item: (-item[1], item[0]))),
        "submissionTracks": dict(sorted(submission_tracks.items(), key=lambda item: (-item[1], item[0]))),
        "updatedAt": now_epoch(),
        "shareContract": {
            "schema": "tokenbar.share_contract.v1",
            "publicProofCount": len(public_proofs),
            "unlistedProofCount": len(unlisted_proofs),
            "privateProofCount": len(private_proofs),
            "publicIncludedInFeed": True,
            "unlistedIncludedInFeed": False,
            "privateIncludedInFeed": False,
            "leaderboardsUse": "public proof cards only",
            "tokenLookup": "public and unlisted tokens resolve directly; private proof tokens are disabled",
            "publicClaims": [
                "proofScore",
                "loopMaturity",
                "rankSignals",
                "feedStory",
                "shippedWork",
                "nextActionPlan",
                "verificationReceipt",
                "shareReceipt",
            ],
            "neverPublic": [
                "rawTranscripts",
                "sourceCode",
                "privateDiffs",
                "credentials",
                "envFiles",
            ],
        },
        "privacyBoundary": {
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "publicMaterial": "proof cards generated from safe identity JSON only",
        },
    }


def identity_trailer_html(proof: dict) -> str:
    story = proof.get("builderStory") if isinstance(proof.get("builderStory"), dict) else {}
    spotlight = clean_spotlight_sources(proof.get("spotlightSources"))
    privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
    title = html.escape(str(proof.get("title") or "Builder Identity"))
    archetype = html.escape(str(proof.get("primaryArchetype") or "Builder"))
    npc_class = html.escape(str(proof.get("npcClass") or "proof card"))
    proof_score = safe_number(proof.get("proofScore"))
    loop_maturity = safe_number(proof.get("loopMaturity"))
    sessions = spotlight.get("sessions") or []
    projects = spotlight.get("projects") or []
    notes = spotlight.get("notes") or []
    beats = spotlight.get("storyBeats") or [
        {"label": "Key insight", "text": "The builder turned local agent evidence into a shareable identity story."},
        {"label": "Struggle", "text": "The public proof stays careful about what it does not know."},
        {"label": "Progress", "text": "The next loop is now visible, not buried in a transcript."},
    ]
    spotlight_story = spotlight.get("story") if isinstance(spotlight.get("story"), dict) else {}
    story_beats = [
        {"label": "Insight", "text": spotlight_story.get("insight") or ""},
        {"label": "Struggle", "text": spotlight_story.get("struggle") or ""},
        {"label": "Feature", "text": spotlight_story.get("features") or ""},
        {"label": "Progress", "text": spotlight_story.get("progress") or ""},
    ]
    anchor_cards = "".join(
        f"<li><span>{html.escape(kind)}</span><strong>{html.escape(value)}</strong><em>user-provided public anchor</em></li>"
        for kind, values in [("Session", sessions), ("Project", projects), ("Note", notes)]
        for value in values[:4]
    )
    beat_cards = "".join(
        f"<div><span>{html.escape(str(beat.get('label') or 'Beat'))}</span><p>{html.escape(str(beat.get('text') or ''))}</p></div>"
        for beat in (story_beats + beats)[:8]
        if isinstance(beat, dict)
        if str(beat.get("text") or "").strip()
    )
    raw_state = "No raw transcripts" if privacy.get("rawTranscriptsIncluded") is False else "Review privacy flag"
    source_state = "No source code" if privacy.get("sourceCodeIncluded") is False else "Review privacy flag"
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>TokenBar identity trailer - {title}</title>
  <style>
    :root {{ color-scheme: dark; font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    body {{ margin:0; background:#05070b; color:#f8fbff; }}
    main {{ min-height:100vh; padding:42px 24px; display:grid; place-items:center; background:
      radial-gradient(circle at 18% 16%, rgba(40,128,255,.32), transparent 32%),
      radial-gradient(circle at 82% 10%, rgba(255,115,45,.22), transparent 26%),
      linear-gradient(135deg,#05070b,#0b1220 54%,#08090d); }}
    article {{ width:min(1120px,100%); border:1px solid rgba(197,214,255,.22); border-radius:34px; overflow:hidden; box-shadow:0 40px 120px rgba(0,0,0,.55); background:rgba(7,12,22,.82); }}
    header {{ padding:46px; display:grid; grid-template-columns:1.05fr .95fr; gap:34px; align-items:end; border-bottom:1px solid rgba(197,214,255,.14); }}
    .eyebrow {{ color:#91bdff; font-size:12px; font-weight:950; letter-spacing:.16em; text-transform:uppercase; }}
    h1 {{ margin:12px 0 16px; font-size:clamp(54px,8vw,108px); line-height:.86; letter-spacing:-.055em; }}
    p {{ color:#b8c2d6; font-size:18px; line-height:1.55; }}
    .scoregrid {{ display:grid; grid-template-columns:repeat(2,1fr); gap:12px; }}
    .scoregrid div, .beatgrid div, li {{ border:1px solid rgba(197,214,255,.16); border-radius:20px; padding:18px; background:linear-gradient(145deg,rgba(255,255,255,.08),rgba(255,255,255,.025)); }}
    .scoregrid span, .beatgrid span, li span {{ display:block; color:#7fb2ff; font-size:12px; font-weight:950; letter-spacing:.12em; text-transform:uppercase; }}
    .scoregrid strong {{ display:block; margin-top:8px; font-size:44px; line-height:1; }}
    section {{ padding:34px 46px; border-bottom:1px solid rgba(197,214,255,.12); }}
    h2 {{ margin:0 0 16px; font-size:34px; letter-spacing:-.035em; }}
    .filmstrip {{ display:grid; grid-template-columns:repeat(4,1fr); gap:14px; }}
    .filmstrip div {{ min-height:170px; border-radius:24px; border:1px solid rgba(197,214,255,.16); background:
      linear-gradient(160deg,rgba(255,255,255,.12),rgba(255,255,255,.02)),
      radial-gradient(circle at 30% 20%,rgba(58,145,255,.45),transparent 38%); padding:18px; position:relative; overflow:hidden; }}
    .filmstrip div:after {{ content:""; position:absolute; inset:auto 18px 18px; height:4px; border-radius:999px; background:linear-gradient(90deg,#2887ff,#48d25d,#ff7a1a); }}
    .filmstrip strong {{ position:absolute; bottom:34px; left:18px; right:18px; font-size:22px; line-height:1.05; }}
    .beatgrid {{ display:grid; grid-template-columns:repeat(3,1fr); gap:14px; }}
    ul {{ list-style:none; padding:0; margin:0; display:grid; grid-template-columns:repeat(auto-fit,minmax(220px,1fr)); gap:12px; }}
    li strong {{ display:block; margin-top:8px; color:#fff; font-size:18px; overflow-wrap:anywhere; }}
    li em {{ display:block; margin-top:10px; color:#8794aa; font-style:normal; font-weight:800; font-size:11px; text-transform:uppercase; letter-spacing:.08em; }}
    footer {{ padding:28px 46px; display:flex; justify-content:space-between; gap:18px; color:#a8b3c8; flex-wrap:wrap; }}
    a {{ color:#ffffff; font-weight:900; }}
    @media (max-width:850px) {{ header {{ grid-template-columns:1fr; }} .filmstrip, .beatgrid {{ grid-template-columns:1fr; }} h1 {{ font-size:58px; }} }}
  </style>
</head>
<body>
  <main>
    <article>
      <header>
        <div>
          <div class="eyebrow">TokenBar identity trailer</div>
          <h1>{title}</h1>
          <p>{html.escape(str(story.get("summary") or proof.get("verdict") or "A 30-second builder identity trailer from safe aggregate proof."))}</p>
        </div>
        <div class="scoregrid">
          <div><span>Archetype</span><strong>{archetype}</strong></div>
          <div><span>Class</span><strong>{npc_class}</strong></div>
          <div><span>Proof</span><strong>{proof_score:.0f}</strong></div>
          <div><span>Loop</span><strong>{loop_maturity:.0f}</strong></div>
        </div>
      </header>
      <section>
        <h2>30-second micro-storyboard</h2>
        <div class="filmstrip">
          <div><span>00-06</span><strong>The private build trail wakes up.</strong></div>
          <div><span>06-13</span><strong>Signals become a builder identity.</strong></div>
          <div><span>13-21</span><strong>Struggles, tradeoffs, and shipped proof surface.</strong></div>
          <div><span>21-30</span><strong>A shareable card closes the loop.</strong></div>
        </div>
      </section>
      <section>
        <h2>Spotlight sessions & projects</h2>
        <p>These are builder-selected anchors. TokenBar does not read or upload raw session transcripts, source files, private diffs, or secrets for this public trailer.</p>
        <ul>{anchor_cards or "<li><span>Anchor</span><strong>No spotlight anchors selected yet.</strong><em>run tokenbar publish-proof --spotlight-note ...</em></li>"}</ul>
      </section>
      <section>
        <h2>Story beats</h2>
        <div class="beatgrid">{beat_cards}</div>
      </section>
      <footer>
        <span>{html.escape(raw_state)} · {html.escape(source_state)}</span>
        <a href="{html.escape(str(proof.get("profileUrl") or "#"))}">Open public profile</a>
      </footer>
    </article>
  </main>
</body>
</html>"""


def proof_card_html(proof: dict) -> str:
    story = proof.get("builderStory") if isinstance(proof.get("builderStory"), dict) else {}
    privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
    self_comparison = proof.get("selfComparison") if isinstance(proof.get("selfComparison"), dict) else {}
    receipt = proof.get("verificationReceipt") if isinstance(proof.get("verificationReceipt"), dict) else {}
    safe_receipt = proof.get("safeEvidenceReceipt") if isinstance(proof.get("safeEvidenceReceipt"), dict) else build_safe_evidence_receipt(proof)
    share_receipt = proof.get("shareReceipt") if isinstance(proof.get("shareReceipt"), dict) else build_share_receipt(proof, str(receipt.get("runId") or ""))
    raw_state = "No raw transcripts" if privacy.get("rawTranscriptsIncluded") is False else "Review privacy flag"
    source_state = "No source code" if privacy.get("sourceCodeIncluded") is False else "Review privacy flag"
    artifact_state = str(privacy.get("uploadedArtifact") or "generated identity JSON only")
    share_mode = str(proof.get("publicVisibility") or privacy.get("shareMode") or "public")
    redactions = privacy.get("redactions") if isinstance(privacy.get("redactions"), dict) else {}
    redaction_state = ", ".join(name for name, enabled in redactions.items() if enabled) or "none"
    share_copy = str(proof.get("shareCopy") or "")
    next_frontier = str(story.get("nextFrontier") or "")
    facts = "".join(
        f"<li><span>{html.escape(str(f.get('label', '')))}</span><strong>{html.escape(str(f.get('value', '')))}</strong><p>{html.escape(str(f.get('note', '')))}</p></li>"
        for f in proof.get("facts", [])
        if isinstance(f, dict)
    )
    axes = "".join(
        f"<li><span>{html.escape(str(axis.get('label', '')))}</span><strong>{safe_number(axis.get('score')):.0f}</strong><p>{html.escape(str(axis.get('claim', '')))}</p><em>{html.escape(str(axis.get('confidence', 'low')))} confidence</em></li>"
        for axis in story.get("axes", [])
        if isinstance(axis, dict)
    )
    proved = "".join(
        f"<li>{html.escape(str(item))}</li>"
        for item in story.get("whatProved", [])
    )
    shipped_work = "".join(
        (
            "<div>"
            f"<span>{html.escape(str(item.get('label') or 'Evidence'))}</span>"
            f"<strong>{html.escape(str(item.get('value') or ''))}</strong>"
            f"<p>{html.escape(str(item.get('note') or ''))}</p>"
            f"<em>{html.escape(str(item.get('provenance') or 'safe aggregate evidence'))}</em>"
            "</div>"
        )
        for item in (story.get("shippedWork") if isinstance(story.get("shippedWork"), list) else [])
        if isinstance(item, dict)
    )
    uncertainties = "".join(
        f"<li>{html.escape(str(item))}</li>"
        for item in story.get("uncertainties", [])
    )
    privacy_cards = "".join(
        f"<div><span>{html.escape(label)}</span><strong>{html.escape(value)}</strong></div>"
        for label, value in [
            ("Raw transcripts", raw_state),
            ("Source code", source_state),
            ("Share mode", share_mode),
            ("Redactions", redaction_state),
            ("Uploaded artifact", artifact_state),
        ]
    )
    rank_cards = "".join(
        (
            "<div>"
            f"<span>{html.escape(str(item.get('label') or 'Rank'))}</span>"
            f"<strong>#{int(safe_number(item.get('rank')) or 0)}"
            f"<small> of {int(safe_number(item.get('total')) or 0)}</small></strong>"
            f"<p>{html.escape(str(item.get('scoreKey') or 'score'))}: {safe_number(item.get('score')):.0f}</p>"
            "</div>"
        )
        for item in (proof.get("rankBadges") if isinstance(proof.get("rankBadges"), list) else [])
        if isinstance(item, dict)
    )
    comparison_cards = "".join(
        f"<li><span>{html.escape(str(card.get('label') or 'Self signal'))}</span><strong>{html.escape(str(card.get('value') or ''))}</strong><p>{html.escape(str(card.get('note') or ''))}</p></li>"
        for card in (self_comparison.get("cards") if isinstance(self_comparison.get("cards"), list) else [])
        if isinstance(card, dict)
    )
    comparison_basis = html.escape(str(self_comparison.get("basis") or "Safe aggregate windows only."))
    comparison_uncertainty = html.escape(str(self_comparison.get("uncertainty") or "Multiple claims make this trend sharper."))
    completed_stages = ", ".join(str(item) for item in (receipt.get("completedStages") if isinstance(receipt.get("completedStages"), list) else []) if item)
    redacted_fields = ", ".join(name for name, enabled in (receipt.get("redactions") if isinstance(receipt.get("redactions"), dict) else {}).items() if enabled) or "none"
    receipt_cards = "".join(
        f"<div><span>{html.escape(label)}</span><strong>{html.escape(value)}</strong></div>"
        for label, value in [
            ("Receipt schema", str(receipt.get("schema") or "tokenbar.verification_receipt.v1")),
            ("Run id", str(receipt.get("runId") or "")),
            ("Completed stages", str(receipt.get("stageCount") or 0)),
            ("Redacted fields", redacted_fields),
            ("Ranking rule", str((receipt.get("rankingPolicy") or {}).get("antiPayToWin") or "Token volume is capped.")),
        ]
    )
    not_included = "".join(
        f"<li>{html.escape(str(item))}</li>"
        for item in (receipt.get("notIncluded") if isinstance(receipt.get("notIncluded"), list) else [])
    )
    safe_used = "".join(
        f"<li>{html.escape(str(item))}</li>"
        for item in (safe_receipt.get("usedEvidence") if isinstance(safe_receipt.get("usedEvidence"), list) else [])
    )
    safe_never_used = "".join(
        f"<li>{html.escape(str(item))}</li>"
        for item in (safe_receipt.get("neverUsed") if isinstance(safe_receipt.get("neverUsed"), list) else [])
    )
    safe_surfaces = "".join(
        f"<li><span>{html.escape(str(item.get('label') or item.get('key') or 'Surface'))}</span><strong>{html.escape(str(item.get('url') or ''))}</strong></li>"
        for item in (safe_receipt.get("surfaces") if isinstance(safe_receipt.get("surfaces"), list) else [])
        if isinstance(item, dict)
    )
    builder_signals = clean_builder_signal_summary(proof.get("builderSignalInbox") or proof.get("socialLearningSignals"))
    spotlight = clean_spotlight_sources(proof.get("spotlightSources"))
    reference_chips = []
    for item in (builder_signals.get("topTags") or [])[:5]:
        if isinstance(item, dict) and item.get("name"):
            reference_chips.append(f"<span>{html.escape(str(item.get('name')))}<small>{int(safe_number(item.get('count')))}</small></span>")
    for item in (builder_signals.get("topHosts") or [])[:4]:
        if isinstance(item, dict) and item.get("name"):
            reference_chips.append(f"<span>{html.escape(str(item.get('name')))}<small>{int(safe_number(item.get('count')))}</small></span>")
    reference_radar_html = ""
    if builder_signals.get("available"):
        reference_radar_html = f"""
      <section>
        <h2>Builder reference radar</h2>
        <p class="receipt-note">What this builder studies between work sessions. TokenBar turns saved articles, demos, repos, videos, and social posts into a private learning trail; the public proof only shows safe aggregates.</p>
        <div class="reference-radar" aria-label="Builder reference radar">
          <div>
            <span>Saved references</span>
            <strong>{int(safe_number(builder_signals.get("signalCount")))}</strong>
            <p>{html.escape(str(builder_signals.get("story") or "Local saved links are summarized as aggregate builder taste signals."))}</p>
          </div>
          <div>
            <span>Study pattern</span>
            <strong>{html.escape(", ".join(str((item or {}).get("name")) for item in (builder_signals.get("topTags") or [])[:2] if isinstance(item, dict) and item.get("name")) or "emerging")}</strong>
            <p>Useful for the social app: it explains what references shaped the builder without exposing the actual private inbox.</p>
          </div>
          <div>
            <span>Public boundary</span>
            <strong>Aggregate only</strong>
            <p>Raw URLs, titles, notes, page content, transcripts, and source code stay local.</p>
          </div>
        </div>
        <div class="reference-chips">{''.join(reference_chips) or "<span>local signal<small>1</small></span>"}</div>
      </section>
        """
    spotlight_anchor_cards = "".join(
        f"<div><span>{html.escape(kind)}</span><strong>{html.escape(value)}</strong><p>User-selected public anchor; no raw files read.</p></div>"
        for kind, values in [("Session", spotlight.get("sessions") or []), ("Project", spotlight.get("projects") or []), ("Note", spotlight.get("notes") or [])]
        for value in values[:4]
    )
    spotlight_beat_cards = "".join(
        f"<div><span>{html.escape(str(beat.get('label') or 'Beat'))}</span><p>{html.escape(str(beat.get('text') or ''))}</p></div>"
        for beat in (spotlight.get("storyBeats") or [])
        if isinstance(beat, dict)
    )
    spotlight_story = spotlight.get("story") if isinstance(spotlight.get("story"), dict) else {}
    spotlight_story_cards = "".join(
        f"<div><span>{html.escape(label)}</span><p>{html.escape(str(value))}</p></div>"
        for label, value in [
            ("Insight", spotlight_story.get("insight") or ""),
            ("Struggle", spotlight_story.get("struggle") or ""),
            ("Feature", spotlight_story.get("features") or ""),
            ("Progress", spotlight_story.get("progress") or ""),
        ]
        if value
    )
    spotlight_html = ""
    if spotlight:
        spotlight_html = f"""
      <section>
        <h2>Spotlight sessions & projects</h2>
        <p class="receipt-note">Builder-selected anchors that turn the proof card into a specific story. TokenBar treats these as labels only; it does not upload raw transcripts, source code, private diffs, or secrets.</p>
        <div class="spotlight-grid">{spotlight_anchor_cards}</div>
        <div class="spotlight-beats">{spotlight_story_cards}</div>
        <div class="spotlight-beats">{spotlight_beat_cards}</div>
      </section>
        """
    share_receipt_cards = "".join(
        f"<div><span>{html.escape(label)}</span><strong>{html.escape(value)}</strong></div>"
        for label, value in [
            ("Share schema", str(share_receipt.get("schema") or "tokenbar.share_receipt.v1")),
            ("Share mode", str(share_receipt.get("shareMode") or share_mode)),
            ("Public material", str(share_receipt.get("publicMaterial") or "")),
            ("Redacted fields", ", ".join(str(item) for item in (share_receipt.get("redactedFields") if isinstance(share_receipt.get("redactedFields"), list) else [])) or "none"),
        ]
    )
    share_receipt_never = "".join(
        f"<li>{html.escape(str(item))}</li>"
        for item in (share_receipt.get("neverPublic") if isinstance(share_receipt.get("neverPublic"), list) else [])
    )
    next_plan = proof.get("nextActionPlan") if isinstance(proof.get("nextActionPlan"), dict) else build_next_action_plan(proof)
    next_actions = "".join(
        (
            "<div>"
            f"<span>{html.escape(str(item.get('label') or item.get('key') or 'Next action'))}</span>"
            f"<code>{html.escape(str(item.get('command') or 'tokenbar claim'))}</code>"
            f"<p>{html.escape(str(item.get('why') or 'Run the next safe builder loop.'))}</p>"
            f"<em>{html.escape(str(item.get('evidenceNeeded') or 'Reloadable proof evidence.'))}</em>"
            "</div>"
        )
        for item in (next_plan.get("actions") if isinstance(next_plan.get("actions"), list) else [])
        if isinstance(item, dict)
    )
    feedback_url = "/api/report-feedback"
    feedback_payload = json.dumps(
        {
            "token": str(proof.get("token") or ""),
            "category": "correction",
            "reportUrl": str(proof.get("proofCardUrl") or proof.get("profileUrl") or ""),
            "message": "Explain what is wrong without pasting raw transcripts, source code, secrets, private diffs, or env files.",
        },
        sort_keys=True,
    )
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{html.escape(str(proof.get("title") or "TokenBar Proof Card"))}</title>
  <style>
    :root {{ color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    body {{ margin: 0; background: #f6f8fb; color: #08111f; }}
    main {{ min-height: 100vh; display: grid; place-items: center; padding: 40px 20px; }}
    article {{ width: min(920px, 100%); background: #fff; border: 1px solid #dfe7f1; border-radius: 28px; overflow: hidden; box-shadow: 0 24px 70px rgba(15, 31, 55, .14); }}
    header {{ padding: 42px; background: #0b1220; color: white; }}
    .eyebrow {{ color: #86b6ff; text-transform: uppercase; letter-spacing: .12em; font-weight: 800; font-size: 13px; }}
    h1 {{ margin: 12px 0 10px; font-size: clamp(42px, 8vw, 82px); line-height: .9; letter-spacing: -.04em; }}
    p {{ color: #5f6b7a; font-size: 17px; line-height: 1.55; }}
    header p {{ color: #ccd7e5; max-width: 760px; }}
    ul {{ list-style: none; padding: 26px 42px 40px; margin: 0; display: grid; gap: 14px; }}
    li {{ border: 1px solid #e5ecf5; border-radius: 18px; padding: 18px; background: linear-gradient(135deg, #fff, #f8fbff); }}
    li span {{ display: block; color: #2c7be5; font-weight: 800; font-size: 13px; text-transform: uppercase; letter-spacing: .08em; }}
    li strong {{ display: block; margin-top: 4px; font-size: 26px; letter-spacing: -.02em; }}
    li p {{ margin: 6px 0 0; }}
    footer {{ padding: 0 42px 42px; display: flex; gap: 14px; flex-wrap: wrap; align-items: center; }}
    a {{ color: #0b1220; font-weight: 800; }}
    code {{ background: #eef4ff; padding: 5px 8px; border-radius: 8px; }}
    section {{ padding: 0 42px 36px; }}
    h2 {{ margin: 0 0 12px; font-size: 30px; letter-spacing: -.02em; }}
    .story {{ padding-top: 34px; border-top: 1px solid #e5ecf5; }}
    .story p {{ margin-top: 0; }}
    .axes {{ grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); padding: 0; }}
    .axes li strong {{ font-size: 34px; }}
    .axes li em {{ display: block; margin-top: 8px; color: #6c7787; font-style: normal; font-weight: 700; }}
    .plain-list {{ padding: 0 0 0 18px; list-style: disc; }}
    .plain-list li {{ border: 0; padding: 3px 0; background: transparent; }}
    .privacy-strip {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; padding: 24px 42px 0; }}
    .privacy-strip div {{ border: 1px solid #dfe7f1; border-radius: 16px; padding: 14px; background: #f8fbff; }}
    .privacy-strip span {{ display: block; color: #637084; font-size: 12px; font-weight: 900; text-transform: uppercase; letter-spacing: .08em; }}
    .privacy-strip strong {{ display: block; margin-top: 5px; font-size: 17px; }}
    .rank-context {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:12px; padding:24px 42px 0; }}
    .rank-context div {{ border:1px solid #bfdbfe; border-radius:18px; padding:16px; background:linear-gradient(135deg,#eff6ff,#ffffff); }}
    .rank-context span {{ display:block; color:#2563eb; font-size:12px; font-weight:950; letter-spacing:.08em; text-transform:uppercase; }}
    .rank-context strong {{ display:block; margin-top:5px; color:#08111f; font-size:30px; line-height:1; }}
    .rank-context small {{ color:#64748b; font-size:13px; }}
    .rank-context p {{ margin:8px 0 0; font-size:13px; font-weight:850; }}
    .next {{ border: 1px solid #cfe0ff; border-radius: 18px; padding: 18px; background: #f2f7ff; }}
    .share-copy {{ border: 1px solid #dfe7f1; border-radius: 18px; padding: 18px; background: #fbfcff; }}
    .share-copy p {{ margin: 0; color: #0b1220; font-weight: 750; }}
    .receipt-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin-top: 14px; }}
    .receipt-grid div {{ border: 1px solid #dfe7f1; border-radius: 16px; padding: 14px; background: #fff; }}
    .receipt-grid span {{ display: block; color: #637084; font-size: 12px; font-weight: 900; text-transform: uppercase; letter-spacing: .08em; }}
    .receipt-grid strong {{ display: block; margin-top: 6px; font-size: 16px; line-height: 1.25; }}
    .receipt-note {{ color: #5f6b7a; font-size: 15px; }}
    .shipped-work {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(190px, 1fr)); gap: 12px; }}
    .shipped-work div {{ border: 1px solid #dfe7f1; border-radius: 18px; padding: 16px; background: linear-gradient(135deg, #ffffff, #f7fbff); }}
    .shipped-work span {{ display: block; color: #2c7be5; font-size: 12px; font-weight: 900; text-transform: uppercase; letter-spacing: .08em; }}
    .shipped-work strong {{ display: block; margin-top: 7px; color: #0b1220; font-size: 20px; line-height: 1.15; }}
    .shipped-work p {{ margin: 7px 0 0; font-size: 14px; }}
    .shipped-work em {{ display: block; margin-top: 8px; color: #748094; font-style: normal; font-size: 11px; font-weight: 800; text-transform: uppercase; letter-spacing: .05em; }}
    .reference-radar {{ display:grid; grid-template-columns:1.1fr 1fr 1fr; gap:12px; }}
    .reference-radar div {{ border:1px solid #cfe0ff; border-radius:18px; padding:18px; background:radial-gradient(circle at 20% 0%, #dbeafe, transparent 42%), linear-gradient(135deg,#fff,#f7fbff); }}
    .reference-radar span {{ display:block; color:#2563eb; font-size:12px; font-weight:950; text-transform:uppercase; letter-spacing:.08em; }}
    .reference-radar strong {{ display:block; margin-top:8px; color:#0b1220; font-size:28px; line-height:1; }}
    .reference-radar p {{ margin:10px 0 0; font-size:14px; }}
    .reference-chips {{ display:flex; flex-wrap:wrap; gap:8px; margin-top:12px; }}
    .reference-chips span {{ display:inline-flex; gap:8px; align-items:center; border:1px solid #d8e5ff; border-radius:999px; padding:8px 10px; background:#fff; color:#0f172a; font-size:12px; font-weight:900; }}
    .reference-chips small {{ color:#64748b; font-size:11px; font-weight:950; }}
    .spotlight-grid, .spotlight-beats {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(190px,1fr)); gap:12px; margin-top:14px; }}
    .spotlight-grid div, .spotlight-beats div {{ border:1px solid #d8e5ff; border-radius:18px; padding:16px; background:linear-gradient(135deg,#ffffff,#f7fbff); }}
    .spotlight-grid span, .spotlight-beats span {{ display:block; color:#2563eb; font-size:12px; font-weight:950; letter-spacing:.08em; text-transform:uppercase; }}
    .spotlight-grid strong {{ display:block; margin-top:7px; color:#0b1220; font-size:19px; line-height:1.15; overflow-wrap:anywhere; }}
    .spotlight-grid p, .spotlight-beats p {{ margin:8px 0 0; font-size:14px; }}
    .next-action-plan {{ display:grid; grid-template-columns:repeat(3,1fr); gap:12px; padding:0 42px 42px; }}
    .next-action-plan div {{ border:1px solid #bcd4ff; border-radius:18px; padding:18px; background:linear-gradient(135deg,#f8fbff,#ffffff); }}
    .next-action-plan span {{ display:block; color:#2563eb; font-size:12px; font-weight:900; text-transform:uppercase; letter-spacing:.08em; }}
    .next-action-plan code {{ display:block; margin-top:10px; padding:10px 12px; border:1px solid #d8e5ff; border-radius:12px; background:#fff; color:#0f172a; font-weight:850; overflow-wrap:anywhere; }}
    .next-action-plan p {{ margin:10px 0 0; font-size:14px; }}
    .next-action-plan em {{ display:block; margin-top:10px; color:#64748b; font-size:12px; font-style:normal; font-weight:800; line-height:1.4; }}
    .correction-box {{ border:1px solid #fed7aa; border-radius:18px; padding:18px; background:#fff7ed; }}
    .correction-box code {{ display:block; margin-top:10px; padding:12px; border:1px solid #fdba74; background:#fff; overflow-wrap:anywhere; }}
    @media (max-width: 760px) {{ header, section, footer {{ padding-left: 22px; padding-right: 22px; }} ul {{ padding-left: 22px; padding-right: 22px; }} .privacy-strip, .reference-radar {{ grid-template-columns: 1fr; padding-left: 22px; padding-right: 22px; }} }}
  </style>
</head>
<body>
  <main>
    <article>
      <header>
        <div class="eyebrow">TokenBar proof card</div>
        <h1>{html.escape(str(proof.get("title") or "Builder Identity"))}</h1>
        <p>{html.escape(str(proof.get("verdict") or ""))}</p>
      </header>
      <div class="privacy-strip">{privacy_cards}</div>
      {f'<div class="rank-context" aria-label="Public rank context">{rank_cards}</div>' if rank_cards else ''}
      <ul>{facts}</ul>
      <section class="story">
        <h2>{html.escape(str(story.get("headline") or "Builder story"))}</h2>
        <p>{html.escape(str(story.get("summary") or ""))}</p>
        <ul class="axes">{axes}</ul>
      </section>
      <section>
        <h2>Compared to yourself over time</h2>
        <p>{comparison_basis}</p>
        <ul>{comparison_cards}</ul>
        <div class="next"><p>{comparison_uncertainty}</p></div>
      </section>
      <section>
        <h2>What this proves</h2>
        <ul class="plain-list">{proved}</ul>
      </section>
      <section>
        <h2>Shipped-work receipt</h2>
        <p class="receipt-note">A compact trail of the safe work evidence behind this proof card. Counts can be redacted by the builder; provenance remains visible.</p>
        <div class="shipped-work">{shipped_work}</div>
      </section>
      {spotlight_html}
      {reference_radar_html}
      <section>
        <h2>What remains uncertain</h2>
        <ul class="plain-list">{uncertainties}</ul>
      </section>
      <section>
        <h2>Safe evidence receipt</h2>
        <p class="receipt-note">{html.escape(str(safe_receipt.get("summary") or "Safe aggregate evidence only."))} Public material: {html.escape(str(safe_receipt.get("publicMaterial") or ""))}</p>
        <h3>Used evidence</h3>
        <ul class="plain-list">{safe_used}</ul>
        <h3>Never used</h3>
        <ul class="plain-list">{safe_never_used}</ul>
        <h3>Share surfaces</h3>
        <ul>{safe_surfaces}</ul>
      </section>
      <section>
        <h2>Verification receipt</h2>
        <p class="receipt-note">This receipt proves the proof card was generated from safe aggregate identity data. It does not include raw transcripts, source code, private diffs, or credentials.</p>
        <div class="receipt-grid">{receipt_cards}</div>
        <p class="receipt-note">Completed stages: {html.escape(completed_stages or "not available")}</p>
        <ul class="plain-list">{not_included}</ul>
      </section>
      <section>
        <h2>Act next</h2>
        <p class="receipt-note">Focus: {html.escape(str(next_plan.get("focus") or "run one safe builder loop"))}. Confidence: {html.escape(str(next_plan.get("confidence") or "medium"))}. These actions do not require raw transcripts or source code to become public.</p>
      </section>
      <div class="next-action-plan">{next_actions}</div>
      <section>
        <h2>Next frontier</h2>
        <div class="next"><p>{html.escape(next_frontier)}</p></div>
      </section>
      <section>
        <h2>Share receipt</h2>
        <p class="receipt-note">{html.escape(str(share_receipt.get("copySafeSummary") or "This proof is safe to share."))}</p>
        <div class="receipt-grid">{share_receipt_cards}</div>
        <h3>Never public</h3>
        <ul class="plain-list">{share_receipt_never}</ul>
      </section>
      <section>
        <h2>Share copy</h2>
        <div class="share-copy"><p>{html.escape(share_copy)}</p></div>
      </section>
      <section>
        <h2>Report or correct this profile</h2>
        <div class="correction-box">
          <p class="receipt-note">If this identity feels wrong, submit a correction with the token and a human explanation. Do not paste raw transcripts, source code, credentials, private diffs, or environment files.</p>
          <code>POST {html.escape(feedback_url)} {html.escape(feedback_payload)}</code>
        </div>
      </section>
      <footer>
        <span>Share token: <code>{html.escape(str(proof.get("token") or ""))}</code></span>
        <a href="{html.escape(str(proof.get("profileUrl") or "#"))}">Open public profile</a>
      </footer>
    </article>
  </main>
</body>
</html>"""


def handler(request: BaseHTTPRequestHandler) -> None:
    parsed = urlparse(request.path)
    query = parse_qs(parsed.query)

    if request.command == "OPTIONS":
        respond_json(request, 204, {})
        return

    if request.command == "GET":
        if (query.get("health") or [""])[0] in {"1", "true", "yes"}:
            respond_json(request, 200, {"ok": True, "health": storage_health()})
            return
        try:
            store = read_store()
        except Exception as exc:
            respond_json(request, 503, {"ok": False, "error": str(exc), "health": storage_health()})
            return
        run_id = (query.get("run") or [""])[0]
        token = (query.get("token") or [""])[0]
        if run_id:
            run = (store.get("runs") or {}).get(run_id)
            if not run:
                respond_json(request, 404, {"ok": False, "error": "run not found"})
                return
            respond_json(request, 200, {"ok": True, "run": run})
            return
        if token:
            proof = (store.get("proofCards") or {}).get(token)
            if not proof:
                respond_json(request, 404, {"ok": False, "error": "proof card not found"})
                return
            if proof_is_private(proof):
                receipt = proof.get("verificationReceipt") if isinstance(proof.get("verificationReceipt"), dict) else {}
                respond_json(
                    request,
                    403,
                    {
                        "ok": False,
                        "error": "private proof is not token-addressable; reload the action by run id instead",
                        "runId": receipt.get("runId"),
                    },
                )
                return
            action_feed = aggregate_action_feed(store, public_base(request))
            enriched = next(
                (
                    item
                    for item in (action_feed.get("feed") or [])
                    if isinstance(item, dict) and item.get("token") == token
                ),
                None,
            )
            proof_for_response = dict(proof)
            if enriched:
                proof_for_response["rankBadges"] = enriched.get("rankBadges") or []
                proof_for_response["rankPlacements"] = enriched.get("rankPlacements") or {}
            if not isinstance(proof_for_response.get("shareReceipt"), dict):
                receipt = proof_for_response.get("verificationReceipt") if isinstance(proof_for_response.get("verificationReceipt"), dict) else {}
                proof_for_response["shareReceipt"] = build_share_receipt(proof_for_response, str(receipt.get("runId") or ""))
            accept = request.headers.get("Accept", "")
            if "text/html" in accept and "application/json" not in accept:
                view = (query.get("view") or [""])[0].strip().lower()
                if view == "trailer":
                    respond_html(request, 200, identity_trailer_html(proof_for_response))
                else:
                    respond_html(request, 200, proof_card_html(proof_for_response))
            else:
                respond_json(request, 200, {"ok": True, "proof": proof_for_response})
            return
        runs = [
            run
            for run in (store.get("runs") or {}).values()
            if isinstance(run, dict) and proof_is_publicly_listed(run.get("proof") if isinstance(run.get("proof"), dict) else {})
        ]
        runs.sort(key=lambda item: item.get("createdAt", 0), reverse=True)
        action_feed = aggregate_action_feed(store, public_base(request))
        respond_json(request, 200, {"ok": True, "action": ACTION_NAME, "runs": runs[:20], **action_feed})
        return

    if request.command != "POST":
        respond_json(request, 405, {"ok": False, "error": "method not allowed"})
        return

    try:
        length = int(request.headers.get("content-length") or "0")
    except ValueError:
        length = 0
    if length <= 0 or length > MAX_BODY_BYTES:
        respond_json(request, 413, {"ok": False, "error": "payload must be 1-256KB"})
        return

    try:
        body = json.loads(request.rfile.read(length).decode("utf-8"))
        if not isinstance(body, dict):
            raise ValueError("expected JSON object")
        owner_id = _request_owner_id(request)
        identity = body.get("identity") if isinstance(body.get("identity"), dict) else body
        action = str(body.get("action") or ACTION_NAME)
        if action != ACTION_NAME:
            raise ValueError(f"unsupported action: {action}")
        run = create_action_run(
            identity,
            public_base(request),
            str(body.get("idempotencyKey") or ""),
            body.get("shareControls"),
            owner_id=owner_id,
        )
        storage = save_action_run(run)
        respond_json(request, 201, {"ok": True, "runId": run["runId"], "status": run["status"], "storage": storage, "stages": run["stages"], "result": run["result"], "proof": run["proof"]})
    except Exception as exc:
        respond_json(request, 400, {"ok": False, "error": str(exc)})
