from __future__ import annotations

import html
import json
import math
import os
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler
from pathlib import Path
from urllib.parse import parse_qs, quote, urlparse


STORE_PATH = Path(os.environ.get("TOKENBAR_PROFILE_STORE_PATH", "/tmp/tokenbar-profile-store.json"))
ACTION_STORE_PATH = Path(os.environ.get("TOKENBAR_ACTION_STORE_PATH", "/tmp/tokenbar-action-store.json"))
MAX_BODY_BYTES = 256_000


def read_store() -> dict:
    try:
        return json.loads(STORE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {"profiles": {}}


def write_store(store: dict) -> None:
    STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = STORE_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(store, indent=2, sort_keys=True), encoding="utf-8")
    tmp.replace(STORE_PATH)


def read_action_store() -> dict:
    try:
        data = json.loads(ACTION_STORE_PATH.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {"proofCards": {}}
    except Exception:
        return {"proofCards": {}}


def write_action_store(store: dict) -> None:
    ACTION_STORE_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = ACTION_STORE_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(store, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(ACTION_STORE_PATH)


def supabase_config() -> tuple[str, str] | None:
    url = (os.environ.get("SUPABASE_URL") or "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if not url or not key:
        return None
    return url, key


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


def supabase_action_store_enabled() -> bool:
    return bool(supabase_config()) and os.environ.get("TOKENBAR_ACTION_STORE") == "supabase"


def get_action_proof_card(token: str) -> dict | None:
    if supabase_action_store_enabled():
        try:
            rows = supabase_request(
                f"tokenbar_action_runs?token=eq.{quote(token)}&select=proof&order=created_at_epoch.desc&limit=1"
            )
            if isinstance(rows, list) and rows:
                proof = rows[0].get("proof")
                return proof if isinstance(proof, dict) else None
        except Exception:
            return None

    proof = (read_action_store().get("proofCards") or {}).get(token)
    return proof if isinstance(proof, dict) else None


def profile_to_row(profile: dict) -> dict:
    return {
        "token": profile["token"],
        "profile": profile,
        "primary_archetype": profile.get("primaryArchetype"),
        "npc_class": profile.get("npcClass"),
        "specificity_score": profile.get("specificityScore"),
        "uploaded_at_epoch": profile.get("uploadedAt"),
    }


def read_profiles() -> tuple[dict[str, dict], str]:
    if supabase_config():
        rows = supabase_request(
            "tokenbar_profiles?select=token,profile&order=uploaded_at_epoch.desc&limit=1000"
        )
        profiles = {
            str(row.get("token")): row.get("profile")
            for row in (rows or [])
            if isinstance(row, dict) and isinstance(row.get("profile"), dict)
        }
        return profiles, "supabase-postgres"

    store = read_store()
    return dict(store.get("profiles") or {}), "ephemeral-json-file"


def get_profile(token: str) -> tuple[dict | None, str]:
    if supabase_config():
        rows = supabase_request(
            f"tokenbar_profiles?token=eq.{quote(token)}&select=profile&limit=1"
        )
        if isinstance(rows, list) and rows:
            profile = rows[0].get("profile")
            return profile if isinstance(profile, dict) else None, "supabase-postgres"
        return None, "supabase-postgres"

    store = read_store()
    return (store.get("profiles") or {}).get(token), "ephemeral-json-file"


def save_profile(profile: dict) -> str:
    if supabase_config():
        supabase_request(
            "tokenbar_profiles?on_conflict=token",
            method="POST",
            body=profile_to_row(profile),
        )
        return "supabase-postgres"

    store = read_store()
    store.setdefault("profiles", {})[profile["token"]] = profile
    write_store(store)
    return "ephemeral-json-file"


def apply_submission_to_profile(profile: dict, submission: dict, visibility: str = "") -> dict:
    updated = dict(profile)
    updated["hackathonSubmission"] = submission
    updated["submittedProject"] = submission
    updated["projectTitle"] = submission.get("projectTitle")
    updated["event"] = submission.get("event")
    updated["track"] = submission.get("track")
    updated["repoUrl"] = submission.get("repoUrl")
    updated["demoUrl"] = submission.get("demoUrl")
    if visibility in {"public", "listed", "unlisted", "private"}:
        public_profile = updated.get("publicProfile") if isinstance(updated.get("publicProfile"), dict) else {}
        public_profile = dict(public_profile)
        public_profile["visibility"] = visibility
        updated["publicProfile"] = public_profile
    return updated


def apply_submission_to_proof(proof: dict, submission: dict, visibility: str = "") -> dict:
    updated = dict(proof)
    updated["hackathonSubmission"] = submission
    updated["submittedProject"] = submission
    updated["projectTitle"] = submission.get("projectTitle")
    updated["event"] = submission.get("event")
    updated["track"] = submission.get("track")
    updated["repoUrl"] = submission.get("repoUrl")
    updated["demoUrl"] = submission.get("demoUrl")
    if visibility in {"public", "listed", "unlisted", "private"}:
        updated["publicVisibility"] = "public" if visibility == "listed" else visibility
        privacy = updated.get("privacy") if isinstance(updated.get("privacy"), dict) else {}
        privacy = dict(privacy)
        privacy["shareMode"] = "public" if visibility == "listed" else visibility
        updated["privacy"] = privacy
        share_controls = updated.get("shareControls") if isinstance(updated.get("shareControls"), dict) else {}
        share_controls = dict(share_controls)
        share_controls["visibility"] = "public" if visibility == "listed" else visibility
        updated["shareControls"] = share_controls
    return updated


def update_action_submission(token: str, submission: dict, visibility: str = "") -> bool:
    changed = False
    if supabase_action_store_enabled():
        try:
            rows = supabase_request(
                f"tokenbar_action_runs?token=eq.{quote(token)}&select=run_id,run,proof"
            )
            for row in rows or []:
                if not isinstance(row, dict) or not row.get("run_id"):
                    continue
                proof = row.get("proof") if isinstance(row.get("proof"), dict) else {}
                run = row.get("run") if isinstance(row.get("run"), dict) else {}
                proof = apply_submission_to_proof(proof, submission, visibility)
                if isinstance(run.get("proof"), dict):
                    run["proof"] = apply_submission_to_proof(run["proof"], submission, visibility)
                supabase_request(
                    f"tokenbar_action_runs?run_id=eq.{quote(str(row.get('run_id')))}",
                    method="PATCH",
                    body={"run": run, "proof": proof},
                )
                changed = True
        except Exception:
            return changed
        return changed

    store = read_action_store()
    proof_cards = store.setdefault("proofCards", {})
    if isinstance(proof_cards.get(token), dict):
        proof_cards[token] = apply_submission_to_proof(proof_cards[token], submission, visibility)
        changed = True
    for run in (store.get("runs") or {}).values():
        if not isinstance(run, dict) or not isinstance(run.get("proof"), dict):
            continue
        if str(run["proof"].get("token") or "") != token:
            continue
        run["proof"] = apply_submission_to_proof(run["proof"], submission, visibility)
        changed = True
    if changed:
        write_action_store(store)
    return changed


def build_surface_bundle(
    token: str,
    proof_url: str = "",
    profile_url: str = "",
    social_url: str = "",
    rankings_url: str = "",
    loop_rankings_url: str = "",
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

    def number(value: object) -> int:
        try:
            return int(float(value or 0))
        except Exception:
            return 0

    def ranked(items: object) -> list[dict]:
        rows = []
        if not isinstance(items, list):
            return rows
        for item in items[:8]:
            if not isinstance(item, dict):
                continue
            name = str(item.get("name") or "").strip()
            if not name:
                continue
            rows.append({"name": name.replace("https://", "").replace("http://", "")[:80], "count": number(item.get("count"))})
        return rows

    signal_count = number(raw.get("signalCount"))
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


def enrich_proof_rank_context(token: str, proof: dict) -> dict:
    enriched_proof = dict(proof)
    try:
        from api.actions import aggregate_action_feed, read_store as read_action_store_for_feed

        feed = aggregate_action_feed(read_action_store_for_feed())
        for item in feed.get("feed") or []:
            if isinstance(item, dict) and str(item.get("token") or "") == token:
                enriched_proof["rankBadges"] = item.get("rankBadges") or []
                enriched_proof["rankPlacements"] = item.get("rankPlacements") or {}
                break
    except Exception:
        enriched_proof.setdefault("rankBadges", [])
        enriched_proof.setdefault("rankPlacements", {})
    return enriched_proof


def proof_card_to_profile(proof: dict) -> dict:
    story = proof.get("builderStory") if isinstance(proof.get("builderStory"), dict) else {}
    axes = story.get("axes") if isinstance(story.get("axes"), list) else []
    dimensions = [
        {
            "name": axis.get("label") or axis.get("key") or "Builder signal",
            "score": axis.get("score") or 0,
            "description": axis.get("claim") or "",
        }
        for axis in axes
        if isinstance(axis, dict)
    ]
    proof_score = proof.get("proofScore") or proof.get("specificityScore") or 0
    loop_maturity = proof.get("loopMaturity") or proof_score
    archetype = proof.get("primaryArchetype") or "Builder"
    npc_class = proof.get("npcClass") or "proof card"
    token = proof.get("token")
    proof_url = proof.get("proofCardUrl") or ""
    profile_url = proof.get("profileUrl") or ""
    social_url = proof.get("socialUrl") or ""
    rankings_url = proof.get("rankingsUrl") or ""
    loop_rankings_url = proof.get("loopRankingsUrl") or ""
    privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
    share_controls = proof.get("shareControls") if isinstance(proof.get("shareControls"), dict) else {}
    redactions = privacy.get("redactions") if isinstance(privacy.get("redactions"), dict) else share_controls.get("redactions") if isinstance(share_controls.get("redactions"), dict) else {}
    visibility = str(proof.get("publicVisibility") or privacy.get("shareMode") or share_controls.get("visibility") or "public").lower()
    owner_profile = clean_public_profile(proof.get("ownerProfile"), fallback_name=str(proof.get("title") or archetype or "builder"))
    submission = clean_submission_metadata(
        proof.get("hackathonSubmission") or proof.get("submittedProject"),
        fallback_title=str(proof.get("title") or archetype or "builder"),
    )
    surface_bundle = build_surface_bundle(
        token=token,
        proof_url=proof_url,
        profile_url=profile_url,
        social_url=social_url,
        rankings_url=rankings_url,
        loop_rankings_url=loop_rankings_url,
        visibility=visibility,
        share_copy=proof.get("shareCopy") or "",
    )
    builder_signals = clean_builder_signal_summary(proof.get("builderSignalInbox") or proof.get("socialLearningSignals"))
    return {
        "schema": "tokenbar.identity.v1",
        "token": token,
        "title": proof.get("title") or "TokenBar Builder Profile",
        "subtitle": story.get("summary") or proof.get("verdict") or "Safe proof card generated from local TokenBar analysis.",
        "primaryArchetype": archetype,
        "npcClass": npc_class,
        "specificityScore": proof.get("specificityScore") or proof_score,
        "proofScore": proof_score,
        "loopMaturity": loop_maturity,
        "loopScore": loop_maturity,
        "growthEdge": story.get("nextFrontier") or "",
        "reportKind": "tokenbar.action-proof-fallback",
        "uploadedAt": proof.get("createdAt") or int(time.time()),
        "source": "tokenbar-action-proof-card",
        "privacy": {
            "rawTranscriptsIncluded": False,
            "sourceCodeIncluded": False,
            "uploadedArtifact": privacy.get("uploadedArtifact") or "generated proof card only",
            "shareMode": visibility,
            "redactions": redactions,
        },
        "usage": {
            "totalTokens": proof.get("totalTokens") or 0,
            "sessionCount": proof.get("sessionCount") or 0,
            "tokenCountHidden": bool(proof.get("tokenCountHidden")),
            "sessionCountHidden": bool(proof.get("sessionCountHidden")),
        },
        "identityLabel": {
            "bucketKey": f"{archetype}/{npc_class}".lower().replace(" ", "-"),
            "summary": story.get("headline") or proof.get("verdict") or "",
        },
        "labelRationale": {
            "summary": "This public profile is backed by a persisted TokenBar proof-card action, not raw local transcripts.",
            "topTraitDrivers": [
                {"trait": item.get("label"), "score": item.get("score")}
                for item in axes[:6]
                if isinstance(item, dict)
            ],
        },
        "archetypeDistribution": [
            {
                "name": archetype,
                "probability": max(1, min(100, round(float(proof_score or 0), 1))),
                "npcClass": npc_class,
            }
        ],
        "labelDistribution": [
            {
                "title": proof.get("title") or archetype,
                "probability": max(1, min(100, round(float(proof_score or 0), 1))),
                "npcClass": npc_class,
            }
        ],
        "dimensions": dimensions,
        "loopScale": [
            {
                "name": "Loop maturity",
                "score": loop_maturity,
                "evidence": "Persisted action run completed request, validation, proof build, persistence, and reload stages.",
            }
        ],
        "publicProfile": {
            "visibility": visibility,
            "handle": owner_profile.get("handle"),
            "nickname": owner_profile.get("nickname") or proof.get("title") or archetype,
            "region": owner_profile.get("region") or "Global",
            "bio": owner_profile.get("bio") or story.get("summary") or proof.get("verdict") or "",
            "links": owner_profile.get("links") or {},
            "ownerRedacted": bool(owner_profile.get("ownerRedacted")),
            "rawLogsShared": False,
            "sourceCodeShared": False,
        },
        "hackathonSubmission": submission,
        "submittedProject": submission,
        "leaderboard": {
            "score": proof_score,
            "tokenCount": proof.get("totalTokens") or 0,
            "region": owner_profile.get("region") or "Global",
        },
        "profileActivation": {
            "localPdfCommand": "tokenbar claim --pdf",
            "shareLatestCommand": "tokenbar publish-proof",
        },
        "shareCopy": proof.get("shareCopy") or "",
        "shareControls": {
            "visibility": visibility,
            "redactions": redactions,
        },
        "socialUrl": social_url,
        "rankingsUrl": rankings_url,
        "loopRankingsUrl": loop_rankings_url,
        "actionLinks": {
            "proofCardUrl": proof_url,
            "profileUrl": profile_url,
            "socialUrl": social_url,
            "rankingsUrl": rankings_url,
            "loopRankingsUrl": loop_rankings_url,
        },
        "surfaceBundle": surface_bundle,
        "builderSignalInbox": builder_signals,
        "socialLearningSignals": builder_signals,
        "rankBadges": proof.get("rankBadges") if isinstance(proof.get("rankBadges"), list) else [],
        "rankPlacements": proof.get("rankPlacements") if isinstance(proof.get("rankPlacements"), dict) else {},
        "builderStory": story,
        "shippedWork": story.get("shippedWork") if isinstance(story.get("shippedWork"), list) else [],
        "selfComparison": proof.get("selfComparison") if isinstance(proof.get("selfComparison"), dict) else {},
        "nextActionPlan": proof.get("nextActionPlan") if isinstance(proof.get("nextActionPlan"), dict) else {},
        "verificationReceipt": proof.get("verificationReceipt") if isinstance(proof.get("verificationReceipt"), dict) else {},
        "safeEvidenceReceipt": proof.get("safeEvidenceReceipt") if isinstance(proof.get("safeEvidenceReceipt"), dict) else {},
        "shareReceipt": proof.get("shareReceipt") if isinstance(proof.get("shareReceipt"), dict) else {},
        "proofFacts": proof.get("facts") if isinstance(proof.get("facts"), list) else [],
    }


def get_action_profile(token: str) -> dict | None:
    proof = get_action_proof_card(token)
    if not isinstance(proof, dict):
        return None
    privacy = proof.get("privacy") if isinstance(proof.get("privacy"), dict) else {}
    share_controls = proof.get("shareControls") if isinstance(proof.get("shareControls"), dict) else {}
    visibility = str(proof.get("publicVisibility") or privacy.get("shareMode") or share_controls.get("visibility") or "public").lower()
    if visibility == "private":
        return None
    if privacy.get("rawTranscriptsIncluded") or privacy.get("sourceCodeIncluded"):
        return None
    return proof_card_to_profile(enrich_proof_rank_context(token, proof))


def storage_health() -> dict:
    has_supabase_url = bool((os.environ.get("SUPABASE_URL") or "").strip())
    has_service_key = bool((os.environ.get("SUPABASE_SERVICE_ROLE_KEY") or "").strip())
    configured = has_supabase_url and has_service_key
    action_store_requested = os.environ.get("TOKENBAR_ACTION_STORE") == "supabase"
    action_store_enabled = configured and action_store_requested

    result = {
        "storage": "supabase-postgres" if configured else "ephemeral-json-file",
        "durable": configured,
        "supabaseUrlConfigured": has_supabase_url,
        "supabaseServiceRoleKeyConfigured": has_service_key,
        "actionProofFallbackStorage": "supabase-postgres" if action_store_enabled else "ephemeral-json-file",
        "actionProofFallbackDurable": action_store_enabled,
        "actionStoreRequested": action_store_requested,
        "publicBaseUrlConfigured": bool((os.environ.get("TOKENBAR_PUBLIC_BASE_URL") or "").strip()),
        "maxProfilePayloadBytes": MAX_BODY_BYTES,
        "uploadBoundary": "opt-in tokenbar.identity.v1 JSON only; no source code or raw transcripts",
        "table": "tokenbar_profiles",
        "setupSql": "docs/tokenbar_profiles_supabase.sql",
        "actionProofSetupSql": "docs/tokenbar_actions_supabase.sql",
    }

    if configured:
        try:
            supabase_request("tokenbar_profiles?select=token&limit=1")
            result["reachable"] = True
            result["status"] = "durable profile storage ready"
        except Exception as exc:
            result["reachable"] = False
            result["status"] = "supabase configured but table/query failed"
            result["error"] = str(exc)
    else:
        result["reachable"] = True
        result["status"] = "using local ephemeral fallback"
    if action_store_requested and not action_store_enabled:
        result["actionProofFallbackStatus"] = "supabase action fallback requested but SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY is missing"
    elif action_store_enabled:
        result["actionProofFallbackStatus"] = "profile fallback can read tokenbar_action_runs"
    else:
        result["actionProofFallbackStatus"] = "profile fallback reads local action store"
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


def clean_public_profile(value: object, fallback_name: str = "builder") -> dict:
    raw = value if isinstance(value, dict) else {}
    links_raw = raw.get("links") if isinstance(raw.get("links"), dict) else {}
    links = {}
    for key in ("github", "linkedin", "website", "x"):
        url = clean_public_url(links_raw.get(key))
        if url:
            links[key] = url
    nickname = "".join(ch for ch in str(raw.get("nickname") or raw.get("handle") or fallback_name) if ch.isalnum() or ch in ("_", "-", ".", " "))[:64].strip()
    handle = "".join(ch for ch in str(raw.get("handle") or nickname or fallback_name) if ch.isalnum() or ch in ("_", "-", "."))[:48].strip(".-_")
    region = "".join(ch for ch in str(raw.get("region") or "Global") if ch.isalnum() or ch in (",", " ", ".", "_", "-"))[:80].strip() or "Global"
    visibility = str(raw.get("visibility") or "public").lower()
    if visibility not in {"public", "listed", "unlisted", "private"}:
        visibility = "public"
    return {
        "handle": handle or "builder",
        "nickname": nickname or handle or "builder",
        "region": region,
        "visibility": visibility,
        "bio": str(raw.get("bio") or "").replace("\x00", "").strip()[:220],
        "links": links,
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

    repo_url = clean_public_url(raw.get("repoUrl") or raw.get("repositoryUrl"))
    demo_url = clean_public_url(raw.get("demoUrl") or raw.get("websiteUrl") or raw.get("productUrl"))
    project_title = text("projectTitle", fallback_title or "Untitled project", 120) or "Untitled project"
    event = text("event", "Independent build", 100) or "Independent build"
    track = text("track", "Builder identity", 80) or "Builder identity"
    tagline = text("tagline", "", 220)
    submitted_at = text("submittedAt", "", 64)

    return {
        "schema": "tokenbar.hackathon_submission.v1",
        "event": event,
        "projectTitle": project_title,
        "tagline": tagline,
        "track": track,
        "repoUrl": repo_url,
        "demoUrl": demo_url,
        "submittedAt": submitted_at,
        "privacy": {
            "rawRepoUploaded": False,
            "sourceCodeUploaded": False,
            "rawTranscriptsUploaded": False,
            "publicMetadataOnly": True,
        },
    }


def clean_profile(raw: dict) -> dict:
    if raw.get("schema") != "tokenbar.identity.v1":
        raise ValueError("expected tokenbar.identity.v1")
    token = str(raw.get("token") or "").strip()
    if not token.startswith("TBAR-") or len(token) < 10:
        raise ValueError("missing TokenBar identity token")

    allowed = {
        "schema",
        "token",
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
        "loopScaleVersion",
        "loopScaleSource",
        "windowDays",
        "generatedAt",
        "privacy",
        "dimensions",
        "signatureMoves",
        "growthEdge",
        "usage",
        "populationStats",
        "sessionAnalysis",
        "shippingAnalysis",
        "providerAnalyses",
        "providerSources",
        "builderSignalInbox",
        "socialLearningSignals",
        "publicProfile",
        "hackathonSubmission",
        "submittedProject",
        "leaderboard",
        "shareCopy",
        "shareControls",
        "socialUrl",
        "rankingsUrl",
        "loopRankingsUrl",
        "actionLinks",
        "surfaceBundle",
        "rankBadges",
        "rankPlacements",
        "safeEvidenceReceipt",
        "nextActionPlan",
        "shareReceipt",
    }
    cleaned = {key: raw.get(key) for key in allowed if key in raw}
    builder_signals = clean_builder_signal_summary(cleaned.get("builderSignalInbox") or cleaned.get("socialLearningSignals"))
    if builder_signals:
        cleaned["builderSignalInbox"] = builder_signals
        cleaned["socialLearningSignals"] = builder_signals
    else:
        cleaned.pop("builderSignalInbox", None)
        cleaned.pop("socialLearningSignals", None)
    if isinstance(cleaned.get("publicProfile"), dict):
        cleaned["publicProfile"] = clean_public_profile(cleaned.get("publicProfile"), fallback_name=str(cleaned.get("title") or "builder"))
    submission = clean_submission_metadata(
        cleaned.get("hackathonSubmission") or cleaned.get("submittedProject"),
        fallback_title=str(cleaned.get("title") or "builder"),
    )
    if submission:
        cleaned["hackathonSubmission"] = submission
        cleaned["submittedProject"] = submission
    else:
        cleaned.pop("hackathonSubmission", None)
        cleaned.pop("submittedProject", None)
    session_analysis = cleaned.get("sessionAnalysis")
    privacy = cleaned.get("privacy") if isinstance(cleaned.get("privacy"), dict) else {}
    if isinstance(session_analysis, dict):
        if session_analysis.get("rawTranscriptsIncluded") is not False or privacy.get("rawTranscriptsIncluded") is not False:
            cleaned.pop("sessionAnalysis", None)
        else:
            safe_session_keys = {
                "available",
                "source",
                "sampledFiles",
                "promptCount",
                "assistantMessageCount",
                "toolCallCount",
                "avgPromptWords",
                "shortPromptRatio",
                "commandPromptRatio",
                "questionPromptRatio",
                "planningSignal",
                "redirectionSignal",
                "urgencySignal",
                "visualSignal",
                "monetizationSignal",
                "privacySignal",
                "identitySignal",
                "topWorkspaces",
                "signaturePhrases",
                "behaviorPatterns",
                "operatingMode",
                "rawTranscriptsIncluded",
                "redactedExcerptsOnly",
            }
            cleaned["sessionAnalysis"] = {
                key: session_analysis.get(key)
                for key in safe_session_keys
                if key in session_analysis
            }
    shipping_analysis = cleaned.get("shippingAnalysis")
    if isinstance(shipping_analysis, dict):
        if shipping_analysis.get("sourceCodeIncluded") is not False or shipping_analysis.get("rawDiffsIncluded") is not False:
            cleaned.pop("shippingAnalysis", None)
        else:
            safe_shipping_keys = {
                "available",
                "reason",
                "source",
                "repo",
                "windowDays",
                "commitCount",
                "filesChanged",
                "insertions",
                "deletions",
                "netLoc",
                "contributors",
                "peakCommitDay",
                "recentCommitSubjects",
                "sourceCodeIncluded",
                "rawDiffsIncluded",
                "method",
            }
            cleaned["shippingAnalysis"] = {
                key: shipping_analysis.get(key)
                for key in safe_shipping_keys
                if key in shipping_analysis
            }
    cleaned["uploadedAt"] = int(time.time())
    cleaned["source"] = "tokenbar-cli-opt-in"
    action_links = cleaned.get("actionLinks") if isinstance(cleaned.get("actionLinks"), dict) else {}
    surface_bundle = cleaned.get("surfaceBundle") if isinstance(cleaned.get("surfaceBundle"), dict) else {}
    if action_links and surface_bundle.get("schema") != "tokenbar.surface_bundle.v1":
        share_controls = cleaned.get("shareControls") if isinstance(cleaned.get("shareControls"), dict) else {}
        visibility = str(share_controls.get("visibility") or privacy.get("shareMode") or "public").lower()
        cleaned["surfaceBundle"] = build_surface_bundle(
            token=token,
            proof_url=str(action_links.get("proofCardUrl") or ""),
            profile_url=str(action_links.get("profileUrl") or ""),
            social_url=str(action_links.get("socialUrl") or ""),
            rankings_url=str(action_links.get("rankingsUrl") or ""),
            loop_rankings_url=str(action_links.get("loopRankingsUrl") or ""),
            visibility=visibility,
            share_copy=str(cleaned.get("shareCopy") or ""),
        )
    elif surface_bundle:
        boundary = surface_bundle.get("privacyBoundary") if isinstance(surface_bundle.get("privacyBoundary"), dict) else {}
        boundary["rawTranscriptsIncluded"] = False
        boundary["sourceCodeIncluded"] = False
        boundary.setdefault("neverPublic", ["rawTranscripts", "sourceCode", "privateDiffs", "credentials", "envFiles"])
        surface_bundle["privacyBoundary"] = boundary
        cleaned["surfaceBundle"] = surface_bundle
    return cleaned


def aggregate_stats(profiles_by_token: dict[str, dict], storage: str) -> dict:
    profiles = list(profiles_by_token.values())
    archetypes: dict[str, int] = {}
    npc_classes: dict[str, int] = {}
    label_buckets: dict[str, int] = {}
    provider_coverage: dict[str, int] = {}
    specificity_bands: dict[str, int] = {
        "0-39 emerging": 0,
        "40-59 forming": 0,
        "60-79 specific": 0,
        "80-100 rare": 0,
    }
    specificity = []
    loop_maturity_values = []
    label_space_size = 0
    top_profiles = []
    social_feed = []
    regional_scores: dict[str, list[dict]] = {}
    submission_events: dict[str, int] = {}
    submission_tracks: dict[str, int] = {}
    session_signal_keys = [
        "planningSignal",
        "redirectionSignal",
        "urgencySignal",
        "visualSignal",
        "monetizationSignal",
        "privacySignal",
        "identitySignal",
        "commandPromptRatio",
        "shortPromptRatio",
    ]
    session_totals = {key: [] for key in session_signal_keys}
    session_prompt_counts = []
    for profile in profiles:
        public_profile = profile.get("publicProfile") if isinstance(profile.get("publicProfile"), dict) else {}
        visibility = str(public_profile.get("visibility") or "public").lower()
        if visibility not in {"public", "listed"}:
            continue
        archetype = profile.get("primaryArchetype") or "Unknown"
        npc_class = profile.get("npcClass") or "unknown"
        label = profile.get("identityLabel") or {}
        bucket = label.get("bucketKey") if isinstance(label, dict) else None
        archetypes[archetype] = archetypes.get(archetype, 0) + 1
        npc_classes[npc_class] = npc_classes.get(npc_class, 0) + 1
        if bucket:
            label_buckets[bucket] = label_buckets.get(bucket, 0) + 1
        label_model = profile.get("labelModel") if isinstance(profile.get("labelModel"), dict) else {}
        try:
            label_space_size = max(label_space_size, int(label_model.get("possibleLabels") or 0))
        except Exception:
            pass
        score = None
        try:
            score = float(profile.get("specificityScore") or 0)
            specificity.append(score)
            if score < 40:
                specificity_bands["0-39 emerging"] += 1
            elif score < 60:
                specificity_bands["40-59 forming"] += 1
            elif score < 80:
                specificity_bands["60-79 specific"] += 1
            else:
                specificity_bands["80-100 rare"] += 1
        except Exception:
            pass
        try:
            loop_maturity_values.append(float(profile.get("loopMaturity") or profile.get("loopScore") or profile.get("proofScore") or 0))
        except Exception:
            pass
        if score is not None:
            leaderboard = profile.get("leaderboard") if isinstance(profile.get("leaderboard"), dict) else {}
            nickname = public_profile.get("nickname") or public_profile.get("handle") or profile.get("title")
            region = public_profile.get("region") or leaderboard.get("region") or "Global"
            token_count = leaderboard.get("tokenCount") or (profile.get("usage") or {}).get("totalTokens")
            proof_score = profile.get("proofScore") or leaderboard.get("score") or score
            loop_maturity = profile.get("loopMaturity") or profile.get("loopScore") or proof_score
            provider_sources = profile.get("providerSources") if isinstance(profile.get("providerSources"), list) else []
            provider_count = sum(1 for item in provider_sources if isinstance(item, dict) and item.get("found"))
            session_count = (profile.get("usage") or {}).get("sessionCount") or profile.get("sessionCount") or 0
            try:
                token_component = min(100.0, math.log10(max(1, float(token_count or 0))) * 10.0)
            except Exception:
                token_component = 0.0
            try:
                range_component = min(100.0, (float(provider_count) * 22.0) + (math.log10(max(1, float(session_count or 0))) * 14.0))
            except Exception:
                range_component = min(100.0, float(provider_count) * 22.0)
            ranking_breakdown = {
                "proof": round(float(proof_score or 0), 1),
                "loop": round(float(loop_maturity or 0), 1),
                "specificity": round(float(score or 0), 1),
                "range": round(range_component, 1),
                "tokens": round(token_component, 1),
                "weights": {
                    "proof": 0.34,
                    "loop": 0.24,
                    "specificity": 0.22,
                    "range": 0.14,
                    "tokens": 0.06,
                },
                "note": "Token volume is capped at 6% of the composite ranking score.",
            }
            composite_score = leaderboard.get("score")
            if not composite_score:
                composite_score = (
                    ranking_breakdown["proof"] * ranking_breakdown["weights"]["proof"]
                    + ranking_breakdown["loop"] * ranking_breakdown["weights"]["loop"]
                    + ranking_breakdown["specificity"] * ranking_breakdown["weights"]["specificity"]
                    + ranking_breakdown["range"] * ranking_breakdown["weights"]["range"]
                    + ranking_breakdown["tokens"] * ranking_breakdown["weights"]["tokens"]
                )
            submission = clean_submission_metadata(
                profile.get("hackathonSubmission") or profile.get("submittedProject"),
                fallback_title=str(profile.get("title") or "builder"),
            )
            if submission:
                submission_events[submission["event"]] = submission_events.get(submission["event"], 0) + 1
                submission_tracks[submission["track"]] = submission_tracks.get(submission["track"], 0) + 1
            leaderboard_row = {
                "token": profile.get("token"),
                "nickname": nickname,
                "region": region,
                "title": profile.get("title"),
                "projectTitle": submission.get("projectTitle") if submission else None,
                "event": submission.get("event") if submission else None,
                "track": submission.get("track") if submission else None,
                "repoUrl": submission.get("repoUrl") if submission else None,
                "demoUrl": submission.get("demoUrl") if submission else None,
                "hackathonSubmission": submission,
                "submittedProject": submission,
                "primaryArchetype": archetype,
                "npcClass": npc_class,
                "bucket": bucket,
                "specificityScore": round(score, 1),
                "score": round(float(composite_score or 0), 1),
                "proofScore": round(float(proof_score or 0), 1),
                "loopMaturity": round(float(loop_maturity or 0), 1),
                "loopScore": round(float(loop_maturity or 0), 1),
                "tokenCount": token_count,
                "sessionCount": session_count,
                "rankingBreakdown": ranking_breakdown,
                "bio": public_profile.get("bio"),
                "github": (public_profile.get("links") or {}).get("github") if isinstance(public_profile.get("links"), dict) else None,
            }
            top_profiles.append({
                "token": profile.get("token"),
                "title": profile.get("title"),
                "projectTitle": submission.get("projectTitle") if submission else None,
                "event": submission.get("event") if submission else None,
                "track": submission.get("track") if submission else None,
                "repoUrl": submission.get("repoUrl") if submission else None,
                "demoUrl": submission.get("demoUrl") if submission else None,
                "hackathonSubmission": submission,
                "submittedProject": submission,
                "nickname": nickname,
                "region": region,
                "primaryArchetype": archetype,
                "npcClass": npc_class,
                "bucket": bucket,
                "specificityScore": round(score, 1),
                "score": leaderboard_row["score"],
                "proofScore": leaderboard_row["proofScore"],
                "loopMaturity": leaderboard_row["loopMaturity"],
                "loopScore": leaderboard_row["loopScore"],
                "tokenCount": token_count,
                "sessionCount": session_count,
                "rankingBreakdown": ranking_breakdown,
            })
            social_feed.append(leaderboard_row)
            regional_scores.setdefault(str(region), []).append(leaderboard_row)
        for item in profile.get("providerSources") or []:
            if not isinstance(item, dict):
                continue
            key = item.get("name") or item.get("key")
            if key and item.get("found"):
                provider_coverage[str(key)] = provider_coverage.get(str(key), 0) + 1
        session = profile.get("sessionAnalysis") if isinstance(profile.get("sessionAnalysis"), dict) else {}
        if session.get("rawTranscriptsIncluded") is False:
            try:
                session_prompt_counts.append(int(session.get("promptCount") or 0))
            except Exception:
                pass
            for key in session_signal_keys:
                try:
                    session_totals[key].append(float(session.get(key) or 0))
                except Exception:
                    pass
    total = max(1, len(profiles))

    def percentages(values: dict[str, int]) -> dict[str, float]:
        return {
            key: round((count / total) * 100, 1)
            for key, count in sorted(values.items(), key=lambda item: (-item[1], item[0]))
        }

    label_bucket_percentages = percentages(label_buckets)
    common_buckets = sorted(label_buckets.items(), key=lambda item: (-item[1], item[0]))[:20]
    rare_buckets = sorted(label_buckets.items(), key=lambda item: (item[1], item[0]))[:20]

    def bucket_rows(items: list[tuple[str, int]]) -> list[dict]:
        return [
            {
                "bucket": key,
                "count": count,
                "sharePercent": label_bucket_percentages.get(key, 0),
                "rarity": "unique" if count == 1 else "uncommon" if count <= 3 else "common",
            }
            for key, count in items
        ]

    return {
        "profileCount": len(profiles),
        "archetypes": dict(sorted(archetypes.items(), key=lambda item: (-item[1], item[0]))),
        "archetypePercentages": percentages(archetypes),
        "npcClasses": dict(sorted(npc_classes.items(), key=lambda item: (-item[1], item[0]))),
        "npcClassPercentages": percentages(npc_classes),
        "labelBuckets": dict(common_buckets),
        "labelBucketPercentages": dict((key, label_bucket_percentages.get(key, 0)) for key, _ in common_buckets),
        "rarestLabelBuckets": bucket_rows(rare_buckets),
        "commonLabelBuckets": bucket_rows(common_buckets),
        "uniqueLabelBucketCount": len(label_buckets),
        "labelSpaceSize": label_space_size,
        "labelSpaceCoveragePercent": round((len(label_buckets) / label_space_size) * 100, 3) if label_space_size else 0,
        "publicRankings": {
            "rarestBuckets": bucket_rows(rare_buckets[:12]),
            "commonBuckets": bucket_rows(common_buckets[:12]),
            "topSpecificProfiles": sorted(
                top_profiles,
                key=lambda item: (-float(item.get("specificityScore") or 0), str(item.get("title") or "")),
            )[:12],
            "topLoopProfiles": sorted(
                top_profiles,
                key=lambda item: (-float(item.get("loopMaturity") or 0), str(item.get("title") or "")),
            )[:12],
            "socialFeed": sorted(
                social_feed,
                key=lambda item: (-float(item.get("score") or 0), str(item.get("nickname") or "")),
            )[:24],
            "regionalLeaderboards": {
                region: sorted(rows, key=lambda item: (-float(item.get("score") or 0), str(item.get("nickname") or "")))[:12]
                for region, rows in sorted(regional_scores.items())
            },
            "submissionEvents": dict(sorted(submission_events.items(), key=lambda item: (-item[1], item[0]))),
            "submissionTracks": dict(sorted(submission_tracks.items(), key=lambda item: (-item[1], item[0]))),
        },
        "specificityBands": specificity_bands,
        "specificityBandPercentages": percentages(specificity_bands),
        "topSpecificProfiles": sorted(
            top_profiles,
            key=lambda item: (-float(item.get("specificityScore") or 0), str(item.get("title") or "")),
        )[:12],
        "submissionEvents": dict(sorted(submission_events.items(), key=lambda item: (-item[1], item[0]))),
        "submissionTracks": dict(sorted(submission_tracks.items(), key=lambda item: (-item[1], item[0]))),
        "providerCoverage": dict(sorted(provider_coverage.items(), key=lambda item: (-item[1], item[0]))),
        "providerCoveragePercentages": percentages(provider_coverage),
        "averageSpecificity": round(sum(specificity) / len(specificity), 1) if specificity else 0,
        "averageLoopMaturity": round(sum(loop_maturity_values) / len(loop_maturity_values), 1) if loop_maturity_values else 0,
        "sessionSignalAverages": {
            key: round((sum(values) / len(values)) * 100, 1)
            for key, values in session_totals.items()
            if values
        },
        "averageSampledPrompts": round(sum(session_prompt_counts) / len(session_prompt_counts), 1) if session_prompt_counts else 0,
        "storage": storage,
        "durable": storage == "supabase-postgres",
        "durableStoreNext": "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in Vercel to persist public profiles." if storage != "supabase-postgres" else "Durable Supabase profile storage is active.",
    }


def profile_population_context(profile: dict, profiles_by_token: dict[str, dict]) -> dict:
    profiles = list(profiles_by_token.values())
    total = len(profiles)
    if not total:
        return {
            "profileCount": 0,
            "status": "no opt-in profiles yet",
        }

    label = profile.get("identityLabel") if isinstance(profile.get("identityLabel"), dict) else {}
    bucket = label.get("bucketKey")
    archetype = profile.get("primaryArchetype")
    npc_class = profile.get("npcClass")

    def percent(count: int) -> float:
        return round((count / max(1, total)) * 100, 1)

    bucket_count = 0
    archetype_count = 0
    npc_count = 0
    specificity_values = []
    current_specificity = None
    try:
        current_specificity = float(profile.get("specificityScore") or 0)
    except Exception:
        current_specificity = None

    for item in profiles:
        item_label = item.get("identityLabel") if isinstance(item.get("identityLabel"), dict) else {}
        if bucket and item_label.get("bucketKey") == bucket:
            bucket_count += 1
        if archetype and item.get("primaryArchetype") == archetype:
            archetype_count += 1
        if npc_class and item.get("npcClass") == npc_class:
            npc_count += 1
        try:
            specificity_values.append(float(item.get("specificityScore") or 0))
        except Exception:
            pass

    percentile = None
    if current_specificity is not None and specificity_values:
        less_or_equal = sum(1 for value in specificity_values if value <= current_specificity)
        percentile = round((less_or_equal / len(specificity_values)) * 100, 1)

    return {
        "profileCount": total,
        "bucket": bucket,
        "bucketCount": bucket_count,
        "bucketSharePercent": percent(bucket_count) if bucket else 0,
        "archetype": archetype,
        "archetypeCount": archetype_count,
        "archetypeSharePercent": percent(archetype_count) if archetype else 0,
        "npcClass": npc_class,
        "npcClassCount": npc_count,
        "npcClassSharePercent": percent(npc_count) if npc_class else 0,
        "specificityPercentile": percentile,
        "status": "opt-in population context",
    }


def profile_html(profile: dict, stats: dict, population: dict | None = None) -> str:
    title = html.escape(str(profile.get("title") or "TokenBar Builder Profile"))
    subtitle = html.escape(str(profile.get("subtitle") or "Local-first AI builder identity profile."))
    archetype = html.escape(str(profile.get("primaryArchetype") or title))
    npc = html.escape(str(profile.get("npcClass") or "builder"))
    token = html.escape(str(profile.get("token") or ""))
    growth = html.escape(str(profile.get("growthEdge") or ""))
    specificity = html.escape(str(profile.get("specificityScore") or "0"))
    proof_score = html.escape(str(profile.get("proofScore") or profile.get("specificityScore") or "0"))
    loop_maturity = html.escape(str(profile.get("loopMaturity") or profile.get("loopScore") or "0"))
    rarity = html.escape(str(profile.get("estimatedRarityPercent") or "unknown"))
    report_kind = html.escape(str(profile.get("reportKind") or "tokenbar.identity.v1"))
    activation = profile.get("profileActivation") if isinstance(profile.get("profileActivation"), dict) else {}
    pdf_command = html.escape(str(activation.get("localPdfCommand") or "tokenbar profile --pdf"))
    share_command = html.escape(str(activation.get("shareLatestCommand") or "tokenbar share latest"))
    share_copy = html.escape(str(profile.get("shareCopy") or ""))
    action_links = profile.get("actionLinks") if isinstance(profile.get("actionLinks"), dict) else {}
    privacy = profile.get("privacy") if isinstance(profile.get("privacy"), dict) else {}
    share_controls = profile.get("shareControls") if isinstance(profile.get("shareControls"), dict) else {}
    public_profile = profile.get("publicProfile") if isinstance(profile.get("publicProfile"), dict) else {}
    owner_profile = clean_public_profile(public_profile, fallback_name=str(profile.get("title") or "builder"))
    owner_nickname = html.escape(str(owner_profile.get("nickname") or "builder"))
    owner_handle = html.escape(str(owner_profile.get("handle") or "builder"))
    owner_region = html.escape(str(owner_profile.get("region") or "Global"))
    owner_bio = html.escape(str(owner_profile.get("bio") or "Published a safe TokenBar builder identity proof from local analysis."))
    owner_links = "".join(
        f'<a href="{html.escape(str(url), quote=True)}" rel="noopener noreferrer">{html.escape(str(label).title())}</a>'
        for label, url in (owner_profile.get("links") or {}).items()
        if str(url or "").strip()
    )
    submission = clean_submission_metadata(
        profile.get("hackathonSubmission") or profile.get("submittedProject"),
        fallback_title=str(profile.get("title") or "builder"),
    )
    submission_html = ""
    if submission:
        submission_links = []
        if submission.get("repoUrl"):
            submission_links.append(f'<a href="{html.escape(str(submission["repoUrl"]), quote=True)}" rel="noopener noreferrer">Public repo</a>')
        if submission.get("demoUrl"):
            submission_links.append(f'<a href="{html.escape(str(submission["demoUrl"]), quote=True)}" rel="noopener noreferrer">Demo</a>')
        submission_html = f"""
      <div class="submission-card" aria-label="Submitted project">
        <div>
          <span>Submitted project</span>
          <strong>{html.escape(str(submission.get("projectTitle") or "Untitled project"))}</strong>
          <p>{html.escape(str(submission.get("tagline") or "Repo-level builder identity proof generated locally."))}</p>
        </div>
        <div>
          <b>{html.escape(str(submission.get("event") or "Independent build"))}</b>
          <small>{html.escape(str(submission.get("track") or "Builder identity"))}</small>
          <nav>{''.join(submission_links) or '<span>No public repo/demo link attached</span>'}</nav>
          <em>No raw repo upload · No raw transcripts · Public metadata only</em>
        </div>
      </div>
        """
    visibility = html.escape(str(share_controls.get("visibility") or privacy.get("shareMode") or public_profile.get("visibility") or "public"))
    share_surface_count = len([href for href in action_links.values() if str(href or "").strip()])
    share_surface_text = html.escape(str(share_surface_count or "0"))
    rank_badges = profile.get("rankBadges") if isinstance(profile.get("rankBadges"), list) else []
    rank_badge_rows = []
    for badge in rank_badges[:5]:
        if not isinstance(badge, dict):
            continue
        label = html.escape(str(badge.get("label") or badge.get("key") or "Public board"))
        rank = html.escape(str(badge.get("rank") or ""))
        total = html.escape(str(badge.get("total") or ""))
        basis = html.escape(str(badge.get("basis") or badge.get("description") or "safe public proof cards"))
        score = html.escape(str(badge.get("score") or ""))
        rank_badge_rows.append(
            f"<div><b>{label}</b><strong>#{rank}{('/' + total) if total else ''}</strong><span>{basis}</span><small>{score}</small></div>"
        )
    rank_context_html = ""
    if rank_badge_rows:
        rank_context_html = f"""
        <div class="profile-rank-context" aria-label="Public rank context">
          <h3>Public rank context</h3>
          <p>Derived only from opt-in proof cards. Token volume is capped so the board rewards loop quality, proof, craft, and completion rather than raw spend.</p>
          <div>{''.join(rank_badge_rows)}</div>
        </div>
        """
    identity_label = profile.get("identityLabel") if isinstance(profile.get("identityLabel"), dict) else {}
    bucket = html.escape(str(identity_label.get("bucketKey") or ""))
    catalog = identity_label.get("catalog") if isinstance(identity_label.get("catalog"), dict) else {}
    label_model = profile.get("labelModel") if isinstance(profile.get("labelModel"), dict) else {}
    possible_labels = html.escape(str(label_model.get("possibleLabels") or catalog.get("possibleLabels") or ""))
    population = population or {}
    population_count = html.escape(str(population.get("profileCount") or stats.get("profileCount") or 0))
    bucket_share = html.escape(str(population.get("bucketSharePercent", 0)))
    archetype_share = html.escape(str(population.get("archetypeSharePercent", 0)))
    npc_share = html.escape(str(population.get("npcClassSharePercent", 0)))
    specificity_percentile = population.get("specificityPercentile")
    specificity_percentile_text = html.escape(
        "pending" if specificity_percentile is None else f"{specificity_percentile}%"
    )
    rationale = profile.get("labelRationale") if isinstance(profile.get("labelRationale"), dict) else {}
    rationale_summary = html.escape(str(rationale.get("summary") or ""))
    driver_rows = []
    for item in (rationale.get("topTraitDrivers") or [])[:6]:
        trait = html.escape(str(item.get("trait") or "Trait"))
        score = html.escape(str(item.get("score") or 0))
        driver_rows.append(f"<li><b>{trait}</b><span>{score}/100</span></li>")

    rows = []
    for item in (profile.get("archetypeDistribution") or [])[:8]:
        name = html.escape(str(item.get("name") or "Unknown"))
        probability = html.escape(str(item.get("probability") or 0))
        item_npc = html.escape(str(item.get("npcClass") or "builder"))
        rows.append(f"<li><b>{name}</b><span>{probability}%</span><small>{item_npc}</small></li>")

    bucket_rows = []
    for item in (profile.get("labelDistribution") or [])[:8]:
        name = html.escape(str(item.get("title") or "Unknown bucket"))
        probability = html.escape(str(item.get("probability") or 0))
        item_npc = html.escape(str(item.get("npcClass") or "builder"))
        bucket_rows.append(f"<li><b>{name}</b><span>{probability}%</span><small>{item_npc}</small></li>")

    modifier_rows = []
    for item in (profile.get("modifierDistribution") or [])[:6]:
        name = html.escape(str(item.get("name") or "Modifier"))
        probability = html.escape(str(item.get("probability") or 0))
        modifier_rows.append(f"<li><b>{name}</b><span>{probability}%</span></li>")

    stance_rows = []
    for item in (profile.get("stanceDistribution") or [])[:6]:
        name = html.escape(str(item.get("name") or "Stance"))
        probability = html.escape(str(item.get("probability") or 0))
        stance_rows.append(f"<li><b>{name}</b><span>{probability}%</span></li>")

    session = profile.get("sessionAnalysis") if isinstance(profile.get("sessionAnalysis"), dict) else {}
    operating_mode = html.escape(str(session.get("operatingMode") or "insufficient local signal"))
    behavior_rows = []
    for item in (session.get("behaviorPatterns") or [])[:5]:
        name = html.escape(str(item.get("name") or "Pattern"))
        score = html.escape(str(item.get("score") or 0))
        evidence = html.escape(str(item.get("evidence") or ""))
        behavior_rows.append(f"<li><b>{name}</b><span>{score}/100</span><small>{evidence}</small></li>")

    loop_rows = []
    for item in (profile.get("loopScale") or [])[:9]:
        name = html.escape(str(item.get("name") or "Loop dimension"))
        score = html.escape(str(item.get("score") or 0))
        evidence = html.escape(str(item.get("evidence") or ""))
        loop_rows.append(f"<li><b>{name}</b><span>{score}/100</span><small>{evidence}</small></li>")

    story = profile.get("builderStory") if isinstance(profile.get("builderStory"), dict) else {}
    story_headline = html.escape(str(story.get("headline") or "Builder story"))
    story_summary = html.escape(str(story.get("summary") or "This public profile was generated from a safe aggregate TokenBar proof artifact."))
    story_frontier = html.escape(str(story.get("nextFrontier") or growth or ""))
    axis_rows = []
    for axis in (story.get("axes") or [])[:6]:
        if not isinstance(axis, dict):
            continue
        label = html.escape(str(axis.get("label") or axis.get("key") or "Builder signal"))
        score = html.escape(str(round(float(axis.get("score") or 0), 1)))
        confidence = html.escape(str(axis.get("confidence") or "low"))
        claim = html.escape(str(axis.get("claim") or ""))
        provenance = axis.get("provenance") if isinstance(axis.get("provenance"), list) else []
        provenance_text = html.escape(" · ".join(str(item) for item in provenance[:3]))
        axis_rows.append(
            f"<li><b>{label}</b><span>{score}/100</span><small>{claim}</small><em>{confidence} confidence · {provenance_text}</em></li>"
        )
    proved_rows = [
        f"<li><b>{html.escape(str(item))}</b><span>proved</span></li>"
        for item in (story.get("whatProved") or [])[:5]
    ]
    shipped_work_rows = []
    for item in (story.get("shippedWork") or profile.get("shippedWork") or [])[:4]:
        if not isinstance(item, dict):
            continue
        label = html.escape(str(item.get("label") or "Evidence"))
        value = html.escape(str(item.get("value") or ""))
        note = html.escape(str(item.get("note") or ""))
        provenance = html.escape(str(item.get("provenance") or "safe aggregate evidence"))
        shipped_work_rows.append(
            f"<div><b>{label}</b><strong>{value}</strong><span>{note}</span><small>{provenance}</small></div>"
        )
    shipped_work_html = ""
    if shipped_work_rows:
        shipped_work_html = f"""
        <div class="shipped-work-receipt" aria-label="Shipped-work receipt">
          <h3>Shipped-work receipt</h3>
          <p>Evidence behind the public story. Quantities can be redacted, but the safe provenance stays visible.</p>
          <div>{''.join(shipped_work_rows)}</div>
        </div>
        """
    builder_signals = clean_builder_signal_summary(profile.get("builderSignalInbox") or profile.get("socialLearningSignals"))
    reference_radar_html = ""
    if builder_signals.get("available"):
        reference_chips = []
        for item in (builder_signals.get("topTags") or [])[:5]:
            if isinstance(item, dict) and item.get("name"):
                reference_chips.append(
                    f"<span>{html.escape(str(item.get('name')))}<small>{html.escape(str(item.get('count') or 0))}</small></span>"
                )
        for item in (builder_signals.get("topHosts") or [])[:4]:
            if isinstance(item, dict) and item.get("name"):
                reference_chips.append(
                    f"<span>{html.escape(str(item.get('name')))}<small>{html.escape(str(item.get('count') or 0))}</small></span>"
                )
        tag_names = ", ".join(
            str(item.get("name"))
            for item in (builder_signals.get("topTags") or [])[:2]
            if isinstance(item, dict) and item.get("name")
        )
        reference_radar_html = f"""
        <div class="reference-radar-panel" aria-label="Builder reference radar">
          <h3>Builder reference radar</h3>
          <p>What this builder studies between work sessions. Saved links become a private learning trail; the public profile only shows aggregate hosts, tags, and counts.</p>
          <div>
            <section><b>Saved references</b><strong>{html.escape(str(builder_signals.get("signalCount") or 0))}</strong><span>{html.escape(str(builder_signals.get("story") or "Local saved links are summarized as aggregate builder taste signals."))}</span></section>
            <section><b>Study pattern</b><strong>{html.escape(tag_names or "emerging")}</strong><span>Explains taste and inspiration without exposing the private inbox.</span></section>
            <section><b>Public boundary</b><strong>Aggregate only</strong><span>Raw URLs, titles, notes, page content, transcripts, and source code stay local.</span></section>
          </div>
          <nav>{''.join(reference_chips) or '<span>local signal<small>1</small></span>'}</nav>
        </div>
        """
    uncertainty_rows = [
        f"<li><b>{html.escape(str(item))}</b><span>uncertain</span></li>"
        for item in (story.get("uncertainties") or [])[:5]
    ]
    fact_rows = []
    for fact in (profile.get("proofFacts") or [])[:5]:
        if not isinstance(fact, dict):
            continue
        label = html.escape(str(fact.get("label") or "Fact"))
        value = html.escape(str(fact.get("value") or ""))
        note = html.escape(str(fact.get("note") or ""))
        fact_rows.append(f"<li><b>{label}</b><span>{value}</span><small>{note}</small></li>")
    link_rows = []
    for label, key in [
        ("Proof card", "proofCardUrl"),
        ("Public profile", "profileUrl"),
        ("For You feed", "socialUrl"),
        ("Rankings", "rankingsUrl"),
        ("Loop rankings", "loopRankingsUrl"),
    ]:
        href = str(action_links.get(key) or "").strip()
        if not href:
            continue
        safe_href = html.escape(href, quote=True)
        safe_label = html.escape(label)
        link_rows.append(f'<a href="{safe_href}">{safe_label}</a>')
    share_preview_html = (
        f'<div class="share-preview"><strong>Share preview</strong><p>{share_copy}</p></div>'
        if share_copy
        else ""
    )
    safe_receipt = profile.get("safeEvidenceReceipt") if isinstance(profile.get("safeEvidenceReceipt"), dict) else {}
    safe_receipt_html = ""
    if safe_receipt:
        used_rows = "".join(
            f"<li><b>{html.escape(str(item))}</b><span>used</span></li>"
            for item in (safe_receipt.get("usedEvidence") if isinstance(safe_receipt.get("usedEvidence"), list) else [])[:5]
        )
        never_rows = "".join(
            f"<li><b>{html.escape(str(item))}</b><span>never used</span></li>"
            for item in (safe_receipt.get("neverUsed") if isinstance(safe_receipt.get("neverUsed"), list) else [])[:6]
        )
        safe_receipt_html = f"""
        <div class="safe-evidence-receipt" aria-label="Safe evidence receipt">
          <h3>Safe evidence receipt</h3>
          <p>{html.escape(str(safe_receipt.get("summary") or "Safe aggregate evidence only."))} {html.escape(str(safe_receipt.get("publicMaterial") or ""))}</p>
          <div>
            <section><b>Used</b><ul>{used_rows}</ul></section>
            <section><b>Never used</b><ul>{never_rows}</ul></section>
          </div>
        </div>
        """
    share_receipt = profile.get("shareReceipt") if isinstance(profile.get("shareReceipt"), dict) else {}
    share_receipt_html = ""
    if share_receipt:
        redacted = ", ".join(str(item) for item in (share_receipt.get("redactedFields") if isinstance(share_receipt.get("redactedFields"), list) else [])) or "none"
        never_rows = "".join(
            f"<li><b>{html.escape(str(item))}</b><span>never public</span></li>"
            for item in (share_receipt.get("neverPublic") if isinstance(share_receipt.get("neverPublic"), list) else [])[:6]
        )
        share_receipt_html = f"""
        <div class="share-receipt" aria-label="Share receipt">
          <h3>Share receipt</h3>
          <p>{html.escape(str(share_receipt.get("copySafeSummary") or "This TokenBar profile is safe to share."))}</p>
          <div>
            <span><b>Schema</b>{html.escape(str(share_receipt.get("schema") or "tokenbar.share_receipt.v1"))}</span>
            <span><b>Mode</b>{html.escape(str(share_receipt.get("shareMode") or visibility))}</span>
            <span><b>Public material</b>{html.escape(str(share_receipt.get("publicMaterial") or "profile summary"))}</span>
            <span><b>Redacted</b>{html.escape(redacted)}</span>
          </div>
          <ul>{never_rows}</ul>
        </div>
        """
    identity_passport_html = f"""
        <div class="identity-passport" aria-label="Builder identity passport">
          <div class="passport-main">
            <span>Builder identity passport</span>
            <strong>{title}</strong>
            <p>{story_summary}</p>
          </div>
          <div class="passport-proof">
            <div><b>Token</b><code>{token or "pending"}</code></div>
            <div><b>Public shape</b><strong>{archetype}</strong><small>{npc}</small></div>
            <div><b>Proof posture</b><strong>{proof_score}/100 proof · {loop_maturity}/100 loop</strong><small>safe evidence only</small></div>
            <div><b>Visibility</b><strong>{visibility}</strong><small>{share_surface_text} shareable surfaces</small></div>
          </div>
          <div class="passport-strip">
            <span>Public profile</span>
            <span>Proof card</span>
            <span>For You feed</span>
            <span>Rankings row</span>
          </div>
        </div>
    """
    self_comparison = profile.get("selfComparison") if isinstance(profile.get("selfComparison"), dict) else {}
    self_comparison_rows = []
    for card in (self_comparison.get("cards") or [])[:4]:
        if not isinstance(card, dict):
            continue
        label = html.escape(str(card.get("label") or "Self signal"))
        value = html.escape(str(card.get("value") or ""))
        note = html.escape(str(card.get("note") or ""))
        self_comparison_rows.append(f"<li><b>{label}</b><span>{value}</span><small>{note}</small></li>")
    self_comparison_html = ""
    if self_comparison_rows:
        basis = html.escape(str(self_comparison.get("basis") or "Safe aggregate windows only."))
        uncertainty = html.escape(str(self_comparison.get("uncertainty") or "Multiple claims make this trend sharper."))
        self_comparison_html = f"""
        <div class="self-comparison" aria-label="Compared to yourself over time">
          <h3>Compared to yourself over time</h3>
          <p>{basis}</p>
          <ul>{''.join(self_comparison_rows)}</ul>
          <div class="edge">{uncertainty}</div>
        </div>
        """
    next_action_plan = profile.get("nextActionPlan") if isinstance(profile.get("nextActionPlan"), dict) else {}
    next_action_rows = []
    for item in (next_action_plan.get("actions") if isinstance(next_action_plan.get("actions"), list) else [])[:3]:
        if not isinstance(item, dict):
            continue
        label = html.escape(str(item.get("label") or item.get("key") or "Next action"))
        command = html.escape(str(item.get("command") or "tokenbar claim"))
        why = html.escape(str(item.get("why") or "Run the next safe builder loop."))
        evidence = html.escape(str(item.get("evidenceNeeded") or "Reloadable proof evidence."))
        next_action_rows.append(f"<div><b>{label}</b><code>{command}</code><span>{why}</span><small>{evidence}</small></div>")
    next_action_html = ""
    if next_action_rows:
        next_action_html = f"""
        <div class="next-action-plan" aria-label="Act verify share next-action plan">
          <h3>Act next</h3>
          <p>Focus: {html.escape(str(next_action_plan.get("focus") or "run one safe builder loop"))}. Confidence: {html.escape(str(next_action_plan.get("confidence") or "medium"))}. This plan keeps public sharing optional.</p>
          <div>{''.join(next_action_rows)}</div>
        </div>
        """
    receipt = profile.get("verificationReceipt") if isinstance(profile.get("verificationReceipt"), dict) else {}
    receipt_redactions = receipt.get("redactions") if isinstance(receipt.get("redactions"), dict) else {}
    receipt_redaction_state = html.escape(", ".join(name for name, enabled in receipt_redactions.items() if enabled) or "none")
    receipt_stage_names = html.escape(", ".join(str(item) for item in (receipt.get("completedStages") if isinstance(receipt.get("completedStages"), list) else []) if item) or "not available")
    receipt_html = ""
    if receipt:
        receipt_html = f"""
        <div class="verification-receipt" aria-label="TokenBar verification receipt">
          <h3>Verification receipt</h3>
          <p>This profile is backed by a reloadable proof action. The public artifact is generated identity evidence only, with raw transcripts, source code, private diffs, credentials, and environment files excluded.</p>
          <div>
            <span><b>Run</b>{html.escape(str(receipt.get("runId") or ""))}</span>
            <span><b>Stages</b>{html.escape(str(receipt.get("stageCount") or 0))}</span>
            <span><b>Share mode</b>{html.escape(str(receipt.get("shareMode") or "public"))}</span>
            <span><b>Redactions</b>{receipt_redaction_state}</span>
            <span><b>Ranking</b>{html.escape(str((receipt.get("rankingPolicy") or {}).get("antiPayToWin") or "Token volume is capped."))}</span>
          </div>
          <small>Completed stages: {receipt_stage_names}</small>
        </div>
        """
    feedback_payload = json.dumps(
        {
            "token": str(profile.get("token") or ""),
            "category": "correction",
            "reportUrl": str(profile.get("profileUrl") or profile.get("proofCardUrl") or ""),
            "message": "Explain what is wrong without pasting raw transcripts, source code, credentials, private diffs, or env files.",
        },
        sort_keys=True,
    )

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>{title}</title>
  <style>
    body {{ margin:0; background:#eef2f7; color:#111827; font-family:Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }}
    main {{ max-width:980px; margin:0 auto; padding:42px 22px 70px; }}
    .card {{ background:white; border:1px solid #d8e0ec; border-radius:2px; padding:32px; box-shadow:0 24px 70px rgba(17,24,39,.10); }}
    .brand {{ display:flex; align-items:center; gap:12px; font-weight:900; }}
    .mark {{ width:38px; height:38px; border-radius:12px; background:linear-gradient(135deg,#1769ff,#27c46b,#f97316); color:white; display:grid; place-items:center; }}
    .doc-type {{ margin-top:42px; color:#f97316; font-size:12px; font-weight:900; letter-spacing:.14em; text-transform:uppercase; }}
    h1 {{ font-size:56px; line-height:.96; margin:46px 0 14px; letter-spacing:0; }}
    p {{ color:#4b5563; font-size:18px; line-height:1.55; }}
    .meta {{ display:grid; grid-template-columns:repeat(4,1fr); gap:12px; margin:28px 0; }}
    .meta div {{ border:1px solid #d8e0ec; border-radius:14px; padding:14px; }}
    .meta span {{ display:block; color:#6b7280; font-size:12px; font-weight:800; text-transform:uppercase; }}
    .meta strong {{ display:block; margin-top:8px; font-size:22px; }}
    .brief {{ display:grid; grid-template-columns:repeat(3,1fr); gap:12px; margin:26px 0; }}
    .brief div {{ border:1px solid #d8e0ec; border-radius:16px; padding:16px; background:#fbfdff; }}
    .brief b {{ display:block; color:#111827; font-size:15px; }}
    .brief span {{ display:block; margin-top:8px; color:#5b6678; font-size:13px; line-height:1.45; }}
    ul {{ list-style:none; padding:0; margin:0; display:grid; gap:10px; }}
    li {{ display:grid; grid-template-columns:1fr 72px; gap:12px; border:1px solid #e5e7eb; border-radius:12px; padding:13px 14px; }}
    li span {{ text-align:right; font-weight:900; }}
    li small {{ grid-column:1 / 3; color:#6b7280; font-weight:700; }}
    .edge {{ border-left:5px solid #f97316; background:#fff7ed; padding:18px; border-radius:2px; }}
    .activation {{ display:grid; gap:10px; border:1px solid #bed4ff; background:#f3f7ff; padding:18px; margin:22px 0; }}
    .activation code {{ display:block; padding:12px 14px; border:1px solid #d8e5ff; background:white; font-weight:850; overflow-wrap:anywhere; }}
    .story-card {{ margin:28px 0; padding:24px; border:1px solid #d8e0ec; background:linear-gradient(135deg,#ffffff,#f7fbff); }}
    .story-card h2 {{ margin-top:0; font-size:32px; letter-spacing:-.02em; }}
    .story-first {{ border-color:#bed4ff; box-shadow:0 20px 60px rgba(31,109,255,.10); }}
    .identity-passport {{ margin:22px 0; overflow:hidden; border:1px solid #b8cff8; border-radius:22px; background:#0f172a; color:#fff; box-shadow:0 18px 50px rgba(15,23,42,.18); }}
    .passport-main {{ padding:22px; background:radial-gradient(circle at 18% 0%, rgba(96,165,250,.35), transparent 42%), linear-gradient(135deg,#101827,#182338); }}
    .passport-main span {{ display:inline-flex; border:1px solid rgba(255,255,255,.24); border-radius:999px; padding:7px 10px; color:#bfdbfe; font-size:11px; font-weight:950; letter-spacing:.12em; text-transform:uppercase; }}
    .passport-main strong {{ display:block; margin-top:16px; color:white; font-size:36px; line-height:.98; letter-spacing:-.02em; }}
    .passport-main p {{ margin:12px 0 0; color:#cbd5e1; font-size:15px; line-height:1.48; }}
    .passport-proof {{ display:grid; grid-template-columns:repeat(4,1fr); gap:1px; background:rgba(255,255,255,.12); }}
    .passport-proof div {{ padding:15px; background:rgba(15,23,42,.96); }}
    .passport-proof b {{ display:block; color:#93c5fd; font-size:10px; letter-spacing:.12em; text-transform:uppercase; }}
    .passport-proof strong, .passport-proof code {{ display:block; margin-top:8px; color:#fff; font-size:15px; line-height:1.25; overflow-wrap:anywhere; }}
    .passport-proof small {{ display:block; margin-top:6px; color:#94a3b8; font-weight:800; }}
    .passport-strip {{ display:flex; flex-wrap:wrap; gap:8px; padding:12px 14px; background:linear-gradient(90deg,#1d4ed8,#0ea5e9,#22c55e,#f97316); }}
    .passport-strip span {{ color:white; font-size:11px; font-weight:950; letter-spacing:.08em; text-transform:uppercase; text-shadow:0 1px 2px rgba(0,0,0,.2); }}
    .safe-boundary {{ display:grid; grid-template-columns:repeat(3,1fr); gap:10px; margin-top:18px; }}
    .safe-boundary div {{ border:1px solid #d8e0ec; border-radius:12px; padding:12px; background:#ffffff; }}
    .safe-boundary b {{ display:block; color:#0f172a; }}
    .safe-boundary span {{ display:block; margin-top:5px; color:#6b7280; font-size:12px; font-weight:800; }}
    .share-preview {{ margin-top:18px; border:1px solid #d8e0ec; border-radius:14px; padding:14px; background:#f8fbff; }}
    .share-preview strong {{ display:block; color:#111827; }}
    .share-preview p {{ margin:8px 0 0; color:#374151; font-size:15px; }}
    .share-contract {{ display:grid; grid-template-columns:repeat(3,1fr); gap:10px; margin:18px 0 0; }}
    .share-contract div {{ border:1px solid #e5e7eb; border-radius:12px; padding:12px; background:white; }}
    .share-contract b {{ display:block; color:#111827; }}
    .share-contract span {{ display:block; margin-top:4px; color:#6b7280; font-size:12px; font-weight:800; }}
    .self-comparison {{ margin-top:22px; border:1px solid #d8e0ec; border-radius:18px; padding:18px; background:#ffffff; }}
    .self-comparison h3 {{ margin:0 0 8px; font-size:24px; }}
    .self-comparison p {{ margin:0 0 12px; font-size:14px; }}
    .self-comparison ul {{ grid-template-columns:repeat(2,1fr); }}
    .next-action-plan {{ margin-top:22px; border:1px solid #bed4ff; border-radius:18px; padding:18px; background:linear-gradient(135deg,#f7fbff,#ffffff); }}
    .next-action-plan h3 {{ margin:0 0 8px; font-size:24px; }}
    .next-action-plan p {{ margin:0 0 12px; font-size:14px; }}
    .next-action-plan > div {{ display:grid; grid-template-columns:repeat(3,1fr); gap:10px; }}
    .next-action-plan > div > div {{ border:1px solid #d8e5ff; border-radius:14px; padding:14px; background:white; }}
    .next-action-plan b {{ display:block; color:#2563eb; font-size:11px; letter-spacing:.08em; text-transform:uppercase; }}
    .next-action-plan code {{ display:block; margin-top:8px; padding:9px 10px; border:1px solid #e5edf8; border-radius:10px; background:#f8fbff; color:#111827; font-weight:850; overflow-wrap:anywhere; }}
    .next-action-plan span {{ display:block; margin-top:8px; color:#4b5563; font-size:13px; line-height:1.4; }}
    .next-action-plan small {{ display:block; margin-top:8px; color:#64748b; font-weight:800; line-height:1.35; }}
    .verification-receipt {{ margin-top:18px; border:1px solid #d8e0ec; border-radius:18px; padding:18px; background:#ffffff; }}
    .verification-receipt h3 {{ margin:0 0 8px; font-size:24px; }}
    .verification-receipt p {{ margin:0 0 12px; font-size:14px; }}
    .verification-receipt div {{ display:grid; grid-template-columns:repeat(5,1fr); gap:10px; }}
    .verification-receipt span {{ border:1px solid #e5e7eb; border-radius:12px; padding:12px; color:#4b5563; font-size:13px; font-weight:800; }}
    .verification-receipt b {{ display:block; margin-bottom:5px; color:#111827; font-size:11px; letter-spacing:.08em; text-transform:uppercase; }}
    .verification-receipt small {{ display:block; margin-top:12px; color:#6b7280; font-weight:800; line-height:1.45; }}
    .safe-evidence-receipt {{ margin-top:18px; border:1px solid #bbd4ff; border-radius:18px; padding:18px; background:#f7fbff; }}
    .safe-evidence-receipt h3 {{ margin:0 0 8px; font-size:24px; }}
    .safe-evidence-receipt p {{ margin:0 0 12px; font-size:14px; }}
    .safe-evidence-receipt > div {{ display:grid; grid-template-columns:1fr 1fr; gap:12px; }}
    .safe-evidence-receipt section {{ border:1px solid #d8e0ec; border-radius:14px; padding:14px; background:white; }}
    .safe-evidence-receipt section > b {{ display:block; margin-bottom:10px; color:#2563eb; font-size:11px; letter-spacing:.1em; text-transform:uppercase; }}
    .share-receipt {{ margin-top:18px; border:1px solid #c7d9ff; border-radius:18px; padding:18px; background:linear-gradient(135deg,#ffffff,#f7fbff); }}
    .share-receipt h3 {{ margin:0 0 8px; font-size:24px; }}
    .share-receipt p {{ margin:0 0 12px; font-size:14px; }}
    .share-receipt div {{ display:grid; grid-template-columns:repeat(3,1fr); gap:10px; }}
    .share-receipt span {{ border:1px solid #e5e7eb; border-radius:12px; padding:12px; color:#4b5563; font-size:13px; font-weight:800; }}
    .share-receipt b {{ display:block; margin-bottom:5px; color:#111827; font-size:11px; letter-spacing:.08em; text-transform:uppercase; }}
    .share-receipt ul {{ margin-top:12px; grid-template-columns:repeat(2,1fr); }}
    .shipped-work-receipt {{ margin-top:18px; border:1px solid #d8e0ec; border-radius:18px; padding:18px; background:linear-gradient(135deg,#ffffff,#f8fbff); }}
    .shipped-work-receipt h3 {{ margin:0 0 8px; font-size:24px; }}
    .shipped-work-receipt p {{ margin:0 0 12px; font-size:14px; }}
    .shipped-work-receipt > div {{ display:grid; grid-template-columns:repeat(2,1fr); gap:10px; }}
    .shipped-work-receipt > div > div {{ border:1px solid #e5e7eb; border-radius:14px; padding:14px; background:white; }}
    .shipped-work-receipt b {{ display:block; color:#2563eb; font-size:11px; letter-spacing:.08em; text-transform:uppercase; }}
    .shipped-work-receipt strong {{ display:block; margin-top:7px; color:#111827; font-size:18px; line-height:1.16; }}
    .shipped-work-receipt span {{ display:block; margin-top:7px; color:#4b5563; font-size:13px; line-height:1.4; }}
    .shipped-work-receipt small {{ display:block; margin-top:8px; color:#6b7280; font-size:10px; font-weight:850; letter-spacing:.05em; text-transform:uppercase; }}
    .reference-radar-panel {{ margin-top:18px; border:1px solid #c7d9ff; border-radius:18px; padding:18px; background:radial-gradient(circle at 18% 0%, #dbeafe, transparent 38%), linear-gradient(135deg,#ffffff,#f7fbff); }}
    .reference-radar-panel h3 {{ margin:0 0 8px; font-size:24px; }}
    .reference-radar-panel p {{ margin:0 0 12px; font-size:14px; }}
    .reference-radar-panel > div {{ display:grid; grid-template-columns:1.1fr 1fr 1fr; gap:10px; }}
    .reference-radar-panel section {{ border:1px solid #dbe7ff; border-radius:14px; padding:14px; background:white; }}
    .reference-radar-panel b {{ display:block; color:#2563eb; font-size:11px; letter-spacing:.08em; text-transform:uppercase; }}
    .reference-radar-panel strong {{ display:block; margin-top:8px; color:#111827; font-size:24px; line-height:1; }}
    .reference-radar-panel span {{ display:block; margin-top:8px; color:#4b5563; font-size:13px; line-height:1.4; }}
    .reference-radar-panel nav {{ display:flex; flex-wrap:wrap; gap:8px; margin-top:12px; }}
    .reference-radar-panel nav span {{ display:inline-flex; gap:8px; align-items:center; border:1px solid #d8e5ff; border-radius:999px; padding:8px 10px; background:#fff; color:#0f172a; font-size:12px; font-weight:900; }}
    .reference-radar-panel small {{ color:#64748b; font-size:11px; font-weight:950; }}
    .proof-links {{ display:flex; flex-wrap:wrap; gap:10px; margin:18px 0 28px; }}
    .proof-links a {{ color:#111827; text-decoration:none; border:1px solid #bed4ff; background:#f8fbff; border-radius:999px; padding:10px 13px; font-weight:900; }}
    .owner-card {{ display:grid; grid-template-columns:1fr auto; gap:18px; align-items:start; border:1px solid #d8e0ec; border-radius:20px; padding:18px; margin:22px 0; background:linear-gradient(135deg,#ffffff,#f8fbff); }}
    .owner-card span {{ display:block; color:#2563eb; font-size:11px; font-weight:950; letter-spacing:.12em; text-transform:uppercase; }}
    .owner-card strong {{ display:block; margin-top:6px; font-size:28px; line-height:1; }}
    .owner-card p {{ margin:10px 0 0; font-size:14px; }}
    .owner-links {{ display:flex; flex-wrap:wrap; gap:8px; justify-content:flex-end; max-width:320px; }}
    .owner-links a {{ color:#111827; text-decoration:none; border:1px solid #bed4ff; border-radius:999px; padding:8px 11px; background:#fff; font-weight:900; font-size:12px; }}
    .submission-card {{ display:grid; grid-template-columns:1.2fr .8fr; gap:18px; border:1px solid #d4e2f5; border-radius:20px; padding:18px; margin:0 0 22px; background:radial-gradient(circle at 10% 10%, rgba(37,99,235,.12), transparent 28%), linear-gradient(135deg,#ffffff,#f3f8ff); }}
    .submission-card span {{ display:block; color:#2563eb; font-size:11px; font-weight:950; letter-spacing:.12em; text-transform:uppercase; }}
    .submission-card strong {{ display:block; margin-top:7px; font-size:26px; line-height:1.05; color:#0f172a; }}
    .submission-card p {{ margin:10px 0 0; font-size:14px; }}
    .submission-card b {{ display:block; font-size:15px; }}
    .submission-card small {{ display:block; margin-top:5px; color:#64748b; font-weight:850; }}
    .submission-card nav {{ display:flex; flex-wrap:wrap; gap:8px; margin-top:12px; }}
    .submission-card nav a, .submission-card nav span {{ color:#111827; text-decoration:none; border:1px solid #bed4ff; border-radius:999px; padding:8px 11px; background:#fff; font-weight:900; font-size:12px; }}
    .submission-card em {{ display:block; margin-top:12px; color:#0f766e; font-size:12px; font-style:normal; font-weight:950; }}
    .profile-rank-context {{ margin-top:18px; border:1px solid #c7d9ff; border-radius:18px; padding:18px; background:linear-gradient(135deg,#f8fbff,#ffffff); }}
    .profile-rank-context h3 {{ margin:0 0 8px; font-size:24px; }}
    .profile-rank-context p {{ margin:0 0 12px; font-size:14px; }}
    .profile-rank-context > div {{ display:grid; grid-template-columns:repeat(3,1fr); gap:10px; }}
    .profile-rank-context > div > div {{ border:1px solid #dbe7ff; border-radius:14px; padding:14px; background:white; }}
    .profile-rank-context b {{ display:block; color:#2563eb; font-size:11px; letter-spacing:.08em; text-transform:uppercase; }}
    .profile-rank-context strong {{ display:block; margin-top:7px; color:#111827; font-size:24px; line-height:1; }}
    .profile-rank-context span {{ display:block; margin-top:7px; color:#4b5563; font-size:13px; line-height:1.4; }}
    .profile-rank-context small {{ display:block; margin-top:8px; color:#64748b; font-size:11px; font-weight:850; }}
    .correction-box {{ display:grid; gap:10px; border:1px solid #fed7aa; background:#fff7ed; padding:18px; margin:22px 0; }}
    .correction-box code {{ display:block; padding:12px 14px; border:1px solid #fdba74; background:white; font-weight:850; overflow-wrap:anywhere; }}
    li em {{ grid-column:1 / 3; color:#2563eb; font-style:normal; font-size:12px; font-weight:850; }}
    footer {{ margin-top:18px; color:#6b7280; font-size:13px; }}
    @media (max-width:760px) {{ h1 {{ font-size:40px; }} .meta, .brief, .submission-card, .passport-proof, .safe-boundary, .share-contract, .self-comparison ul, .next-action-plan > div, .verification-receipt div, .safe-evidence-receipt > div, .share-receipt div, .share-receipt ul, .shipped-work-receipt > div, .reference-radar-panel > div, .profile-rank-context > div {{ grid-template-columns:1fr; }} .passport-main strong {{ font-size:28px; }} }}
  </style>
</head>
<body>
  <main>
    <article class="card">
      <div class="brand"><div class="mark">tb</div><div>TokenBar public profile</div></div>
      <div class="doc-type">{report_kind}</div>
      <h1>{title}</h1>
      <p>{subtitle}</p>
      <div class="owner-card" aria-label="Builder owner profile">
        <div>
          <span>Builder profile</span>
          <strong>{owner_nickname}</strong>
          <p>@{owner_handle} · {owner_region}</p>
          <p>{owner_bio}</p>
        </div>
        <div class="owner-links">{owner_links or '<span>No public links attached</span>'}</div>
      </div>
      {submission_html}
      <div class="meta">
        <div><span>Archetype</span><strong>{archetype}</strong></div>
        <div><span>NPC class</span><strong>{npc}</strong></div>
        <div><span>Proof score</span><strong>{proof_score}/100</strong></div>
        <div><span>Loop maturity</span><strong>{loop_maturity}/100</strong></div>
      </div>
      <section class="story-card story-first" data-proof-profile="story-first">
        <h2>{story_headline}</h2>
        <p>{story_summary}</p>
        {identity_passport_html}
        {rank_context_html}
        <div class="brief" aria-label="Sixty second profile read">
          <div><b>What kind of builder?</b><span>{archetype} · {npc}</span></div>
          <div><b>What did they prove?</b><span>Safe proof score {proof_score}/100 with {loop_maturity}/100 loop maturity.</span></div>
          <div><b>What remains honest?</b><span>Public claims keep uncertainty and provenance visible.</span></div>
        </div>
        {self_comparison_html}
        {next_action_html}
        {shipped_work_html}
        {reference_radar_html}
        {share_receipt_html}
        {safe_receipt_html}
        {receipt_html}
        <div class="safe-boundary" aria-label="Safe evidence boundary">
          <div><b>No raw transcripts</b><span>Private prompts and agent messages stay local.</span></div>
          <div><b>No source code</b><span>Repos and secret files are not part of this public card.</span></div>
          <div><b>Safe aggregates only</b><span>Scores, labels, facts, action stages, and chosen links.</span></div>
        </div>
        {share_preview_html}
        <div class="share-contract" aria-label="Profile sharing modes">
          <div><b>Public</b><span>headline, proof score, safe facts</span></div>
          <div><b>Selective</b><span>axes, provenance, uncertainty</span></div>
          <div><b>Private</b><span>raw logs stay on device</span></div>
        </div>
      </section>
      <nav class="proof-links" aria-label="Proof navigation">{''.join(link_rows)}</nav>
      <div class="activation">
        <strong>Want the full memorandum PDF?</strong>
        <span>Run TokenBar locally. The website profile is activated by the token, but the PDF is generated on your machine from your private logs.</span>
        <code>{pdf_command}</code>
        <code>{share_command}</code>
      </div>
      <div class="correction-box">
        <strong>Report or correct this profile</strong>
        <span>If this identity is wrong, disputed, or should not be public, submit a correction with the token and a human explanation. Do not paste raw transcripts, source code, credentials, private diffs, or environment files.</span>
        <code>POST /api/report-feedback {html.escape(feedback_payload)}</code>
      </div>
      <h2>Safe Proof Facts</h2>
      <ul>{''.join(fact_rows) or "<li><b>No fact card metadata</b><span>legacy</span></li>"}</ul>
      <h2>Builder Identity Axes</h2>
      <ul>{''.join(axis_rows) or "<li><b>No story-axis metadata</b><span>legacy</span></li>"}</ul>
      <h2>What This Proves</h2>
      <ul>{''.join(proved_rows) or "<li><b>No proof claims attached yet</b><span>pending</span></li>"}</ul>
      <h2>What Remains Uncertain</h2>
      <ul>{''.join(uncertainty_rows) or "<li><b>Uncertainty metadata unavailable</b><span>pending</span></li>"}</ul>
      <h2>Next Frontier</h2>
      <div class="edge">{story_frontier}</div>
      <h2>Probability Map</h2>
      <ul>{''.join(rows)}</ul>
      <h2>Nearest Identity Buckets</h2>
      <ul>{''.join(bucket_rows) or "<li><b>No compositional bucket metadata</b><span>legacy</span></li>"}</ul>
      <h2>Component Probability Maps</h2>
      <ul>{''.join(modifier_rows) or "<li><b>No modifier metadata</b><span>legacy</span></li>"}</ul>
      <ul style="margin-top:10px">{''.join(stance_rows) or "<li><b>No stance metadata</b><span>legacy</span></li>"}</ul>
      <h2>Why This Label</h2>
      <div class="edge">{rationale_summary or "This profile was generated before label rationale metadata was added."}</div>
      <h2>Top Trait Drivers</h2>
      <ul>{''.join(driver_rows) or "<li><b>No driver metadata</b><span>legacy</span></li>"}</ul>
      <h2>Behavior Patterns</h2>
      <div class="edge">Operating mode: {operating_mode}</div>
      <ul style="margin-top:10px">{''.join(behavior_rows) or "<li><b>No behavior metadata</b><span>local only</span></li>"}</ul>
      <h2>Builder Loop Scale</h2>
      <ul>{''.join(loop_rows) or "<li><b>No loop scale metadata</b><span>legacy</span></li>"}</ul>
      <h2>Growth Edge</h2>
      <div class="edge">{growth}</div>
      <h2>Identity Bucket</h2>
      <p>{bucket or "Legacy profile without compositional bucket metadata."}</p>
      <p>{("Label space: " + possible_labels + " possible buckets.") if possible_labels else ""}</p>
      <h2>Opt-in Population Context</h2>
      <div class="meta">
        <div><span>Profiles</span><strong>{population_count}</strong></div>
        <div><span>Bucket share</span><strong>{bucket_share}%</strong></div>
        <div><span>Archetype share</span><strong>{archetype_share}%</strong></div>
        <div><span>Specificity percentile</span><strong>{specificity_percentile_text}</strong></div>
      </div>
      <p>NPC class share across opt-in profiles: {npc_share}%.</p>
    </article>
    <footer>
      Token: {token}. Public stats currently include {stats.get("profileCount", 0)} opt-in uploaded profiles.
      Raw transcripts and source code are not included in this public profile.
    </footer>
  </main>
</body>
</html>"""


class handler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        respond_json(self, 204, {})

    def do_GET(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        token = (query.get("token") or [""])[0].strip()

        if (query.get("health") or [""])[0] in {"1", "true", "yes"}:
            respond_json(self, 200, {"ok": True, "health": storage_health()})
            return

        if not token:
            try:
                profiles, storage = read_profiles()
            except Exception as exc:
                respond_json(self, 500, {"ok": False, "error": str(exc)})
                return
            respond_json(self, 200, {"ok": True, "stats": aggregate_stats(profiles, storage)})
            return

        try:
            profile, storage = get_profile(token)
            profiles, _ = read_profiles()
        except Exception as exc:
            respond_json(self, 500, {"ok": False, "error": str(exc)})
            return

        if not profile:
            profile = get_action_profile(token)
            if profile:
                profiles = {**profiles, token: profile}
                storage = "action-proof-card"
            else:
                respond_json(self, 404, {"ok": False, "error": "profile not found", "token": token})
                return
        else:
            action_profile = get_action_profile(token)
            if action_profile:
                for key in (
                    # The proof action is authoritative for the project attached
                    # to this TBAR token. Keep a cached profile from showing a
                    # previous project's title after the builder submits again.
                    "hackathonSubmission",
                    "submittedProject",
                    "projectTitle",
                    "event",
                    "track",
                    "repoUrl",
                    "demoUrl",
                    "shareReceipt",
                    "safeEvidenceReceipt",
                    "verificationReceipt",
                    "nextActionPlan",
                    "surfaceBundle",
                    "actionLinks",
                    "rankBadges",
                    "rankPlacements",
                    "builderStory",
                    "shippedWork",
                    "selfComparison",
                ):
                    if action_profile.get(key):
                        profile[key] = action_profile.get(key)
                profiles = {**profiles, token: profile}

        stats = aggregate_stats(profiles, storage)
        population = profile_population_context(profile, profiles)
        if "application/json" in self.headers.get("accept", ""):
            respond_json(self, 200, {"ok": True, "profile": profile, "stats": stats, "population": population})
        else:
            respond_html(self, 200, profile_html(profile, stats, population))

    def do_POST(self):
        try:
            length = int(self.headers.get("content-length", "0"))
        except ValueError:
            respond_json(self, 400, {"ok": False, "error": "bad content-length"})
            return
        if length <= 0 or length > MAX_BODY_BYTES:
            respond_json(self, 413, {"ok": False, "error": "profile payload too large"})
            return

        try:
            raw = json.loads(self.rfile.read(length).decode("utf-8"))
            if raw.get("schema") == "tokenbar.hackathon_submission_update.v1":
                token = str(raw.get("token") or "").strip()
                if not token.startswith("TBAR-") or len(token) < 10:
                    raise ValueError("missing TokenBar identity token")
                visibility = str(raw.get("visibility") or "public").lower()
                if visibility not in {"public", "listed", "unlisted", "private"}:
                    visibility = "public"
                existing, existing_storage = get_profile(token)
                if not existing:
                    existing = get_action_profile(token)
                    existing_storage = "action-proof-card"
                if not existing:
                    respond_json(self, 404, {"ok": False, "error": "profile token not found", "token": token})
                    return
                submission = clean_submission_metadata(
                    raw.get("hackathonSubmission") or raw.get("submittedProject") or raw,
                    fallback_title=str(existing.get("title") or existing.get("primaryArchetype") or "Submitted project"),
                )
                if not submission:
                    raise ValueError("submission metadata is unsafe or empty")
                profile = apply_submission_to_profile(existing, submission, visibility)
                storage = save_profile(profile)
                action_store_updated = update_action_submission(token, submission, visibility)
                profiles, _ = read_profiles()
                base = public_base(self)
                stats = aggregate_stats(profiles, storage)
                population = profile_population_context(profile, profiles)
                respond_json(
                    self,
                    200,
                    {
                        "ok": True,
                        "token": token,
                        "schema": "tokenbar.hackathon_submission_update.v1",
                        "submission": submission,
                        "profile": profile,
                        "shareUrl": f"{base}/api/profiles?token={quote(token)}",
                        "socialUrl": f"{base}/social?token={quote(token)}",
                        "rankingsUrl": f"{base}/rankings?token={quote(token)}",
                        "storage": storage,
                        "previousStorage": existing_storage,
                        "actionStoreUpdated": action_store_updated,
                        "stats": stats,
                        "population": population,
                    },
                )
                return
            profile = clean_profile(raw)
        except Exception as exc:
            respond_json(self, 400, {"ok": False, "error": str(exc)})
            return

        try:
            storage = save_profile(profile)
            profiles, _ = read_profiles()
        except Exception as exc:
            respond_json(self, 500, {"ok": False, "error": str(exc)})
            return

        base = public_base(self)
        stats = aggregate_stats(profiles, storage)
        population = profile_population_context(profile, profiles)
        respond_json(
            self,
            201,
            {
                "ok": True,
                "token": profile["token"],
                "shareUrl": f"{base}/api/profiles?token={profile['token']}",
                "statsUrl": f"{base}/api/profiles",
                "stats": stats,
                "population": population,
            },
        )
