#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "bin" / "tokenbar"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def get_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=3) as response:
        return json.loads(response.read().decode("utf-8"))


def open_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def main() -> None:
    port = int(os.environ.get("TOKENBAR_IDENTITY_API_SMOKE_PORT") or open_port())
    with tempfile.TemporaryDirectory(prefix="tokenbar-identity-api-") as temp:
        support = Path(temp) / "support"
        profiles = support / "profiles"
        profiles.mkdir(parents=True)
        identity = {
            "schema": "tokenbar.identity.v1",
            "title": "Fixture Systems Cartographer",
            "primaryArchetype": "Systems Cartographer",
            "proofScore": 73,
            "dimensions": [{"name": "Steering", "score": 81, "commandPromptRatio": 0.8}],
            "signatureMoves": ["Closes with inspectable proof"],
            "curiousFacts": [{"label": "Redirect rhythm", "value": "3 turns", "copy": "You steer early."}],
            "growthEdge": "Make the verification receipt easier to inspect.",
            "sessionAnalysis": {
                "sessionCount": 12,
                "prompt": "never return this raw prompt",
                "signaturePhrases": ["never leak this prompt-shaped excerpt"],
                "sourcePath": "/Users/example/private/repo",
                "note": "Built at /Users/example/private/repo with sk-secret123456789",
            },
            "providerAnalyses": {
                "gemini": {
                    "provider": "Gemini CLI",
                    "signaturePhrases": ["never leak provider prompt excerpt"],
                }
            },
            "privacy": {"rawTranscriptsIncluded": False, "sourceCodeIncluded": False},
            "token": "TBAR-SHOULD-NOT-LEAK",
            "email": "owner@example.com",
        }
        (profiles / "fixture.identity.json").write_text(json.dumps(identity), encoding="utf-8")
        (support / "usage-index.json").write_text(
            json.dumps(
                {
                    "updatedAt": 1234,
                    "dayTokens": {"2026-07-22": 2000},
                    "modelTokens": {"gpt-test": 2000},
                    "sessionPaths": ["/Users/example/private/session.jsonl"],
                    "activeFolderPaths": ["/Users/example/private/repo"],
                }
            ),
            encoding="utf-8",
        )
        env = os.environ.copy()
        env["TOKENBAR_SUPPORT_DIR"] = str(support)
        env["TOKENBAR_API_QUIET"] = "1"
        process = subprocess.Popen(
            [str(CLI), "api", "--port", str(port)],
            cwd=ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            base = f"http://127.0.0.1:{port}"
            for _ in range(100):
                try:
                    if get_json(f"{base}/health").get("ok"):
                        break
                except Exception:
                    if process.poll() is not None:
                        stdout = process.stdout.read() if process.stdout else ""
                        stderr = process.stderr.read() if process.stderr else ""
                        raise AssertionError(f"identity API exited before healthy: {stderr or stdout}")
                    time.sleep(0.1)
            else:
                raise AssertionError("identity API did not become healthy")

            identity_response = get_json(f"{base}/v1/identity")
            stats_response = get_json(f"{base}/v1/stats")
            reminders_response = get_json(f"{base}/v1/reminders")
            memory_response = get_json(f"{base}/v1/memory-pressure")
            guide_response = get_json(f"{base}/v1/guide")
            waste_response = get_json(f"{base}/v1/waste-lens")
            playbooks_response = get_json(f"{base}/v1/playbooks")
            providers_response = get_json(f"{base}/v1/providers")
            bundle_response = get_json(f"{base}/v1/bundle")
            serialized = json.dumps(bundle_response, sort_keys=True)

            require(identity_response["identity"]["title"] == "Fixture Systems Cartographer", "identity title missing")
            require(identity_response["identity"]["dimensions"][0]["commandPromptRatio"] == 0.8, "safe aggregate prompt ratio removed")
            require(identity_response["identity"]["signatureMoves"][0] == "Closes with inspectable proof", "safe signature move missing")
            require(identity_response["identity"]["curiousFacts"][0]["value"] == "3 turns", "safe curious fact missing")
            require(stats_response["stats"]["sessionCount"] == 1, "session count mismatch")
            require(stats_response["stats"]["activeFolderCount"] == 1, "folder count mismatch")
            require(reminders_response["schema"] == "tokenbar.reminders.v1", "reminders schema mismatch")
            require(reminders_response["privacy"]["scheduledNotifications"] is False, "reminders should not schedule notifications")
            require(memory_response["schema"] == "tokenbar.memory_pressure.v1", "memory pressure schema mismatch")
            require(memory_response["privacy"]["processKill"] is False, "memory pressure should not close processes")
            require(memory_response["privacy"]["browserRestore"] is False, "memory pressure should not restore browsers")
            require(memory_response["privacy"]["browserTabsIncluded"] is False, "memory pressure should not read browser tabs")
            require(memory_response["privacy"]["commandArgumentsIncluded"] is False, "memory pressure should not expose command arguments")
            require(all(action["approvalRequired"] is True for action in memory_response["actions"]), "memory actions must require approval")
            require(guide_response["schema"] == "tokenbar.guide.v1", "guide schema mismatch")
            require(guide_response["privacy"]["writesSettings"] is False, "guide should not write settings")
            require(guide_response["privacy"]["providerCalls"] is False, "guide should not call providers")
            require(guide_response["privacy"]["accountMutation"] is False, "guide should not mutate accounts")
            require(guide_response["privacy"]["scheduledNotifications"] is False, "guide should not schedule notifications")
            require(guide_response["privacy"]["externalActions"] is False, "guide should not take external actions")
            guide_keys = [choice["key"] for choice in guide_response["choices"]]
            require(guide_keys == ["install", "analyze", "budget", "playbook", "proof"], "guide should return the five coach choices")
            guide_commands = {choice["command"] for choice in guide_response["choices"]}
            for command in [
                "tokenbar usage",
                "tokenbar reminders",
                "tokenbar playbooks copy budget-runway",
                "tokenbar proof-packet",
            ]:
                require(command in guide_commands, f"guide missing {command}")
            require(any("raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh" in command for command in guide_commands), "guide missing install command")
            require(waste_response["schema"] == "tokenbar.waste_lens.v1", "waste lens schema mismatch")
            require(0 <= waste_response["score"] <= 100, "waste lens score out of range")
            require(len(waste_response["levers"]) == 3, "waste lens should return three levers")
            require(any(lever["command"] == "tokenbar playbooks copy mission-lock" for lever in waste_response["levers"]), "waste lens missing mission-lock command")
            require(waste_response["privacy"]["providerCalls"] is False, "waste lens should not call providers")
            require(waste_response["privacy"]["accountMutation"] is False, "waste lens should not mutate accounts")
            require(waste_response["privacy"]["qualityJudgment"] is False, "waste lens should not judge output quality")
            require(playbooks_response["schema"] == "tokenbar.playbooks.v1", "playbooks schema mismatch")
            require(playbooks_response["summary"]["freeCount"] == 5, "playbooks free count mismatch")
            require(playbooks_response["summary"]["catalogCount"] == 100, "playbooks catalog count mismatch")
            require(playbooks_response["privacy"]["paymentActions"] is False, "playbooks should not process payments")
            require(playbooks_response["privacy"]["entitlementMutation"] is False, "playbooks should not mutate entitlements")
            require(playbooks_response["privacy"]["externalActions"] is False, "playbooks should not take external actions")
            tier_names = {tier["name"] for tier in playbooks_response["tiers"]}
            require({"Free", "Pro"} <= tier_names, "playbooks missing Free/Pro tiers")
            require("Gemini" not in playbooks_response["connectorTargets"], "playbooks should not include Gemini connector target")
            require(providers_response["schema"] == "tokenbar.providers.v1", "providers schema mismatch")
            provider_names = [provider["name"] for provider in providers_response["providers"]]
            require(provider_names == ["Codex", "Claude Code", "Cursor", "Antigravity", "OpenCode"], "provider target list mismatch")
            require("Gemini" not in provider_names, "Gemini should not be a provider target")
            require(providers_response["privacy"]["providerCalls"] is False, "providers should not call provider APIs")
            require(providers_response["privacy"]["accountMutation"] is False, "providers should not mutate accounts")
            require(providers_response["privacy"]["externalActions"] is False, "providers should not take external actions")
            require(all(provider.get("evidenceNeeded") for provider in providers_response["providers"]), "providers missing evidence needed text")
            require(all(provider.get("command") in {"tokenbar usage", "tokenbar providers"} for provider in providers_response["providers"]), "providers missing safe local command")
            require(all(len(provider.get("setupFlow") or []) == 3 for provider in providers_response["providers"]), "providers should expose three setup steps")
            require(all(step.get("label") in {"Detect", "Connect", "Review"} for provider in providers_response["providers"] for step in provider["setupFlow"]), "provider setup labels mismatch")
            require(bundle_response["reminders"]["schema"] == "tokenbar.reminders.v1", "bundle missing reminders")
            require(bundle_response["reminders"]["topReminder"]["requiresApproval"] is True, "bundle reminder must require approval")
            require(bundle_response["memoryPressure"]["schema"] == "tokenbar.memory_pressure.v1", "bundle missing memory pressure")
            require(bundle_response["memoryPressure"]["privacy"]["processKill"] is False, "bundle memory pressure should not close processes")
            require(bundle_response["guide"]["schema"] == "tokenbar.guide.v1", "bundle missing guide")
            require(bundle_response["wasteLens"]["schema"] == "tokenbar.waste_lens.v1", "bundle missing waste lens")
            require(bundle_response["wasteLens"]["privacy"]["rawPromptsIncluded"] is False, "bundle waste lens should not include raw prompts")
            require(bundle_response["playbooks"]["schema"] == "tokenbar.playbooks.v1", "bundle missing playbooks")
            require(bundle_response["playbooks"]["privacy"]["paymentActions"] is False, "bundle playbooks should not process payments")
            require(bundle_response["providers"]["schema"] == "tokenbar.providers.v1", "bundle missing providers")
            require("/Users/" not in serialized, "local path leaked")
            require("sk-secret" not in serialized, "secret leaked")
            require("never return this raw prompt" not in serialized, "raw prompt leaked")
            require("never leak this prompt-shaped excerpt" not in serialized, "signature phrase leaked")
            require("never leak provider prompt excerpt" not in serialized, "provider analysis excerpt leaked")
            require("providerAnalyses" not in serialized, "provider analyses should not be in safe local bundle")
            require("owner@example.com" not in serialized, "email leaked")
            require("TBAR-SHOULD-NOT-LEAK" not in serialized, "identity token leaked")
            require(bundle_response["privacy"]["rawTranscriptsIncluded"] is False, "privacy receipt missing")

            no_identity_support = Path(temp) / "support-no-identity"
            no_identity_support.mkdir(parents=True)
            (no_identity_support / "usage-index.json").write_text(
                json.dumps(
                    {
                        "updatedAt": 5678,
                        "dayTokens": {"2026-07-23": 3000, "2026-07-24": 4000},
                        "modelTokens": {"codex": 5000, "opencode": 2000},
                        "sessionPaths": ["/Users/example/private/session-a.jsonl", "/Users/example/private/session-b.jsonl"],
                        "activeFolderPaths": ["/Users/example/private/repo"],
                    }
                ),
                encoding="utf-8",
            )
            env["TOKENBAR_SUPPORT_DIR"] = str(no_identity_support)
            stats_only = subprocess.run(
                [str(CLI), "api", "--snapshot"],
                cwd=ROOT,
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            stats_only_payload = json.loads(stats_only.stdout)
            require(stats_only_payload["ok"] is False, "bundle should require a generated identity")
            require(stats_only_payload["identity"] is None, "bundle should not invent an identity")
            require(stats_only_payload["stats"]["totalTokens"] == 7000, "stats-only token total mismatch")
            require(stats_only_payload["stats"]["sessionCount"] == 2, "stats-only session count mismatch")
            require(stats_only_payload["reminders"]["schema"] == "tokenbar.reminders.v1", "stats-only bundle missing reminders")
            require(stats_only_payload["memoryPressure"]["schema"] == "tokenbar.memory_pressure.v1", "stats-only bundle missing memory pressure")
            require(stats_only_payload["guide"]["schema"] == "tokenbar.guide.v1", "stats-only bundle missing guide")
            require(stats_only_payload["providers"]["schema"] == "tokenbar.providers.v1", "stats-only bundle missing providers")
            measured = {provider["name"]: provider["status"] for provider in stats_only_payload["providers"]["providers"]}
            require(measured["Codex"] == "measured", "Codex should be measured in stats-only fixture")
            require(measured["OpenCode"] == "measured", "OpenCode should be measured in stats-only fixture")
            require(measured["Claude Code"] == "setup", "Claude Code should stay setup without local evidence")
            commands = {provider["name"]: provider["command"] for provider in stats_only_payload["providers"]["providers"]}
            require(commands["Codex"] == "tokenbar usage", "measured provider should point to tokenbar usage")
            require(commands["Claude Code"] == "tokenbar providers", "setup provider should point to tokenbar providers")
            codex_flow = next(provider["setupFlow"] for provider in stats_only_payload["providers"]["providers"] if provider["name"] == "Codex")
            claude_flow = next(provider["setupFlow"] for provider in stats_only_payload["providers"]["providers"] if provider["name"] == "Claude Code")
            require(all(step["done"] is True for step in codex_flow), "measured provider setup flow should be complete")
            require(all(step["done"] is False for step in claude_flow), "setup provider setup flow should stay incomplete")
            env["TOKENBAR_SUPPORT_DIR"] = str(support)

            snapshot = subprocess.run(
                [str(CLI), "api", "--snapshot"],
                cwd=ROOT,
                env=env,
                check=True,
                capture_output=True,
                text=True,
            )
            require(json.loads(snapshot.stdout)["schema"] == "tokenbar.builder_bundle.v1", "snapshot schema mismatch")
        finally:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)

    print("TokenBar safe identity API smoke passed")
    print("  routes: /v1/identity, /v1/stats, /v1/reminders, /v1/memory-pressure, /v1/guide, /v1/waste-lens, /v1/playbooks, /v1/providers, /v1/bundle, /health")
    print("  privacy: no raw prompt, transcript, source code, local path, email, token, or secret")
    print("  packaging: tokenbar api --snapshot returned tokenbar.builder_bundle.v1")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"TokenBar safe identity API smoke failed: {exc}", file=sys.stderr)
        raise
