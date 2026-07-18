#!/usr/bin/env python3
"""End-to-end local smoke for the TokenBar Builder Identity proof loop.

This intentionally uses localhost and temp JSON stores. It proves the judge path:
local identity artifact -> safe proof action -> proof/profile reload -> feed/rankings.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TOKENBAR = ROOT / "bin" / "tokenbar"
SERVER = ROOT / "scripts" / "tokenbar_local_server.py"


def support_profiles_dir() -> Path:
    return Path.home() / "Library/Application Support/CodexLimitBar/profiles"


def latest_identity() -> Path | None:
    candidates = sorted(support_profiles_dir().glob("*.identity.json"), key=lambda path: path.stat().st_mtime, reverse=True)
    return candidates[0] if candidates else None


def run(command: list[str], env: dict[str, str], timeout: int = 90) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=str(ROOT),
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=True,
    )


def get_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def get_text(url: str) -> str:
    request = urllib.request.Request(url, headers={"Accept": "text/html"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.read().decode("utf-8", "replace")


def get_status(url: str, accept: str = "application/json") -> tuple[int, str]:
    request = urllib.request.Request(url, headers={"Accept": accept})
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status, response.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", "replace")


def post_json(url: str, payload: dict) -> tuple[int, dict]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Accept": "application/json", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        try:
            return exc.code, json.loads(body)
        except Exception:
            return exc.code, {"ok": False, "raw": body}


def wait_for_server(base_url: str) -> None:
    deadline = time.time() + 10
    last_error: Exception | None = None
    while time.time() < deadline:
        try:
            payload = get_json(f"{base_url}/api/actions?health=1")
            if payload.get("ok"):
                return
        except Exception as exc:  # pragma: no cover - printed on timeout
            last_error = exc
        time.sleep(0.2)
    raise RuntimeError(f"local proof server did not become ready: {last_error}")


def require(condition: object, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    parser = argparse.ArgumentParser(description="Smoke-test the local TokenBar Builder Identity proof flow.")
    parser.add_argument("--port", type=int, default=8768)
    parser.add_argument("--cli", type=Path, default=DEFAULT_TOKENBAR, help="TokenBar CLI to exercise. Defaults to the repo launcher.")
    parser.add_argument("--identity", type=Path, help="Use a specific .identity.json instead of the latest local profile.")
    parser.add_argument(
        "--run-claim",
        action="store_true",
        default=True,
        help="Generate a fresh identity with tokenbar claim before publishing (default).",
    )
    parser.add_argument(
        "--use-existing-identity",
        dest="run_claim",
        action="store_false",
        help="Use --identity or the newest local identity instead of generating a deterministic smoke fixture.",
    )
    args = parser.parse_args()

    tokenbar_cli = args.cli.expanduser()
    if not tokenbar_cli.exists():
        raise SystemExit(f"missing CLI: {tokenbar_cli}")

    base_url = f"http://127.0.0.1:{args.port}"
    temp_dir = Path(tempfile.mkdtemp(prefix="tokenbar-builder-smoke-"))
    action_store = temp_dir / "action-store.json"
    profile_store = temp_dir / "profile-store.json"
    signal_store = temp_dir / "builder-signal-inbox.json"
    signal_home = temp_dir / "signal-home"
    env = os.environ.copy()
    env.update(
        {
            "TOKENBAR_LOCAL_SERVER_QUIET": "1",
            "TOKENBAR_ACTION_STORE_PATH": str(action_store),
            "TOKENBAR_PROFILE_STORE_PATH": str(profile_store),
        }
    )

    server = subprocess.Popen(
        [sys.executable, str(SERVER), "--port", str(args.port)],
        cwd=str(ROOT),
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )

    try:
        wait_for_server(base_url)

        # The inbox assertions below exercise the safe local-signal boundary in
        # both smoke modes. Keep this seed independent from --run-claim so the
        # default proof-card route remains deterministic.
        signal_seed_env = env | {"HOME": str(signal_home), "TOKENBAR_SIGNAL_STORE": str(signal_store)}
        saved = run(
            [
                str(tokenbar_cli),
                "save",
                "https://example.com/agent-loop",
                "--tag",
                "agent-loop",
                "--note",
                "reference for builder signal inbox",
            ],
            signal_seed_env,
            timeout=30,
        )
        require("Saved builder signal" in saved.stdout, "tokenbar save did not save a builder signal")
        require("Privacy: local only; no upload" in saved.stdout, "tokenbar save missing local-only privacy boundary")

        identity_path = args.identity
        claim_publish_stdout = ""
        if args.run_claim:
            before = latest_identity()
            claim_env = env | {
                "TOKENBAR_REPORT_NAME": "TokenBar Local Smoke",
                "TOKENBAR_ACTION_URL": f"{base_url}/api/actions",
                "TOKENBAR_PROFILE_UPLOAD_URL": f"{base_url}/api/profiles",
                "TOKENBAR_SIGNAL_STORE": str(signal_store),
                "TOKENBAR_PUBLIC_HANDLE": "tokenbar-smoke",
                "TOKENBAR_PUBLIC_REGION": "Singapore",
                "TOKENBAR_PUBLIC_GITHUB": "https://github.com/Arnie016/TokenBar",
                "TOKENBAR_PUBLIC_WEBSITE": "https://tokenbar-umber.vercel.app",
                "TOKENBAR_HACKATHON_EVENT": "TokenBar Smoke Hackathon",
                "TOKENBAR_PROJECT_TITLE": "Smoke Proof Repo",
                "TOKENBAR_PROJECT_TAGLINE": "Safe repo submission without raw upload",
                "TOKENBAR_PROJECT_REPO": "https://github.com/Arnie016/TokenBar",
                "TOKENBAR_PROJECT_DEMO": "https://tokenbar-umber.vercel.app/social",
                "TOKENBAR_PROJECT_TRACK": "Builder Identity",
            }
            claim = run([str(tokenbar_cli), "prove"], claim_env, timeout=180)
            claim_publish_stdout = claim.stdout
            require("Private builder claim is ready." in claim.stdout, "claim output missing private-ready state")
            require("Nothing public was uploaded." in claim.stdout, "claim output missing privacy default")
            require("tokenbar publish-proof" in claim.stdout, "prove output missing safe proof command")
            require("This returns a TBAR token plus proof/profile/social/rankings links." in claim.stdout, "claim output missing proof destination explanation")
            require(f"{base_url}/profile" in claim.stdout, "claim output missing exact profile URL")
            require(f"{base_url}/social" in claim.stdout, "claim output missing exact social URL")
            require(f"{base_url}/rankings" in claim.stdout, "claim output missing exact rankings URL")
            require("Builder proof run:" in claim.stdout, "prove did not run the proof action")
            require("Proof card:" in claim.stdout, "prove did not print a proof card")
            require("Safe token:" in claim.stdout, "prove did not print a safe token")
            require("Proof bundle:" in claim.stdout, "prove did not print a proof bundle")
            require("Public profile:" in claim.stdout, "prove did not print a public profile bundle link")
            require("For You feed:" in claim.stdout, "prove did not print a feed bundle link")
            require("Leaderboards:" in claim.stdout, "prove did not print a leaderboard bundle link")
            require("Loop rankings:" in claim.stdout, "prove did not print a loop ranking bundle link")
            after = latest_identity()
            require(after and after != before, "tokenbar claim did not create a fresh identity JSON")
            identity_path = after
        elif not identity_path:
            identity_path = latest_identity()

        require(identity_path and identity_path.exists(), "no identity JSON available; run with --run-claim")
        identity = json.loads(identity_path.read_text(encoding="utf-8"))
        require(not (identity.get("privacy") or {}).get("rawTranscriptsIncluded"), "identity claims raw transcripts are included")
        require(not (identity.get("privacy") or {}).get("sourceCodeIncluded"), "identity claims source code is included")
        submission = identity.get("hackathonSubmission") or {}
        require(submission.get("schema") == "tokenbar.hackathon_submission.v1", "identity missing hackathon submission passport")
        require(submission.get("projectTitle") == "Smoke Proof Repo", "identity missing submitted project title")
        require((submission.get("privacy") or {}).get("rawRepoUploaded") is False, "identity submission claims raw repo upload")
        require((submission.get("privacy") or {}).get("sourceCodeUploaded") is False, "identity submission claims source code upload")
        require((submission.get("privacy") or {}).get("rawTranscriptsUploaded") is False, "identity submission claims raw transcript upload")
        builder_signals = identity.get("builderSignalInbox") or {}
        require(builder_signals.get("schema") == "tokenbar.builder_signal_summary.v1", "identity missing builder signal summary")
        if args.run_claim:
            require(builder_signals.get("signalCount", 0) >= 1, "builder signal summary did not capture saved local signals")
            require((builder_signals.get("privacy") or {}).get("urlsIncluded") is False, "builder signal summary must not include URLs")
            require((builder_signals.get("privacy") or {}).get("titlesIncluded") is False, "builder signal summary must not include titles")
            require((builder_signals.get("privacy") or {}).get("notesIncluded") is False, "builder signal summary must not include notes")
        identity.setdefault("publicProfile", {})
        identity["publicProfile"].update(
            {
                "handle": "tokenbar-smoke",
                "nickname": "TokenBar Smoke Builder",
                "region": "Singapore",
                "bio": "Local smoke profile proving safe public metadata, profile links, and social proof surfaces.",
                "links": {
                    "github": "https://github.com/Arnie016/TokenBar",
                    "website": "https://tokenbar-umber.vercel.app",
                },
                "rawLogsShared": False,
                "sourceCodeShared": False,
            }
        )
        smoke_identity_path = temp_dir / "smoke-public-profile.identity.json"
        smoke_identity_path.write_text(json.dumps(identity, indent=2, sort_keys=True), encoding="utf-8")
        identity_path = smoke_identity_path

        publish_env = env | {
            "TOKENBAR_ACTION_URL": f"{base_url}/api/actions",
            "TOKENBAR_PROFILE_UPLOAD_URL": f"{base_url}/api/profiles",
        }
        quickstart = run([str(tokenbar_cli), "quickstart"], publish_env, timeout=90)
        help_output = run([str(tokenbar_cli), "help"], publish_env, timeout=90)
        require("tokenbar prove" in help_output.stdout, "help output missing prove shortcut")
        require("tokenbar join" in help_output.stdout, "help output missing social board join command")
        require("tokenbar submit" in help_output.stdout, "help output missing hackathon repo submit command")
        require("tokenbar video" in help_output.stdout, "help output missing video brief command")
        require("tokenbar save URL" in help_output.stdout, "help output missing local builder-signal save command")
        require("tokenbar inbox" in help_output.stdout, "help output missing local builder-signal inbox command")
        require("tokenbar claim --publish-proof" in help_output.stdout, "help output missing claim publish-proof path")
        require("Advanced legacy profile JSON upload" in help_output.stdout, "help output missing legacy upload wording")
        quickstart_text = quickstart.stdout
        require("Social / hackathon path" in quickstart_text, "quickstart output missing social/hackathon path")
        require('tokenbar join --project "My Codex App"' in quickstart_text, "quickstart output missing join project command")
        join_help = run([str(tokenbar_cli), "join", "--help"], publish_env, timeout=90)
        require("Usage:\n  tokenbar submit" in join_help.stdout, "join help does not route to submit usage")
        require("The command prints a TBAR token plus profile, feed, and leaderboard links." in join_help.stdout, "join help missing social proof output contract")
        status_output = run([str(tokenbar_cli), "status"], publish_env, timeout=90)
        require("Next:" in status_output.stdout, "status output missing next-step block")
        require("tokenbar claim" in status_output.stdout, "status output missing private claim path")
        require("tokenbar prove" in status_output.stdout, "status output missing safe proof token path")
        require("tokenbar social" in status_output.stdout, "status output missing social surface path")
        require("tokenbar save URL" in status_output.stdout, "status output missing local builder reference save path")
        require("raw transcripts" in status_output.stdout and "source code" in status_output.stdout, "status output missing privacy boundary")
        require("tokenbar prove" in quickstart.stdout, "quickstart missing prove shortcut")
        require(f"{base_url}/profile" in quickstart.stdout, "quickstart missing exact local profile URL")
        require(f"{base_url}/social" in quickstart.stdout, "quickstart missing exact local social URL")
        require(f"{base_url}/rankings" in quickstart.stdout, "quickstart missing exact local rankings URL")
        require("Paste the returned TBAR token into the website" in quickstart.stdout, "quickstart missing token handoff instruction")
        video_output = run([str(tokenbar_cli), "video"], publish_env, timeout=90)
        require("HyperFrames-ready" in video_output.stdout, "video output missing HyperFrames direction")
        require("No raw prompts" in video_output.stdout and "source code" in video_output.stdout, "video output missing privacy boundary")
        require("Shot list" in video_output.stdout, "video output missing shot list")
        video_json = run([str(tokenbar_cli), "video", "--json"], publish_env, timeout=90)
        video_payload = json.loads(video_json.stdout)
        require(video_payload.get("schema") == "tokenbar.video_brief.v1", "video JSON missing schema")
        require(video_payload.get("renderer") == "HyperFrames", "video JSON missing renderer hint")
        require(len(video_payload.get("shots") or []) >= 5, "video JSON missing shot list")
        require(video_payload.get("privacy", {}).get("rawTranscriptsIncluded") is False, "video JSON should exclude raw transcripts")
        require(video_payload.get("privacy", {}).get("sourceCodeIncluded") is False, "video JSON should exclude source code")
        signal_env = publish_env | {"HOME": str(signal_home), "TOKENBAR_SIGNAL_STORE": str(signal_store)}
        inbox = run([str(tokenbar_cli), "inbox", "digest"], signal_env, timeout=30)
        require("TokenBar builder signal inbox" in inbox.stdout, "tokenbar inbox missing heading")
        require("Saved signals: 1" in inbox.stdout, "tokenbar inbox did not list saved signal count")
        require("agent-loop" in inbox.stdout, "tokenbar inbox missing saved tag")
        inbox_json = run([str(tokenbar_cli), "inbox", "--json"], signal_env, timeout=30)
        inbox_payload = json.loads(inbox_json.stdout)
        require(inbox_payload.get("schema") == "tokenbar.builder_signal_inbox.v1", "tokenbar inbox JSON missing schema")
        require((inbox_payload.get("items") or [{}])[0].get("privacy", {}).get("networkUploaded") is False, "builder signal inbox should be local-only")
        publish = (
            subprocess.CompletedProcess([str(tokenbar_cli), "prove"], 0, claim_publish_stdout, "")
            if claim_publish_stdout
            else run([str(tokenbar_cli), "publish-proof", str(identity_path)], publish_env, timeout=90)
        )
        run_match = re.search(r"Builder proof run:\s*(run_[A-Za-z0-9._-]+)", publish.stdout)
        token_match = re.search(r"Proof card:\s*.*token=(TBAR-[A-Z0-9]+)", publish.stdout)
        require(run_match, f"publish-proof did not print a run id:\n{publish.stdout}")
        require(token_match, f"publish-proof did not print a proof-card token:\n{publish.stdout}")
        require("Safe token:" in publish.stdout, "publish-proof did not print a safe token")
        require("Proof bundle:" in publish.stdout, "publish-proof did not print a proof bundle")
        require("Public profile:" in publish.stdout, "publish-proof did not print a public profile bundle link")
        require("For You feed:" in publish.stdout, "publish-proof did not print a feed bundle link")
        require("Leaderboards:" in publish.stdout, "publish-proof did not print a leaderboard bundle link")
        require("Loop rankings:" in publish.stdout, "publish-proof did not print a loop ranking bundle link")
        require("Share receipt:" in publish.stdout, "publish-proof did not print a share receipt")
        require("Local receipt:" in publish.stdout, "publish-proof did not persist a local proof receipt")
        require("tokenbar proof latest" in publish.stdout, "publish-proof did not print the proof receipt recovery command")

        run_id = run_match.group(1)
        token = token_match.group(1)
        latest_proof = run([str(tokenbar_cli), "proof", "latest"], publish_env, timeout=90)
        require(token in latest_proof.stdout, "proof latest did not reprint the safe token")
        require(run_id in latest_proof.stdout, "proof latest did not reprint the action run id")
        require("Latest safe TokenBar proof" in latest_proof.stdout, "proof latest missing heading")
        require("Paste this token" in latest_proof.stdout, "proof latest missing web token handoff")
        require("Use it on /profile" in latest_proof.stdout, "proof latest missing profile paste destination")
        require("Use it on /social" in latest_proof.stdout, "proof latest missing social paste destination")
        require("Use it on /rankings" in latest_proof.stdout, "proof latest missing rankings paste destination")
        require("Proof card:" in latest_proof.stdout, "proof latest missing proof-card URL")
        require("Public profile:" in latest_proof.stdout, "proof latest missing public-profile URL")
        require("For You feed:" in latest_proof.stdout, "proof latest missing social feed URL")
        require("Leaderboards:" in latest_proof.stdout, "proof latest missing leaderboard URL")
        require("Share receipt" in latest_proof.stdout, "proof latest missing share receipt")
        require("Raw transcripts uploaded: no" in latest_proof.stdout, "proof latest missing raw transcript boundary")
        require("Source code uploaded: no" in latest_proof.stdout, "proof latest missing source code boundary")
        require("Submitting a hackathon repo?" in latest_proof.stdout, "proof latest missing hackathon submission recovery path")
        require('tokenbar submit --project "My Codex App"' in latest_proof.stdout, "proof latest missing submit command")
        require("Raw prompts, transcripts, source code, and secrets still stay local" in latest_proof.stdout, "proof latest missing local-first submit boundary")
        latest_json = run([str(tokenbar_cli), "proof", "latest", "--json"], publish_env, timeout=90)
        local_receipt = json.loads(latest_json.stdout)
        require(local_receipt.get("schema") == "tokenbar.local_proof_receipt.v1", "proof latest JSON missing receipt schema")
        require(local_receipt.get("token") == token, "proof latest JSON token mismatch")
        require(local_receipt.get("runId") == run_id, "proof latest JSON run mismatch")
        require((local_receipt.get("privacy") or {}).get("rawTranscriptsUploaded") is False, "local receipt raw transcript boundary is not false")
        require((local_receipt.get("privacy") or {}).get("sourceCodeUploaded") is False, "local receipt source code boundary is not false")
        require({"proofCard", "publicProfile", "socialFeed", "rankings", "loopRankings"}.issubset(set((local_receipt.get("surfaces") or {}).keys())), "local receipt missing safe surface links")
        local_surfaces = local_receipt.get("surfaces") or {}
        require(f"/social?token={token}" in local_surfaces.get("socialFeed", ""), "local receipt social URL missing token handoff")
        require(f"/rankings?token={token}" in local_surfaces.get("rankings", ""), "local receipt rankings URL missing token handoff")
        require(f"/rankings?token={token}#loop" in local_surfaces.get("loopRankings", ""), "local receipt loop rankings URL missing token handoff")
        run_payload = get_json(f"{base_url}/api/actions?run={run_id}")
        proof_payload = get_json(f"{base_url}/api/actions?token={token}")
        profile_payload = get_json(f"{base_url}/api/profiles?token={token}")
        feed_payload = get_json(f"{base_url}/api/actions")

        proof = proof_payload.get("proof") or {}
        profile = profile_payload.get("profile") or {}
        feed = feed_payload.get("feed") or []
        public_runs = feed_payload.get("runs") or []
        loops = feed_payload.get("loopRankings") or []
        leaderboards = feed_payload.get("leaderboards") or {}
        regional_leaderboards = feed_payload.get("regionalLeaderboards") or {}
        share_contract = feed_payload.get("shareContract") or {}
        first = feed[0] if feed else {}
        public_run_ids = {str(item.get("runId") or "") for item in public_runs if isinstance(item, dict)}

        require(run_payload.get("run", {}).get("status") == "complete", "action run did not reload complete")
        require(len(run_payload.get("run", {}).get("stages") or []) >= 6, "action run does not show six stages")
        require(proof.get("token") == token, "proof token mismatch")
        require(profile.get("title"), "public profile fallback did not load")
        require(not (profile.get("privacy") or {}).get("rawTranscriptsIncluded"), "public profile exposes raw transcripts")
        require(not (profile.get("privacy") or {}).get("sourceCodeIncluded"), "public profile exposes source code")
        proof_submission = proof.get("hackathonSubmission") or {}
        profile_submission = profile.get("hackathonSubmission") or {}
        feed_submission = first.get("hackathonSubmission") or {}
        require(proof_submission.get("projectTitle") == "Smoke Proof Repo", "proof card missing submitted project title")
        require(profile_submission.get("event") == "TokenBar Smoke Hackathon", "public profile missing submitted event")
        require(feed_submission.get("track") == "Builder Identity", "feed item missing submitted track")
        require(first.get("projectTitle") == "Smoke Proof Repo", "feed item missing project title shortcut")
        require((feed_payload.get("submissionEvents") or {}).get("TokenBar Smoke Hackathon") == 1, "action feed missing submission event count")
        require((feed_payload.get("submissionTracks") or {}).get("Builder Identity") == 1, "action feed missing submission track count")
        submit_status, submit_payload = post_json(
            f"{base_url}/api/profiles",
            {
                "schema": "tokenbar.hackathon_submission_update.v1",
                "token": token,
                "visibility": "public",
                "hackathonSubmission": {
                    "schema": "tokenbar.hackathon_submission.v1",
                    "event": "Browser Intake Hackathon",
                    "projectTitle": "Browser Submitted Proof",
                    "tagline": "Attached from a TBAR token without uploading source.",
                    "track": "Social proof",
                    "repoUrl": "https://github.com/Arnie016/TokenBar",
                    "demoUrl": "https://tokenbar-umber.vercel.app",
                    "submittedAt": "2026-07-18T00:00:00Z",
                    "privacy": {
                        "rawRepoUploaded": False,
                        "sourceCodeUploaded": False,
                        "rawTranscriptsUploaded": False,
                        "publicMetadataOnly": True,
                    },
                },
            },
        )
        require(submit_status == 200 and submit_payload.get("ok"), f"browser submission update failed: {submit_payload}")
        require(submit_payload.get("actionStoreUpdated") is True, "browser submission update did not update action proof store")
        require(f"/social?token={token}" in submit_payload.get("socialUrl", ""), "browser submission update social URL missing token handoff")
        require(f"/rankings?token={token}" in submit_payload.get("rankingsUrl", ""), "browser submission update rankings URL missing token handoff")
        updated_profile_payload = get_json(f"{base_url}/api/profiles?token={token}")
        updated_feed_payload = get_json(f"{base_url}/api/actions")
        updated_profile = updated_profile_payload.get("profile") or {}
        updated_first = (updated_feed_payload.get("feed") or [{}])[0]
        require((updated_profile.get("hackathonSubmission") or {}).get("projectTitle") == "Browser Submitted Proof", "profile did not persist browser-submitted project")
        require((updated_first.get("hackathonSubmission") or {}).get("event") == "Browser Intake Hackathon", "action feed did not reload browser-submitted project")
        reject_status, reject_payload = post_json(
            f"{base_url}/api/profiles",
            {
                "schema": "tokenbar.hackathon_submission_update.v1",
                "token": token,
                "hackathonSubmission": {
                    "projectTitle": "Unsafe Upload Attempt",
                    "privacy": {
                        "rawRepoUploaded": True,
                        "sourceCodeUploaded": True,
                        "rawTranscriptsUploaded": True,
                    },
                },
            },
        )
        require(reject_status == 400 and not reject_payload.get("ok"), "unsafe submission metadata was not rejected")
        proof_owner = proof.get("ownerProfile") or {}
        profile_owner = profile.get("publicProfile") or {}
        require(proof_owner.get("handle") == "tokenbar-smoke", "proof card did not preserve owner handle")
        require(proof_owner.get("region") == "Singapore", "proof card did not preserve owner region")
        require((proof_owner.get("links") or {}).get("github") == "https://github.com/Arnie016/TokenBar", "proof card did not preserve safe GitHub link")
        require(profile_owner.get("handle") == "tokenbar-smoke", "public profile did not preserve owner handle")
        require((profile_owner.get("links") or {}).get("website") == "https://tokenbar-umber.vercel.app", "public profile did not preserve safe website link")
        proof_signals = proof.get("builderSignalInbox") or {}
        profile_signals = profile.get("builderSignalInbox") or {}
        require(proof_signals.get("schema") == "tokenbar.builder_signal_summary.v1", "proof card missing builder signal summary")
        require(profile_signals.get("schema") == "tokenbar.builder_signal_summary.v1", "public profile missing builder signal summary")
        require(proof_signals.get("signalCount", 0) >= 1, "proof card builder signal summary missing saved signal count")
        require(profile_signals.get("signalCount", 0) >= 1, "public profile builder signal summary missing saved signal count")
        require((proof_signals.get("privacy") or {}).get("urlsIncluded") is False, "proof card builder signals include raw URLs")
        require((profile_signals.get("privacy") or {}).get("urlsIncluded") is False, "public profile builder signals include raw URLs")
        require("example.com" in {item.get("name") for item in (proof_signals.get("topHosts") or []) if isinstance(item, dict)}, "proof card builder signals missing aggregate host")
        proof_rank_badges = proof.get("rankBadges") or []
        require(proof_rank_badges, "proof card token lookup missing public rank badges")
        require(any((badge.get("key") == "global") for badge in proof_rank_badges if isinstance(badge, dict)), "proof card missing global rank badge")
        require(any((badge.get("key") == "loop") for badge in proof_rank_badges if isinstance(badge, dict)), "proof card missing loop rank badge")
        profile_rank_badges = profile.get("rankBadges") or []
        profile_rank_keys = {badge.get("key") for badge in profile_rank_badges if isinstance(badge, dict)}
        require(
            {"global", "loop", "region:Singapore", "region:Southeast Asia"}.issubset(profile_rank_keys),
            f"public profile JSON missing global/loop/regional rank badges: {sorted(profile_rank_keys)}",
        )
        require((profile.get("rankPlacements") or {}).get("global", {}).get("rank") == 1, "public profile JSON missing global rank placement")
        require((proof.get("selfComparison") or {}).get("cards"), "proof card missing self-over-time comparison")
        require((profile.get("selfComparison") or {}).get("cards"), "public profile JSON missing self-over-time comparison")
        require((proof.get("builderStory") or {}).get("shippedWork"), "proof story missing shipped-work receipt")
        require(profile.get("shippedWork"), "public profile JSON missing shipped-work receipt")
        next_plan = proof.get("nextActionPlan") or {}
        profile_next_plan = profile.get("nextActionPlan") or {}
        require(next_plan.get("schema") == "tokenbar.next_action_plan.v1", "proof card missing next-action plan")
        require(profile_next_plan.get("schema") == "tokenbar.next_action_plan.v1", "public profile JSON missing next-action plan")
        require(len(next_plan.get("actions") or []) >= 3, "next-action plan missing act/verify/share actions")
        require((next_plan.get("privacyBoundary") or {}).get("rawTranscriptsRequired") is False, "next-action plan requires raw transcripts")
        require((next_plan.get("privacyBoundary") or {}).get("sourceCodeRequired") is False, "next-action plan requires source code")
        receipt = proof.get("verificationReceipt") or {}
        profile_receipt = profile.get("verificationReceipt") or {}
        safe_receipt = proof.get("safeEvidenceReceipt") or {}
        profile_safe_receipt = profile.get("safeEvidenceReceipt") or {}
        share_receipt = proof.get("shareReceipt") or {}
        profile_share_receipt = profile.get("shareReceipt") or {}
        require(receipt.get("schema") == "tokenbar.verification_receipt.v1", "proof card missing verification receipt")
        require((receipt.get("privacyBoundary") or {}).get("rawTranscriptsIncluded") is False, "receipt raw transcript boundary is not false")
        require((receipt.get("privacyBoundary") or {}).get("sourceCodeIncluded") is False, "receipt source code boundary is not false")
        require((receipt.get("rankingPolicy") or {}).get("tokensWeight") == 0.06, "receipt missing capped token ranking policy")
        require(receipt.get("stageCount", 0) >= 6, "receipt missing completed action stage count")
        require(profile_receipt.get("schema") == "tokenbar.verification_receipt.v1", "public profile JSON missing verification receipt")
        require(safe_receipt.get("schema") == "tokenbar.safe_evidence_receipt.v1", "proof card missing safe evidence receipt")
        require(profile_safe_receipt.get("schema") == "tokenbar.safe_evidence_receipt.v1", "public profile JSON missing safe evidence receipt")
        require((safe_receipt.get("privacyBoundary") or {}).get("rawTranscriptsIncluded") is False, "safe evidence receipt raw transcript boundary is not false")
        require((safe_receipt.get("privacyBoundary") or {}).get("sourceCodeIncluded") is False, "safe evidence receipt source code boundary is not false")
        require({"raw transcripts", "source code", "credentials"}.issubset(set(safe_receipt.get("neverUsed") or [])), "safe evidence receipt missing never-used private data classes")
        require(safe_receipt.get("publicMaterial"), "safe evidence receipt missing public material summary")
        require(share_receipt.get("schema") == "tokenbar.share_receipt.v1", "proof card missing share receipt")
        require(profile_share_receipt.get("schema") == "tokenbar.share_receipt.v1", "public profile JSON missing share receipt")
        require(share_receipt.get("token") == token, "share receipt token mismatch")
        require(share_receipt.get("shareMode") == "public", "share receipt did not persist public share mode")
        require((share_receipt.get("privacyBoundary") or {}).get("rawTranscriptsIncluded") is False, "share receipt raw transcript boundary is not false")
        require((share_receipt.get("privacyBoundary") or {}).get("sourceCodeIncluded") is False, "share receipt source code boundary is not false")
        require({"raw transcripts", "source code", "credentials"}.issubset(set(share_receipt.get("neverPublic") or [])), "share receipt missing never-public data classes")
        require("public proof card" in str(share_receipt.get("publicMaterial") or "").lower(), "share receipt missing public proof surface summary")
        require("copySafeSummary" in share_receipt and "source code" in share_receipt.get("copySafeSummary", "").lower(), "share receipt missing copy-safe privacy summary")
        surface_bundle = profile.get("surfaceBundle") or {}
        surfaces = surface_bundle.get("surfaces") or []
        surface_keys = {item.get("key") for item in surfaces if isinstance(item, dict)}
        surface_urls = {item.get("key"): item.get("url") for item in surfaces if isinstance(item, dict)}
        require(surface_bundle.get("schema") == "tokenbar.surface_bundle.v1", "public profile missing surface bundle schema")
        require(
            {"proofCard", "publicProfile", "socialFeed", "rankings", "loopRankings"}.issubset(surface_keys),
            "surface bundle missing proof/profile/feed/ranking links",
        )
        require(f"/social?token={token}" in surface_urls.get("socialFeed", ""), "surface bundle social feed link does not carry token")
        require(f"/rankings?token={token}" in surface_urls.get("rankings", ""), "surface bundle rankings link does not carry token")
        require(f"/rankings?token={token}#loop" in surface_urls.get("loopRankings", ""), "surface bundle loop ranking link does not carry token")
        require(f"/social?token={token}" in profile.get("socialUrl", ""), "public profile social URL does not carry token")
        require(f"/rankings?token={token}" in profile.get("rankingsUrl", ""), "public profile rankings URL does not carry token")
        bundle_boundary = surface_bundle.get("privacyBoundary") or {}
        require(bundle_boundary.get("rawTranscriptsIncluded") is False, "surface bundle raw transcript boundary is not false")
        require(bundle_boundary.get("sourceCodeIncluded") is False, "surface bundle source code boundary is not false")
        require(run_id in public_run_ids, "public run did not appear in public action index")
        require(share_contract.get("schema") == "tokenbar.share_contract.v1", "action feed missing share contract")
        require(share_contract.get("publicProofCount", 0) >= 1, "share contract did not count public proofs")
        require(share_contract.get("publicIncludedInFeed") is True, "share contract does not include public proofs in feed")
        require(share_contract.get("unlistedIncludedInFeed") is False, "share contract allows unlisted proofs into feed")
        require(share_contract.get("privateIncludedInFeed") is False, "share contract allows private proofs into feed")
        require("public proof cards only" in str(share_contract.get("leaderboardsUse") or "").lower(), "share contract missing public-only leaderboard policy")
        never_public = set(share_contract.get("neverPublic") or [])
        require({"rawTranscripts", "sourceCode", "credentials", "envFiles"}.issubset(never_public), "share contract missing never-public data classes")
        public_claims = set(share_contract.get("publicClaims") or [])
        require({"feedStory", "shippedWork", "nextActionPlan", "verificationReceipt", "shareReceipt"}.issubset(public_claims), "share contract missing safe public claim classes")
        require(first.get("proofCardUrl") and first.get("profileUrl"), "feed item missing proof/profile links")
        require(first.get("shareUrl") and first.get("shareCopy"), "feed item missing share URL/copy")
        require("no raw transcripts" in first.get("shareCopy", "").lower(), "share copy missing raw transcript boundary")
        require("source code" in first.get("shareCopy", "").lower(), "share copy missing source-code boundary")
        require(first.get("rankingsUrl") and first.get("loopRankingsUrl"), "feed item missing ranking links")
        require(f"/social?token={token}" in first.get("socialUrl", ""), "feed item social URL missing token handoff")
        require(f"/rankings?token={token}" in first.get("rankingsUrl", ""), "feed item rankings URL missing token handoff")
        require(f"/rankings?token={token}#loop" in first.get("loopRankingsUrl", ""), "feed item loop rankings URL missing token handoff")
        require(first.get("handle") == "tokenbar-smoke", "feed item missing owner handle")
        require(first.get("region") == "Singapore", "feed item missing owner region")
        require((first.get("profileLinks") or {}).get("github") == "https://github.com/Arnie016/TokenBar", "feed item missing owner GitHub link")
        feed_rank_badges = first.get("rankBadges") or []
        feed_rank_keys = {badge.get("key") for badge in feed_rank_badges if isinstance(badge, dict)}
        require({"global", "loop", "region:Singapore", "region:Southeast Asia"}.issubset(feed_rank_keys), "feed item missing global/loop/regional rank badges")
        require((first.get("rankPlacements") or {}).get("global", {}).get("rank") == 1, "feed item missing global rank placement")
        feed_surface_bundle = first.get("surfaceBundle") or {}
        feed_safe_receipt = first.get("safeEvidenceReceipt") or {}
        feed_share_receipt = first.get("shareReceipt") or {}
        feed_next_plan = first.get("nextActionPlan") or {}
        feed_surface_keys = {
            item.get("key")
            for item in (feed_surface_bundle.get("surfaces") or [])
            if isinstance(item, dict)
        }
        require(feed_surface_bundle.get("schema") == "tokenbar.surface_bundle.v1", "feed item missing surface bundle schema")
        require(
            {"proofCard", "publicProfile", "socialFeed", "rankings", "loopRankings"}.issubset(feed_surface_keys),
            "feed item surface bundle missing proof/profile/feed/ranking links",
        )
        feed_bundle_boundary = feed_surface_bundle.get("privacyBoundary") or {}
        require(feed_bundle_boundary.get("rawTranscriptsIncluded") is False, "feed surface bundle raw transcript boundary is not false")
        require(feed_bundle_boundary.get("sourceCodeIncluded") is False, "feed surface bundle source code boundary is not false")
        require(feed_safe_receipt.get("schema") == "tokenbar.safe_evidence_receipt.v1", "feed item missing safe evidence receipt")
        require("raw transcripts" in set(feed_safe_receipt.get("neverUsed") or []), "feed safe evidence receipt missing raw transcript exclusion")
        feed_signals = first.get("builderSignalInbox") or {}
        require(feed_signals.get("schema") == "tokenbar.builder_signal_summary.v1", "feed item missing builder signal summary")
        require(feed_signals.get("signalCount", 0) >= 1, "feed item builder signal summary missing saved signal count")
        require((feed_signals.get("privacy") or {}).get("urlsIncluded") is False, "feed item builder signals include raw URLs")
        require("aggregate builder-signal hosts and tags" in set(feed_safe_receipt.get("usedEvidence") or []), "feed safe evidence receipt missing builder-signal evidence class")
        require(feed_share_receipt.get("schema") == "tokenbar.share_receipt.v1", "feed item missing share receipt")
        require(feed_share_receipt.get("shareMode") == "public", "feed share receipt did not persist public share mode")
        require("raw transcripts" in set(feed_share_receipt.get("neverPublic") or []), "feed share receipt missing raw transcript exclusion")
        require(feed_next_plan.get("schema") == "tokenbar.next_action_plan.v1", "feed item missing next-action plan")
        require(len(feed_next_plan.get("actions") or []) >= 3, "feed next-action plan missing act/verify/share actions")
        require(first.get("whatRemainsUncertain"), "feed item missing uncertainty copy")
        feed_story = first.get("feedStory") or {}
        require(feed_story.get("whatShipped"), "feed item missing story card shipped summary")
        require(feed_story.get("whyItMatters"), "feed item missing story card why-it-matters copy")
        require(feed_story.get("tradeoff"), "feed item missing story card tradeoff copy")
        require("no raw transcripts" in str(feed_story.get("provenance") or "").lower(), "feed story provenance missing raw transcript boundary")
        require(first.get("shippedWork"), "feed item missing shipped-work receipt")
        require(
            any(item.get("provenance") for item in first.get("shippedWork", []) if isinstance(item, dict)),
            "shipped-work receipt missing provenance",
        )
        require((first.get("verificationReceipt") or {}).get("schema") == "tokenbar.verification_receipt.v1", "feed item missing verification receipt")
        require(not (first.get("privacy") or {}).get("rawTranscriptsIncluded"), "feed item claims raw transcripts are included")
        require(not (first.get("privacy") or {}).get("sourceCodeIncluded"), "feed item claims source code is included")
        breakdown = first.get("rankingBreakdown") or {}
        require(breakdown, "feed item missing transparent ranking breakdown")
        require((breakdown.get("weights") or {}).get("tokens") == 0.06, "ranking breakdown does not cap token weight at 6%")
        require("capped" in str(breakdown.get("note") or "").lower(), "ranking breakdown missing capped-token explanation")
        require(loops and loops[0].get("loopMaturity") is not None, "loop rankings did not populate")
        for board_key in ("overall", "loop", "craftTaste", "completion", "ambition", "discernment"):
            board = leaderboards.get(board_key) if isinstance(leaderboards, dict) else {}
            require(board and board.get("items"), f"action feed missing {board_key} leaderboard")
        require((leaderboards.get("overall") or {}).get("scoreKey") == "score", "overall leaderboard missing composite score key")
        require((leaderboards.get("craftTaste") or {}).get("scoreKey") == "craftTaste", "craft/taste leaderboard missing signal score key")
        require((regional_leaderboards.get("Global") or []), "action feed missing global regional leaderboard")
        require((regional_leaderboards.get("Singapore") or []), "action feed missing Singapore regional leaderboard")
        require((regional_leaderboards.get("Southeast Asia") or []), "action feed missing Southeast Asia regional leaderboard")
        require((regional_leaderboards.get("Singapore") or [{}])[0].get("handle") == "tokenbar-smoke", "Singapore regional board missing owner handle")
        require((regional_leaderboards.get("Southeast Asia") or [{}])[0].get("region") == "Singapore", "Southeast Asia board did not include Singapore proof")

        social_html = get_text(f"{base_url}/social")
        rankings_html = get_text(f"{base_url}/rankings")
        profile_html = get_text(f"{base_url}/profile")
        index_html = get_text(f"{base_url}/")
        docs_html = get_text(f"{base_url}/docs")
        app_js = get_text(f"{base_url}/app.js")
        styles_css = get_text(f"{base_url}/styles.css")
        proof_html = get_text(f"{base_url}/api/actions?token={token}")
        public_profile_html = get_text(f"{base_url}/api/profiles?token={token}")
        require("data-social-feed" in social_html, "social page missing feed mount")
        require("data-hackathon-roster" in social_html, "social page missing hackathon roster mount")
        require("Public hackathon builder roster" in social_html, "social page missing roster label")
        require("Roster pending" in social_html, "social page missing roster empty state")
        require("tokenbar submit --project" in index_html, "home page missing submit shortcut")
        require("tokenbar submit --project" in docs_html, "docs page missing submit shortcut")
        require("tokenbar share latest" not in index_html, "home page still uses obsolete share-latest path")
        require("tokenbar submit --project" in social_html, "social page missing submit shortcut")
        require("Submit your build" in social_html, "social page missing top submit booth")
        require("One repo becomes a public builder card." in social_html, "social page missing repo-to-profile promise")
        require("submit-booth-token" in social_html, "social page missing first-screen TBAR paste form")
        require("class=\"token-surface-launcher\" data-token-surface-launcher" in social_html, "social page token launcher is not styled or mounted")
        require("After <code>tokenbar submit</code> finishes" in social_html, "social page missing post-submit token handoff")
        require("submit-booth" in styles_css, "social page missing submit booth styling")
        require("tokenbar prove" in social_html, "social page missing prove shortcut")
        require("Run tokenbar prove" not in social_html, "social page still makes prove the primary empty-state action")
        require("Submit a repo, get a builder profile." in social_html, "social page missing hackathon repo submission intake")
        require("cd ~/path/to/repo" in social_html, "social page missing repo-local command")
        require("tokenbar save https://example.com --tag inspiration" in social_html, "social page missing builder reference save command")
        require("No raw repo upload" in social_html, "social page missing no-raw-repo-upload privacy promise")
        require("data-submission-update" in social_html, "social page missing project submission update form")
        require("Attach project to token" in social_html, "social page missing project submission action")
        require("GitHub URL" in social_html and "Demo URL" in social_html, "social page missing submitted project links")
        require("Opt-in rankings" in social_html and "Shareable proof token" in social_html, "social page missing hackathon profile-token contract")
        require("data-share-proof" in social_html, "social page missing share-proof action")
        require("feed-safety" in social_html, "social page static feed missing safety receipt")
        require("data-share-contract" in social_html, "social page missing share contract panel")
        require("Public proof contract" in social_html, "social page missing share contract headline")
        require("raw transcripts, source code, credentials, private diffs, and env files" in social_html, "social page missing never-public contract copy")
        require("data-proof-receipt-form" in social_html, "social page missing local receipt handoff form")
        require("tokenbar proof latest --json" in social_html, "social page missing proof receipt JSON command")
        require("feed-story-card" in social_html, "social page static feed missing story card")
        require("What shipped" in social_html and "Why it matters" in social_html, "social page static feed missing story labels")
        require("No raw transcripts" in social_html and "No source code" in social_html, "social page static feed missing privacy boundary")
        require("feed-safety" in app_js, "dynamic feed renderer missing safety receipt")
        require("function renderLocalProofReceipt" in app_js, "dynamic renderer missing local proof receipt preview")
        require("tokenbar.local_proof_receipt.v1" in app_js, "dynamic renderer missing local proof receipt schema check")
        require("rawTranscriptsUploaded" in app_js and "sourceCodeUploaded" in app_js, "dynamic receipt preview missing privacy flag checks")
        require("function renderShareContract" in app_js, "dynamic social renderer missing share contract")
        require("shareContract" in app_js and "Never public" in app_js, "dynamic social renderer missing share contract copy")
        require("feedStory" in app_js and "feed-story-card" in app_js, "dynamic feed renderer missing story card")
        require("What shipped" in app_js and "Why it matters" in app_js, "dynamic feed renderer missing story labels")
        require("feed-shipped-work" in app_js, "dynamic feed renderer missing shipped-work receipt")
        require("feed-safe-receipt" in app_js and "token-safe-receipt" in app_js, "dynamic renderer missing safe evidence receipt surfaces")
        require("feed-next-action" in app_js and "Act next" in app_js, "dynamic feed renderer missing next-action plan")
        require("feed-profile-links" in app_js, "dynamic feed renderer missing owner profile links")
        require("function submissionForProfile" in app_js, "dynamic renderer missing submitted-project helper")
        require("tokenbar.hackathon_submission_update.v1" in app_js, "dynamic submission form missing POST schema")
        require("data-submission-update-state" in app_js, "dynamic submission form missing status binding")
        require("feed-submission-card" in app_js and "Submitted project" in app_js, "dynamic feed renderer missing submitted-project card")
        require("function renderHackathonRoster" in app_js, "dynamic social renderer missing hackathon roster")
        require("data-hackathon-roster" in app_js, "dynamic social renderer missing roster selector")
        require("renderHackathonRoster(payload.feed)" in app_js, "action feed load does not refresh hackathon roster")
        require("roster-card" in app_js and "roster-card" in styles_css, "hackathon roster missing renderer/style")
        require("Repo</a>" in app_js and "Demo</a>" in app_js and "Profile</a>" in app_js, "hackathon roster missing repo/demo/profile links")
        require("No raw repo upload" in app_js, "dynamic submitted-project card missing privacy boundary")
        require("ranking-project-line" in app_js, "dynamic ranking renderers missing submitted-project context")
        require("feed-rank-badges" in app_js, "dynamic feed renderer missing public rank badges")
        require("No raw transcripts" in app_js and "No source code" in app_js, "dynamic feed renderer missing privacy boundary")
        require("data-action-loop-rankings" in social_html, "social page missing loop rankings mount")
        require("data-stats-top-profiles" in rankings_html, "rankings page missing top profile mount")
        require("tokenbar submit --project" in rankings_html, "rankings page missing submit shortcut")
        require("tokenbar prove" in rankings_html, "rankings page missing prove shortcut")
        require("Run tokenbar prove" not in rankings_html, "rankings page still makes prove the primary empty-state action")
        require("data-stats-top-loop-profiles" in rankings_html, "rankings page missing loop profile mount")
        require("data-ranking-leaderboards" in rankings_html, "rankings page missing category leaderboard mount")
        require("Different kinds of excellence should rank differently" in rankings_html, "rankings page missing category leaderboard headline")
        require("rankings-profile-token" in rankings_html, "rankings page missing token lookup")
        require("class=\"token-surface-launcher\" data-token-surface-launcher" in rankings_html, "rankings page missing styled token surface launcher")
        require("Proof beats spend" in rankings_html, "rankings page missing ranking contract headline")
        require("Capped token volume" in rankings_html, "rankings page missing capped-token formula")
        require("--unlisted --hide-owner --hide-tokens --hide-sessions" in profile_html, "profile page missing anonymous unlisted share command")
        require("tokenbar submit --project" in profile_html, "profile page missing submit shortcut")
        require("tokenbar prove" in profile_html, "profile page missing prove shortcut")
        require("Hackathon submission mode" in profile_html, "profile page missing hackathon submission mode")
        require("Each builder gets a shareable profile" in profile_html, "profile page missing per-builder profile promise")
        require("cd ~/path/to/repo && tokenbar submit --project" in profile_html, "profile page missing one-command repo passport")
        require("what remains uncertain" in profile_html, "profile page missing judge-facing uncertainty promise")
        require("share-mode-lab" in profile_html, "profile page missing share mode lab")
        require("data-identity-create" in profile_html, "profile page missing browser-first create identity journey")
        require("Choose safe identity artifact" in profile_html, "create identity journey missing safe artifact picker")
        require("Build identity passport" in profile_html and "Preview share card" in profile_html, "create identity journey missing concise processing stages")
        require("data-identity-create-state" in profile_html, "create identity journey missing privacy-safe status")
        require("/social?token=${encodeURIComponent(token)}" in app_js, "token launcher fallback does not open direct social URL")
        require("/rankings?token=${encodeURIComponent(token)}" in app_js, "token launcher fallback does not open direct rankings URL")
        require("profile?.actionLinks?.[key]" in app_js, "token launcher does not read nested actionLinks")
        require("setIdentityCreateStage" in app_js and "idempotencyKey: `browser-${submittedSelectionKey}-${visibility}`" in app_js, "browser create identity handler missing staged action flow")
        require("identityArtifactIsSafe" in app_js and "setIdentitySubmitEnabled" in app_js, "browser create identity handler can submit before local safety preflight completes")
        require("announceIdentityVisibility" in app_js and "keeps it out of public discovery" in app_js, "browser create identity handler does not explain selected share visibility")
        require("data-identity-share-contract" in profile_html and "renderIdentityShareContract" in app_js, "browser create identity flow lacks a visibility-specific safe share contract")
        require("data-identity-passport" in app_js and "passportPreview?.scrollIntoView" in app_js, "browser create identity handler does not keep the generated share card in view")
        require("passportRequestStarted" in app_js and 'setIdentityCreateStage("passport", "error", "Could not create")' in app_js, "browser create identity flow mislabels a passport request failure as an unsafe artifact")
        require("setIdentityGenerationPending" in app_js and 'identityCreateForm.setAttribute("aria-busy", String(pending))' in app_js, "browser create identity flow does not prevent duplicate passport requests")
        require("data-identity-retry" in profile_html and "identityCreateForm.requestSubmit()" in app_js and "setIdentityRetryVisible(true)" in app_js, "browser create identity flow does not offer a safe retry after passport request failure")
        require("identityArtifactSelectionKey" in app_js and "createIdentityArtifactSelectionKey" in app_js, "browser create identity flow can reuse an older artifact's idempotency key")
        require("submittedSelectionKey" in app_js and "The selected artifact changed" in app_js, "browser create identity flow can submit a replacement artifact under a stale local approval")
        require("MAX_IDENTITY_ARTIFACT_BYTES = 240_000" in app_js and "It was not read or uploaded" in app_js, "browser create identity flow lacks a local oversized-artifact privacy guard")
        require('if (identityCreatePreview) identityCreatePreview.innerHTML = "";' in app_js, "browser create identity flow leaves a prior passport preview visible while a replacement artifact is checked")
        require("Anonymous proof" in social_html, "social page missing anonymous proof action")
        require("ranking-privacy-panel" in rankings_html, "rankings page missing privacy rule panel")
        require("Regional proof boards" in rankings_html, "rankings page missing regional proof board headline")
        require("data-region-tab=\"Singapore\"" in rankings_html, "rankings page missing Singapore region tab")
        require("data-region-list" in rankings_html, "rankings page missing regional leaderboard mount")
        require("ranking-breakdown" in app_js, "dynamic ranking renderer missing score breakdown")
        require("function renderRankingLeaderboards" in app_js, "dynamic ranking renderer missing category boards")
        require("scoreForLeaderboard" in app_js, "dynamic ranking renderer missing signal score helper")
        require("regionalLeaderboards" in app_js, "dynamic renderer missing action regional leaderboards")
        require("Token volume is capped" in app_js, "dynamic ranking renderer missing capped-token explanation")
        require("Share mode" in app_js and "Redactions" in app_js, "dynamic proof renderer missing share-mode receipt")
        require("proof-verification-receipt" in app_js, "dynamic proof renderer missing verification receipt")
        require("This token is private" in app_js, "profile token lookup missing private-token guidance")
        require("No public profile found for that token" in app_js, "profile token lookup missing missing-token guidance")
        require("Profile found. Choose a proof surface below." in app_js, "profile token lookup missing surface launcher success guidance")
        require("function profileHrefForToken" in app_js, "dynamic profile renderer missing token URL helper")
        require("function renderTokenSurfaceLauncher" in app_js, "profile token lookup missing proof surface launcher renderer")
        require("function tokenFromLocation" in app_js, "profile token lookup missing URL token handoff")
        require("autoActivateProfileToken" in app_js, "profile token lookup missing auto activation from URL token")
        require("tokenbar:lastPublicToken" in app_js, "profile token lookup missing last public token recovery")
        require("token-reopen-button" in app_js and "token-reopen-button" in styles_css, "profile token lookup missing last-proof shortcut UI")
        require("surfaceBundle" in app_js and "bundleSurfaces" in app_js, "profile token launcher does not use surface bundle")
        require("function renderTokenSubmissionSummary" in app_js, "profile token launcher missing submitted-project summary")
        require("token-submission-summary" in app_js and "token-submission-summary" in styles_css, "profile token launcher missing submitted-project styling")
        require("function renderTokenProofPassport" in app_js, "profile token launcher missing judge-ready proof passport")
        require("60-second proof passport" in app_js, "profile token launcher missing proof passport headline")
        require("token-proof-passport" in app_js and "token-proof-passport" in styles_css, "profile token launcher missing proof passport styling")
        require("token-passport-boundary" in app_js and "raw transcripts excluded" in app_js, "profile token launcher missing privacy boundary passport")
        require("function surfaceFromBundle" in app_js, "dynamic social renderer missing surface-bundle link helper")
        require("Proof bundle unlocked" in app_js and "For You feed" in app_js, "profile token launcher missing proof bundle surfaces")
        require("/api/profiles${token}" not in app_js, "dynamic profile renderer has malformed token URL fallback")
        require("/api/profiles?token=" in app_js, "dynamic profile renderer missing profile token query URL")
        require("data-profile-lookup" in profile_html, "profile page missing token lookup")
        require("data-token-surface-launcher" in profile_html, "profile page missing token surface launcher")
        require("Paste a `TBAR` token" not in profile_html, "profile page contains malformed backtick token copy")
        require("What remains uncertain" in proof_html, "proof HTML missing uncertainty section")
        require("Safe evidence receipt" in proof_html and "Never used" in proof_html, "proof HTML missing safe evidence receipt")
        require("Act next" in proof_html and "tokenbar publish-proof --unlisted" in proof_html, "proof HTML missing next-action plan")
        require("Share receipt" in proof_html and "tokenbar.share_receipt.v1" in proof_html, "proof HTML missing share receipt")
        require("Verification receipt" in proof_html and "Token volume is capped" in proof_html, "proof HTML missing verification receipt")
        require("Compared to yourself over time" in proof_html, "proof HTML missing self-over-time section")
        require("Shipped-work receipt" in proof_html, "proof HTML missing shipped-work receipt")
        require("safe work evidence" in proof_html, "proof HTML missing shipped-work provenance copy")
        require("Builder reference radar" in proof_html, "proof HTML missing builder reference radar")
        require("What this builder studies between work sessions" in proof_html, "proof HTML missing reference-radar story")
        require("Saved references" in proof_html and "Aggregate only" in proof_html, "proof HTML missing reference-radar aggregate boundary")
        require("Raw URLs, titles, notes, page content, transcripts, and source code stay local" in proof_html, "proof HTML missing reference-radar privacy copy")
        require("Raw transcripts" in proof_html and "No source code" in proof_html, "proof HTML missing privacy strip")
        require("Report or correct this profile" in proof_html, "proof HTML missing correction/report path")
        require("POST /api/report-feedback" in proof_html, "proof HTML missing report-feedback endpoint")
        require("Do not paste raw transcripts, source code, credentials, private diffs, or environment files" in proof_html, "proof HTML missing correction privacy boundary")
        require("Proof card" in public_profile_html and "Loop rankings" in public_profile_html, "public profile missing proof navigation")
        require("Submitted project" in public_profile_html and "Browser Submitted Proof" in public_profile_html, "public profile missing browser-submitted project card")
        require("No raw repo upload" in public_profile_html and "Public metadata only" in public_profile_html, "public profile missing submission privacy boundary")
        require("Public rank context" in proof_html, "proof HTML missing rank context")
        require("Public rank context" in public_profile_html and "Global #1" in public_profile_html, "public profile HTML missing rank context")
        require('data-proof-profile="story-first"' in public_profile_html, "public profile is not story-first")
        require("Builder identity passport" in public_profile_html, "public profile missing identity passport")
        require("Builder owner profile" in public_profile_html and "tokenbar-smoke" in public_profile_html, "public profile HTML missing owner card")
        require("https://github.com/Arnie016/TokenBar" in public_profile_html, "public profile HTML missing owner GitHub link")
        require("Safe evidence receipt" in public_profile_html and "never used" in public_profile_html.lower(), "public profile missing safe evidence receipt")
        require("Act next" in public_profile_html and "tokenbar publish-proof --unlisted" in public_profile_html, "public profile missing next-action plan")
        require("Share receipt" in public_profile_html and "tokenbar.share_receipt.v1" in public_profile_html, "public profile missing share receipt")
        require(token in public_profile_html, "public profile identity passport missing public token")
        require("safe evidence only" in public_profile_html, "public profile identity passport missing safe-evidence boundary")
        require("shareable surfaces" in public_profile_html, "public profile identity passport missing share-surface summary")
        require("What kind of builder?" in public_profile_html, "public profile missing 60-second builder read")
        require("Verification receipt" in public_profile_html and "Token volume is capped" in public_profile_html, "public profile missing verification receipt")
        require("Compared to yourself over time" in public_profile_html, "public profile missing self-over-time section")
        require("Shipped-work receipt" in public_profile_html, "public profile missing shipped-work receipt")
        require("Evidence behind the public story" in public_profile_html, "public profile missing shipped-work provenance copy")
        require("Builder reference radar" in public_profile_html, "public profile missing builder reference radar")
        require("Saved links become a private learning trail" in public_profile_html, "public profile missing reference-radar learning trail copy")
        require("Raw URLs, titles, notes, page content, transcripts, and source code stay local" in public_profile_html, "public profile missing reference-radar privacy copy")
        require("No raw transcripts" in public_profile_html and "No source code" in public_profile_html, "public profile missing safe evidence boundary")
        require("Safe aggregates only" in public_profile_html, "public profile missing aggregate-only boundary")
        require("Share preview" in public_profile_html, "public profile missing share preview")
        require("Report or correct this profile" in public_profile_html, "public profile missing correction/report path")
        require("POST /api/report-feedback" in public_profile_html, "public profile missing report-feedback endpoint")
        require("proof-shipped-work" in app_js, "dynamic proof renderer missing shipped-work receipt")

        missing_feedback_status, missing_feedback = post_json(
            f"{base_url}/api/report-feedback",
            {"token": token, "category": "correction", "message": "short"},
        )
        require(missing_feedback_status == 400, f"report-feedback should reject short messages, got {missing_feedback_status}: {missing_feedback}")
        require(missing_feedback.get("error") == "message_required", "report-feedback short message error changed")
        feedback_status, feedback_payload = post_json(
            f"{base_url}/api/report-feedback",
            {
                "token": token,
                "category": "correction",
                "reportUrl": proof.get("proofCardUrl"),
                "email": "builder@example.com",
                "message": "The profile should emphasize completion evidence more than token count. No raw logs are included.",
            },
        )
        require(feedback_status == 200 and feedback_payload.get("ok") is True, f"report-feedback did not accept safe correction: {feedback_status} {feedback_payload}")
        require("AgentMail delivery is not configured" in feedback_payload.get("message", ""), "report-feedback fallback delivery message changed")

        selective = run(
            [
                str(tokenbar_cli),
                "publish-proof",
                str(identity_path),
                "--unlisted",
                "--hide-owner",
                "--hide-tokens",
                "--hide-sessions",
            ],
            publish_env,
            timeout=90,
        )
        selective_run_match = re.search(r"Builder proof run:\s*(run_[a-f0-9]+)", selective.stdout)
        selective_token_match = re.search(r"Proof card:\s*.*token=(TBAR-[A-Z0-9]+)", selective.stdout)
        require(selective_run_match, f"selective publish-proof did not print a run id:\n{selective.stdout}")
        require(selective_token_match, f"selective publish-proof did not print a proof-card token:\n{selective.stdout}")
        require("Safe token:" in selective.stdout, "selective publish-proof did not print a safe token")
        require("Proof bundle:" in selective.stdout, "selective publish-proof did not print a proof bundle")
        require("Public profile:" in selective.stdout, "selective publish-proof did not print a public profile bundle link")
        require("For You feed:" in selective.stdout, "selective publish-proof did not print a feed bundle link")
        require("Leaderboards:" in selective.stdout, "selective publish-proof did not print a leaderboard bundle link")
        require("Loop rankings:" in selective.stdout, "selective publish-proof did not print a loop ranking bundle link")
        require("Share receipt:" in selective.stdout, "selective publish-proof did not print a share receipt")
        selective_run_id = selective_run_match.group(1)
        selective_token = selective_token_match.group(1)
        require(selective_token != token, "unlisted proof reused the public proof token")
        selective_proof_payload = get_json(f"{base_url}/api/actions?token={selective_token}")
        selective_profile_payload = get_json(f"{base_url}/api/profiles?token={selective_token}")
        selective_feed_payload = get_json(f"{base_url}/api/actions")
        selective_proof = selective_proof_payload.get("proof") or {}
        selective_profile = selective_profile_payload.get("profile") or {}
        selective_feed = selective_feed_payload.get("feed") or []
        selective_public_runs = selective_feed_payload.get("runs") or []
        selective_share_contract = selective_feed_payload.get("shareContract") or {}
        selective_tokens = {str(item.get("token") or "") for item in selective_feed if isinstance(item, dict)}
        selective_public_run_ids = {str(item.get("runId") or "") for item in selective_public_runs if isinstance(item, dict)}
        selective_privacy = selective_proof.get("privacy") or {}
        selective_redactions = selective_privacy.get("redactions") or {}
        require(selective_proof.get("publicVisibility") == "unlisted", "selective proof did not persist unlisted visibility")
        require((selective_proof.get("verificationReceipt") or {}).get("shareMode") == "unlisted", "selective proof receipt did not persist unlisted visibility")
        require((selective_proof.get("shareReceipt") or {}).get("shareMode") == "unlisted", "selective share receipt did not persist unlisted visibility")
        require(selective_redactions.get("owner") is True, "selective proof did not redact owner metadata")
        require(selective_redactions.get("tokens") is True, "selective proof did not redact tokens")
        require(selective_redactions.get("sessions") is True, "selective proof did not redact sessions")
        selective_owner = selective_proof.get("ownerProfile") or {}
        require(selective_owner.get("ownerRedacted") is True, "selective proof owner profile missing ownerRedacted flag")
        require(selective_owner.get("handle") == "anonymous-builder", "selective proof leaked owner handle")
        require(selective_owner.get("nickname") == "Anonymous Builder", "selective proof leaked owner nickname")
        require(selective_owner.get("links") == {}, "selective proof leaked owner links")
        require(selective_proof.get("tokenCountHidden") is True, "selective proof missing token hidden flag")
        require(selective_proof.get("sessionCountHidden") is True, "selective proof missing session hidden flag")
        require(selective_proof.get("totalTokens") == 0, "selective proof exposes token count")
        require(selective_proof.get("sessionCount") == 0, "selective proof exposes session count")
        selective_story = selective_proof.get("builderStory") or {}
        selective_story_text = json.dumps(selective_story, sort_keys=True)
        require("Hidden by owner" in selective_story_text, "selective story missing redaction language")
        require(f"{proof.get('sessionCount')} indexed local sessions" not in selective_story_text, "selective story leaked session count")
        require(selective_story.get("shippedWork"), "selective proof missing shipped-work receipt")
        selective_share_receipt = selective_proof.get("shareReceipt") or {}
        require({"owner", "tokens", "sessions"}.issubset(set(selective_share_receipt.get("redactedFields") or [])), "selective share receipt missing redacted fields")
        require("excluded from public feed" in str(selective_share_receipt.get("publicMaterial") or "").lower(), "selective share receipt missing unlisted boundary")
        selective_public_profile = selective_profile.get("publicProfile") or {}
        require(selective_public_profile.get("visibility") == "unlisted", "selective profile did not inherit unlisted visibility")
        require(selective_public_profile.get("ownerRedacted") is True, "selective profile missing owner redaction flag")
        require(selective_public_profile.get("handle") == "anonymous-builder", "selective profile leaked owner handle")
        selective_public_profile_text = json.dumps(selective_public_profile, sort_keys=True)
        require("tokenbar-smoke" not in selective_public_profile_text, "selective profile leaked original owner handle")
        require("Arnie016/TokenBar" not in selective_public_profile_text, "selective profile leaked original owner links")
        selective_surface_bundle = selective_profile.get("surfaceBundle") or {}
        selective_surface_keys = {
            item.get("key")
            for item in (selective_surface_bundle.get("surfaces") or [])
            if isinstance(item, dict)
        }
        require(selective_surface_bundle.get("schema") == "tokenbar.surface_bundle.v1", "selective profile missing surface bundle schema")
        require(selective_surface_bundle.get("visibility") == "unlisted", "selective surface bundle did not inherit unlisted visibility")
        require({"proofCard", "publicProfile", "socialFeed", "rankings", "loopRankings"}.issubset(selective_surface_keys), "selective surface bundle missing safe surfaces")
        require(selective_share_contract.get("unlistedProofCount", 0) >= 1, "share contract did not count unlisted proof")
        require(selective_share_contract.get("unlistedIncludedInFeed") is False, "share contract regressed unlisted feed exclusion")
        require(selective_token not in selective_tokens, "unlisted proof leaked into public feed")
        require(selective_run_id not in selective_public_run_ids, "unlisted proof leaked into public action index")
        selective_proof_html = get_text(f"{base_url}/api/actions?token={selective_token}")
        require("Share mode" in selective_proof_html and "unlisted" in selective_proof_html, "selective proof HTML missing share mode")
        require("Redactions" in selective_proof_html and "owner" in selective_proof_html and "tokens" in selective_proof_html and "sessions" in selective_proof_html, "selective proof HTML missing redaction receipt")
        require("Share receipt" in selective_proof_html and "tokenbar.share_receipt.v1" in selective_proof_html, "selective proof HTML missing share receipt")

        private = run(
            [
                str(tokenbar_cli),
                "publish-proof",
                str(identity_path),
                "--private",
            ],
            publish_env,
            timeout=90,
        )
        private_run_match = re.search(r"Builder proof run:\s*(run_[a-f0-9]+)", private.stdout)
        private_token_match = re.search(r"Safe token:\s*(TBAR-[A-Z0-9]+)", private.stdout)
        require(private_run_match, f"private publish-proof did not print a run id:\n{private.stdout}")
        require(private_token_match, f"private publish-proof did not print a token:\n{private.stdout}")
        require("Proof bundle: disabled by --private" in private.stdout, "private publish-proof did not explain disabled proof bundle")
        require("Public proof card: disabled by --private" in private.stdout, "private publish-proof did not disable public proof card")
        require("Public profile: disabled by --private" in private.stdout, "private publish-proof did not disable public profile")
        require("For You feed: not listed" in private.stdout, "private publish-proof did not disable feed listing")
        require("Leaderboards: not listed" in private.stdout, "private publish-proof did not disable leaderboard listing")
        require("Share receipt:" in private.stdout, "private publish-proof did not print a share receipt")
        private_run_id = private_run_match.group(1)
        private_token = private_token_match.group(1)
        require(private_token not in {token, selective_token}, "private proof reused a public or unlisted proof token")
        private_run_payload = get_json(f"{base_url}/api/actions?run={private_run_id}")
        private_run = private_run_payload.get("run") or {}
        private_proof = private_run.get("proof") or {}
        private_receipt = private_proof.get("verificationReceipt") or {}
        private_share_receipt = private_proof.get("shareReceipt") or {}
        require(private_run.get("status") == "complete", "private action run did not reload complete")
        require(private_proof.get("publicVisibility") == "private", "private proof did not persist private visibility")
        require(private_receipt.get("shareMode") == "private", "private receipt did not persist private visibility")
        require(private_share_receipt.get("shareMode") == "private", "private share receipt did not persist private visibility")
        require("token, profile, feed, and ranking lookups are disabled" in private_receipt.get("publicMaterial", ""), "private receipt does not explain disabled public surfaces")
        require("no public proof" in private_share_receipt.get("publicMaterial", ""), "private share receipt does not explain disabled public surfaces")
        private_latest = run([str(tokenbar_cli), "proof", "latest", "--json"], publish_env, timeout=90)
        private_local_receipt = json.loads(private_latest.stdout)
        private_surfaces = private_local_receipt.get("surfaces") or {}
        require(private_local_receipt.get("shareMode") == "private", "private local receipt did not persist private share mode")
        require(set(private_surfaces.keys()) == {"privateAudit"}, f"private local receipt leaked public surface links: {sorted(private_surfaces)}")
        require(private_surfaces.get("privateAudit") == f"{base_url}/api/actions?run={private_run_id}", "private local receipt missing private audit surface")
        require("No public token, profile, feed, or ranking lookup is enabled" in private_local_receipt.get("shareCopy", ""), "private local receipt share copy implies public lookup")
        latest_shareable = run([str(tokenbar_cli), "proof", "latest", "--public"], publish_env, timeout=90)
        require("Latest safe TokenBar proof" in latest_shareable.stdout, "proof latest --public missing heading")
        require(token in latest_shareable.stdout or selective_token in latest_shareable.stdout, "proof latest --public did not recover a shareable token")
        require("Share mode: private" not in latest_shareable.stdout, "proof latest --public returned a private receipt")
        require("Public profile:" in latest_shareable.stdout and "For You feed:" in latest_shareable.stdout, "proof latest --public missing public profile/feed surfaces")
        require("Need a shareable profile link?" not in latest_shareable.stdout, "proof latest --public incorrectly returned private guidance")
        private_token_status, private_token_body = get_status(f"{base_url}/api/actions?token={private_token}")
        private_html_status, _ = get_status(f"{base_url}/api/actions?token={private_token}", accept="text/html")
        private_profile_status, _ = get_status(f"{base_url}/api/profiles?token={private_token}")
        require(private_token_status == 403, f"private proof token lookup should be forbidden, got {private_token_status}: {private_token_body}")
        require(private_html_status == 403, f"private proof HTML lookup should be forbidden, got {private_html_status}")
        require(private_profile_status == 404, f"private profile lookup should be hidden, got {private_profile_status}")
        private_feed_payload = get_json(f"{base_url}/api/actions")
        private_feed = private_feed_payload.get("feed") or []
        private_public_runs = private_feed_payload.get("runs") or []
        private_share_contract = private_feed_payload.get("shareContract") or {}
        private_tokens = {str(item.get("token") or "") for item in private_feed if isinstance(item, dict)}
        private_public_run_ids = {str(item.get("runId") or "") for item in private_public_runs if isinstance(item, dict)}
        require(private_share_contract.get("privateProofCount", 0) >= 1, "share contract did not count private proof")
        require(private_share_contract.get("privateIncludedInFeed") is False, "share contract regressed private feed exclusion")
        require(private_token not in private_tokens, "private proof leaked into public feed")
        require(private_run_id not in private_public_run_ids, "private proof leaked into public action index")

        submit = run(
            [
                str(tokenbar_cli),
                "submit",
                "--project",
                "CLI Submitted Proof",
                "--event",
                "CLI Intake Hackathon",
                "--track",
                "Repo league",
                "--repo",
                "https://github.com/Arnie016/TokenBar",
                "--demo",
                "https://tokenbar-umber.vercel.app/social",
                "--tagline",
                "One-command repo submission without raw upload.",
            ],
            publish_env,
            timeout=180,
        )
        submit_run_match = re.search(r"Builder proof run:\s*(run_[A-Za-z0-9._-]+)", submit.stdout)
        submit_token_match = re.search(r"Proof card:\s*.*token=(TBAR-[A-Z0-9]+)", submit.stdout)
        require("Submitting a safe TokenBar builder profile for: CLI Submitted Proof" in submit.stdout, "submit output missing project heading")
        require("Privacy: raw prompts, transcripts, source code, and secrets stay local." in submit.stdout, "submit output missing privacy boundary")
        require("After analysis: copy the printed Safe token and paste it on /social to join the board." in submit.stdout, "submit output missing social token handoff")
        require("Safe token:" in submit.stdout, "submit did not print a safe token")
        require(submit_run_match, f"submit did not print an action run id:\n{submit.stdout}")
        require(submit_token_match, f"submit did not print a proof-card token:\n{submit.stdout}")
        submit_token = submit_token_match.group(1)
        require(f"/social?token={submit_token}" in submit.stdout, "submit output missing direct social URL")
        require(f"/rankings?token={submit_token}" in submit.stdout, "submit output missing direct rankings URL")
        submit_profile_payload = get_json(f"{base_url}/api/profiles?token={submit_token}")
        submit_profile = submit_profile_payload.get("profile") or {}
        submit_submission = submit_profile.get("hackathonSubmission") or {}
        require(submit_submission.get("projectTitle") == "CLI Submitted Proof", "submit profile missing project title")
        require(submit_submission.get("event") == "CLI Intake Hackathon", "submit profile missing event")
        require(submit_submission.get("track") == "Repo league", "submit profile missing track")
        require(submit_submission.get("repoUrl") == "https://github.com/Arnie016/TokenBar", "submit profile missing safe repo URL")
        require((submit_submission.get("privacy") or {}).get("rawRepoUploaded") is False, "submit claims raw repo upload")
        require(not (submit_profile.get("privacy") or {}).get("rawTranscriptsIncluded"), "submit profile exposes raw transcripts")
        require(not (submit_profile.get("privacy") or {}).get("sourceCodeIncluded"), "submit profile exposes source code")

        print("TokenBar Builder Identity smoke passed")
        print(f"  cli: {tokenbar_cli}")
        print(f"  run: {run_id}")
        print(f"  token: {token}")
        print(f"  submit token: {submit_token}")
        print(f"  unlisted token: {selective_token}")
        print(f"  private run: {private_run_id}")
        print(f"  identity: {proof.get('title')}")
        print(f"  proof: {proof.get('proofScore')}/100")
        print(f"  loop: {proof.get('loopMaturity')}/100")
        print(f"  sessions: {proof.get('sessionCount')}")
        print(f"  proof card: {proof.get('proofCardUrl')}")
        print(f"  profile: {first.get('profileUrl')}")
        print(f"  social: {first.get('socialUrl')}")
        print(f"  rankings: {first.get('rankingsUrl')}")
        print("  pages: social/rankings/profile/proof HTML mounted")
        print("  privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified")
        return 0
    finally:
        server.terminate()
        try:
            server.wait(timeout=3)
        except subprocess.TimeoutExpired:
            server.kill()
            server.wait(timeout=3)
        shutil.rmtree(temp_dir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
