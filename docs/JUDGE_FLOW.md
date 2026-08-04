# TokenBar 60-Second Judge Flow

TokenBar answers four questions from local Codex evidence:

1. What kind of builder am I becoming?
2. What did I complete?
3. What evidence supports the story?
4. What should I improve next?

Raw prompts, transcripts, source code, local paths, and credentials are not part of the public contract.

## Fast Reproducible Proof

From the repository:

```bash
python3 scripts/smoke_builder_identity_flow.py --port 8793 --use-existing-identity
```

This uses the newest private local identity, starts an isolated server, completes the six-stage action, reloads the proof/profile/feed/rankings, verifies device-owned revocation, confirms the original identity is byte-for-byte unchanged, then removes the temporary public proof.

Expected result:

```text
TokenBar real Builder Identity compatibility smoke passed
privacy: recursive public-payload audit passed
```

The recursive audit rejects forbidden raw-content fields, local filesystem paths, owner keys, credential-shaped values, and transcript-shaped text in every public JSON surface.

## Visual Local Journey

Terminal A:

```bash
TOKENBAR_ACTION_STORE_PATH=/tmp/tokenbar-action-store.json \
TOKENBAR_PROFILE_STORE_PATH=/tmp/tokenbar-profile-store.json \
python3 scripts/tokenbar_local_server.py --port 8768
```

Terminal B:

```bash
TOKENBAR_ACTION_URL=http://127.0.0.1:8768/api/actions \
TOKENBAR_PROFILE_UPLOAD_URL=http://127.0.0.1:8768/api/profiles \
./bin/tokenbar prove
```

The CLI prints a run id, `TBAR-...` safe token, proof card, public profile, For You feed, rankings, privacy receipt, and the list of data that stayed local. Open the printed profile URL.

Reload without analysis or another upload:

```bash
TOKENBAR_ACTION_URL=http://127.0.0.1:8768/api/actions \
TOKENBAR_PROFILE_UPLOAD_URL=http://127.0.0.1:8768/api/profiles \
./bin/tokenbar proof latest
```

Remove the public proof while retaining all local reports:

```bash
TOKENBAR_ACTION_URL=http://127.0.0.1:8768/api/actions \
TOKENBAR_PROFILE_UPLOAD_URL=http://127.0.0.1:8768/api/profiles \
./bin/tokenbar revoke latest
```

## Portable Offline Report

```bash
./bin/tokenbar report
./bin/tokenbar proof --output /tmp/tokenbar-builder-proof.zip
./bin/tokenbar verify /tmp/tokenbar-builder-proof.zip
```

The ZIP is local, self-contained, checksum-verified, and does not require a TokenBar server.

## Post-July-13 Work

- Six-stage, idempotent Builder Identity server action with progress, result, evidence, and retry state.
- Device-owned proof/profile updates and revocation.
- Public, unlisted, and private sharing contracts with redaction controls.
- Reloadable proof card, profile, For You feed, and rankings.
- Native macOS Builder Story, adjustable usage, thread boards/store, verified report export, and safe storage map.
- Read-only sanitized local API and Codex MCP contract.
- Recursive public-payload privacy regression audit.

No production deployment or installed-app replacement is required for this judge flow.
