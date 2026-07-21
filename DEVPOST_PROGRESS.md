# TokenBar Builder Identity progress

## 2026-07-17 — browser-first identity creation journey

- Change: added a Profile-page Create Identity journey that lets a builder select one local `tokenbar.identity.v1` JSON, choose private/unlisted/public visibility (default: unlisted), see four concise processing stages, and render the returned 60-second passport/share-card preview through the existing `POST /api/actions` path.
- Tests: `node --check docs/app.js` passed; `python3 scripts/smoke_builder_identity_flow.py` passed; `git diff --check` passed.
- Browser artifact: `outputs/builder-identity-create-journey-20260717.png` shows the local journey at `http://127.0.0.1:8876/profile`.
- Privacy boundary: the browser reads only the user-selected JSON and refuses artifacts unless both `rawTranscriptsIncluded` and `sourceCodeIncluded` are explicitly `false`; no raw transcripts, source, private diffs, credentials, or environment files are accepted or shown. No public posting occurred.
- HUMAN_TEST: NOT RUN — the screenshot confirms layout only; manually choose a generated safe identity JSON and verify the unlisted passport/share-card preview before marking PASS.
- Blocker: none for the local path.
- Next move: conduct the one manual file-picker run against `/api/actions`, then update `HUMAN_TEST` with the resulting token/run proof.

## 2026-07-18 — generated passport now has a truthful share-card preview

- Change: replaced the generic post-generation success box on `docs/profile.html`'s Create Identity journey with a compact preview rendered from the returned `/api/actions` proof: selected visibility, title, archetype/headline, proof score, derived proof token, safe-proof link, and copyable share preview.
- Tests: `node --check docs/app.js` passed; `git diff --check` passed. A local `POST /api/actions` using only `/tmp/tokenbar-safe-identity.json` returned an unlisted proof for `Safe Preview Builder` with proof score `82`, a reloadable profile URL, share copy, and a `neverUsed` list including raw transcripts and source code.
- Browser artifact: none this run. The form layout was opened at `http://127.0.0.1:8877/profile`, but the automated file-chooser session did not remain available to complete a visual post-submit capture.
- Privacy boundary: preview uses only response fields already safe for the selected share mode; it repeats the server receipt's excluded fields and does not render the local JSON, raw transcripts, source code, private diffs, credentials, or filesystem paths.
- HUMAN_TEST: NOT RUN — visual/manual confirmation of file selection, generated preview, and copied share text is still required.
- Blocker: no product blocker; current automated browser binding could not retain the file chooser after local form inspection.
- Next move: one manual unlisted file-picker submission and screenshot of the populated preview, then mark `HUMAN_TEST=PASS` only if the title, token, safe-proof link, and exclusion line are visible.

## 2026-07-18 — failed passport requests have a guarded retry

- Change: after a safe artifact passes local validation but its `/api/actions` passport request fails, Create Identity now exposes a “Try passport generation again” control. It reuses the normal submission guard, stays hidden for unsafe/local-read failures and replacement artifacts, and cannot run while a request is pending.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed; `node --check docs/app.js` passed; `python3 -m py_compile scripts/smoke_builder_identity_flow.py` passed; `git diff --check` passed.
- Browser artifact: none this run — no Chromium/Chrome executable is available in this environment, so no fresh file-picker screenshot was possible. The existing layout-only capture remains `outputs/builder-identity-create-journey-20260717.png`.
- Privacy boundary: retry only reuses the already selected, browser-locally validated safe artifact through the existing action request. It does not reveal the JSON, raw transcripts, source code, credentials, private diffs, or local paths.
- HUMAN_TEST: NOT RUN — no human manually selected an artifact, verified a failure/retry state, generated an unlisted share card, or copied its share text.
- Blocker: no automated product-path blocker; fresh visual confirmation needs an available browser or a manual capture.
- Next move: Arnav should complete one unlisted picker run at `/profile`, confirm the share contract, title, TBAR token, safe-proof link, exclusion line, copied share text, and (if practical) retry behavior before explicit approval of `HUMAN_TEST=PASS`.

## 2026-07-18 — deterministic Builder Identity smoke preflight

- Change: made `scripts/smoke_builder_identity_flow.py` seed its local-only builder-signal inbox in both default and `--run-claim` modes, and load the served stylesheet before checking the saved-proof shortcut. The standard proof route no longer depends on the optional identity-claim branch or crashes on an undefined stylesheet variable.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed; `node --check docs/app.js` passed; `python3 -m py_compile scripts/smoke_builder_identity_flow.py` passed; `git diff --check` passed.
- Browser artifact: no new screenshot this run; the smoke confirmed the social, rankings, profile, and proof HTML mounts locally. The existing layout-only screenshot remains `outputs/builder-identity-create-journey-20260717.png`.
- Privacy boundary: the seeded reference stays in a temporary local store with `networkUploaded: false`; smoke continues to verify raw transcripts and source code are false and private/unlisted proof boundaries hold.
- HUMAN_TEST: NOT RUN — no human manually selected an artifact or copied the generated share preview.
- Blocker: none for automated proof; the remaining gate needs human visual confirmation.
- Next move: manual unlisted file-picker submission at `/profile`, confirm title, TBAR token, safe-proof link, exclusion line, and copied share text; then record explicit human approval before `HUMAN_TEST=PASS`.

## 2026-07-18 — generated passport stays in the Create Identity handoff

- Change: after a safe local artifact produces its passport, the browser keeps the compact share-card preview in view and moves keyboard focus there instead of scrolling away to the lower action-inspection panel.
- Tests: `node --check docs/app.js` passed; `python3 scripts/smoke_builder_identity_flow.py` passed; `git diff --check` passed. The smoke now asserts that the generated passport remains the browser handoff target.
- Browser artifact: none this run; no file-picker submission was performed by automation.
- Privacy boundary: unchanged — the preview still receives only the safe proof response and shows the excluded-fields receipt, not local JSON contents, raw transcripts, source, credentials, or filesystem paths.
- HUMAN_TEST: NOT RUN — the remaining proof is a human unlisted picker submission with the resulting share card visibly confirmed.
- Blocker: none for the automated path.
- Next move: Arnav should select a safe generated identity JSON at `/profile`, choose unlisted, generate the passport, and confirm the title, TBAR token, safe-proof link, exclusion line, and copied share text.

## 2026-07-18 — local artifact preflight before the passport request

- Change: the Create Identity file picker now reads the selected file locally before submission, confirms the exact `tokenbar.identity.v1` schema and that raw transcripts/source are explicitly excluded, then marks the first two processing stages complete. It shows no JSON contents or local path.
- Tests: `node --check docs/app.js` passed; `python3 scripts/smoke_builder_identity_flow.py` passed; `git diff --check` passed.
- Browser artifact: none this run. A local server was available at `http://127.0.0.1:8891/profile`, but the in-app browser binding timed out before a visual capture could be taken.
- Privacy boundary: the preflight is browser-local and transmits nothing; submission still sends only the selected safe identity artifact to the existing local `/api/actions` flow.
- HUMAN_TEST: NOT RUN — browser automation did not create human evidence. Manual unlisted picker submission still needs title, TBAR token, safe-proof link, exclusion line, and copied share text visibly confirmed.
- Blocker: browser capture attachment timed out; no product-path blocker.
- Next move: complete the manual unlisted picker run and record explicit human confirmation before marking `HUMAN_TEST=PASS`.

## 2026-07-18 — passport generation waits for a completed local safety check

- Change: disabled the browser Create Identity submit control until the selected JSON completes local `tokenbar.identity.v1` and privacy-boundary validation; submission rechecks the schema before calling `/api/actions`.
- Tests: `node --check docs/app.js` passed; `python3 scripts/smoke_builder_identity_flow.py` passed; `python3 -m py_compile scripts/smoke_builder_identity_flow.py` passed; `git diff --check` passed. The smoke now asserts that the browser handler contains the preflight submission gate.
- Browser artifact: none this run; no automated file-picker submission or new screenshot was created.
- Privacy boundary: no artifact is submitted while validation is pending or unsafe; the local check still requires raw transcripts and source code to be explicitly excluded and never renders the local JSON or filesystem path.
- HUMAN_TEST: NOT RUN — no human manually selected an artifact, reviewed the generated unlisted share card, or copied its share text.
- Blocker: no automated-product blocker; browser visual confirmation is still human-only evidence.
- Next move: Arnav should run the unlisted picker journey at `/profile` and confirm the title, TBAR token, safe-proof link, exclusion line, and copied share text before approving `HUMAN_TEST=PASS`.

## 2026-07-18 — privacy choice explains its discovery boundary

- Change: after a safe local identity artifact passes its local privacy check, Create Identity now immediately explains the selected visibility: private disables token/profile/feed/ranking lookups, unlisted is direct-link-only and excluded from public discovery, and public may appear in TokenBar discovery. The state reiterates that raw transcripts and source code remain excluded.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed before and after the change; `node --check docs/app.js`, `python3 -m py_compile scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed. The smoke now asserts the selected-visibility explanation exists.
- Browser artifact: none this run — no Chromium/Chrome executable is available in this environment. The existing layout-only capture remains `outputs/builder-identity-create-journey-20260717.png`.
- Privacy boundary: this is browser-only copy derived from the selected share mode; it does not read, render, or upload additional artifact content, and raw transcripts/source code remain excluded before the existing `/api/actions` request.
- HUMAN_TEST: NOT RUN — no human manually selected an artifact, reviewed the generated unlisted share card, or copied its share text.
- Blocker: fresh browser capture unavailable in this environment; no automated product-path blocker.
- Next move: manual unlisted Create Identity run at `/profile`, confirming the visibility explanation, title, TBAR token, safe-proof link, exclusion line, and copied share text before explicit approval of `HUMAN_TEST=PASS`.

## 2026-07-18 — privacy choice now has a pre-generation share contract

- Change: once a selected `tokenbar.identity.v1` artifact passes the browser-local safety check, Create Identity shows a visibility-specific share contract before generation: private creates no token or discoverable surface, unlisted creates a direct-link token but remains out of discovery, and public can expose only title, archetype, proof score, and token. It repeats the excluded raw transcripts, source, credentials, private diffs, and local paths.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed before and after the change; `node --check docs/app.js`, `python3 -m py_compile scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed. The smoke now asserts the safe share-contract mount and handler exist.
- Browser artifact: none this run — no browser capture was available in this environment, so no local file-picker submission was automated.
- Privacy boundary: the contract is derived only from selected visibility after the local safety check; it neither renders artifact contents nor makes a request, and it explicitly preserves raw-text, source, credential, diff, and path exclusions.
- HUMAN_TEST: NOT RUN — no human has manually selected an artifact, reviewed the generated unlisted share card, or copied its share text.
- Blocker: no automated product-path blocker; a fresh browser screenshot still needs an available browser or manual capture.
- Next move: Arnav should complete one unlisted picker run at `/profile`, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-18 — passport request failures preserve completed safety stages

- Change: when the Create Identity `/api/actions` request fails after a valid local artifact and privacy check, the four-stage journey now leaves stages 1–2 complete and marks only “Build identity passport” as failed; “Preview share card” remains not created. Invalid local artifacts still stop at the safety stages.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed before and after the change; `node --check docs/app.js` and `git diff --check` passed. The smoke now asserts the browser failure state cannot mislabel a request failure as an unsafe artifact.
- Browser artifact: none this run — no Chromium/Chrome executable is available in the environment, so no fresh file-picker screenshot was possible.
- Privacy boundary: a network/action failure does not expose the selected JSON or alter the local safety boundary; no raw transcripts, source code, credentials, private diffs, or local paths are rendered.
- HUMAN_TEST: NOT RUN — no human has manually selected an artifact, reviewed the generated unlisted share card, or copied its share text.
- Blocker: no product-path blocker; fresh visual confirmation needs an available browser or a manual capture.
- Next move: Arnav should complete one unlisted picker run at `/profile`, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-18 — passport generation prevents duplicate requests

- Change: while the browser sends a validated identity artifact to `/api/actions`, Create Identity now marks the form busy and temporarily disables the file picker, visibility controls, and submit button. It restores the controls afterward, preventing repeated clicks from creating duplicate identity-passport actions.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed; `node --check docs/app.js` passed; `python3 -m py_compile scripts/smoke_builder_identity_flow.py` passed; `git diff --check` passed. The smoke now asserts the busy-state duplicate-request guard.
- Browser artifact: none this run — no Chromium/Chrome executable is installed in this environment.
- Privacy boundary: unchanged — the lock applies only during the existing safe-artifact request and does not expose, render, or upload any extra local content; raw transcripts, source code, credentials, private diffs, and local paths remain excluded.
- HUMAN_TEST: NOT RUN — no human has manually selected an artifact, reviewed the generated unlisted share card, or copied its share text.
- Blocker: fresh browser proof requires a browser/manual capture; no automated product-path blocker.
- Next move: Arnav should complete one unlisted picker run at `/profile`, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-18 — oversized artifacts stop before browser reading or upload

- Change: the Create Identity picker now rejects files over 240 KB before calling `file.text()` or `/api/actions`, with an explicit “not read or uploaded” status. The picker copy now states the safe identity artifact limit.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed before and after the change; `node --check docs/app.js` and `git diff --check` passed. The smoke now asserts the browser-local oversized-artifact privacy guard.
- Browser artifact: none this run — no Chromium/Chrome executable is installed in this environment.
- Privacy boundary: an oversized selected file is not read into browser memory or sent to the action endpoint; raw transcripts, source code, credentials, private diffs, and local paths remain excluded.
- HUMAN_TEST: NOT RUN — no human manually selected an artifact, reviewed the generated unlisted share card, or copied its share text.
- Blocker: fresh visual confirmation still needs an available browser or a manual capture; no automated product-path blocker.
- Next move: Arnav should complete one unlisted picker run at `/profile`, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-18 — replacing an artifact clears the prior passport preview

- Change: choosing a new local identity JSON now immediately removes any prior generated passport/share-card preview before the replacement artifact is inspected. A previous TBAR token or safe-proof link cannot be mistaken for the newly selected artifact.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed before and after the change; `node --check docs/app.js`, `python3 -m py_compile scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed. The smoke now asserts the stale-preview guard exists.
- Browser artifact: none this run. No browser file-picker submission or fresh screenshot was created.
- Privacy boundary: this only clears browser-rendered safe response data; it does not read or upload the replacement artifact, and raw transcripts, source code, credentials, private diffs, and local paths remain excluded.
- HUMAN_TEST: NOT RUN — no human manually selected an artifact, reviewed the generated unlisted share card, or copied its share text.
- Blocker: no automated product-path blocker; fresh visual confirmation needs an available browser or a manual capture.
- Next move: Arnav should complete one unlisted picker run at `/profile`, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-18 — submitted project metadata survives the passport handoff

- Change: `tokenbar submit` now exports its selected public project metadata to the local identity generator, generated passport filenames include seconds to prevent same-minute overwrite, and the profile endpoint uses current token-proof submission metadata instead of a stale cached project card.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed; `node --check docs/app.js`, `python3 -m py_compile api/profiles.py scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed. The smoke verified CLI Submitted Proof title, event, track, repo URL, unlisted/private boundaries, and the browser-first static journey contract.
- Browser artifact: `outputs/builder-identity-create-journey-20260718-1535.png` — Chrome headless capture of local `http://127.0.0.1:8891/profile`; it contains no selected file, token, transcript, source, secret, or private path.
- Privacy boundary: only deliberate public project metadata (title, event, track, public repo/demo URLs, tagline) is exported into the generated safe identity; raw transcripts, source code, credentials, private diffs, and local paths remain excluded.
- HUMAN_TEST: NOT RUN — the automated capture is visual proof only; no human selected an artifact, reviewed an unlisted share card, or copied share text.
- Blocker: human browser confirmation is still required; no automated product-path blocker.
- Next move: Arnav should complete one unlisted Create Identity run at `/profile` and confirm the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text before explicitly approving `HUMAN_TEST=PASS`.

## 2026-07-18 — newly selected artifacts get a distinct passport request

- Change: Create Identity now assigns a random browser-local selection key whenever the user chooses an artifact. Retrying that same selection remains idempotent, while a newly selected artifact cannot receive a previously generated passport merely because it has the same identity token.
- Tests: `node --check docs/app.js`, `python3 scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed.
- Browser artifact: none this run — no Chrome/Chromium executable is available for a fresh local capture. The existing `outputs/builder-identity-create-journey-20260718-1535.png` remains layout-only proof and includes no selected artifact or private evidence.
- Privacy boundary: the selection key is random and never derives from or displays the artifact contents, local filename, or filesystem path. The existing raw transcript, source code, credential, private diff, and local-path exclusions remain intact.
- HUMAN_TEST: NOT RUN — automated smoke and a layout-only capture do not prove a person selected an artifact, reviewed an unlisted share card, or copied share text.
- Blocker: no automated product-path blocker; a browser/manual capture is required for the human test.
- Next move: Arnav should perform one unlisted Create Identity run at `/profile`, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-18 — submit rechecks the approved local artifact

- Change: Create Identity now captures the approved browser-local selection key at submit time and rechecks that the same file is still selected after its local read, before requesting `/api/actions`. A replacement artifact cannot be submitted under stale approval or an older idempotency key.
- Tests: `python3 scripts/smoke_builder_identity_flow.py`, `node --check docs/app.js`, and `git diff --check` passed. The smoke asserts the stale-selection rejection and the submit-scoped idempotency key.
- Browser artifact: `outputs/builder-identity-create-journey-20260718-1715.png` — Chrome headless capture of local `/profile`; it contains no selected artifact, token, transcript, source, secret, or private path. Later anchored capture attempts were blank and are not evidence.
- Privacy boundary: the selection key is random browser-local state. The identity JSON is rechecked locally before the existing action request; raw transcripts, source code, credentials, private diffs, and local paths remain excluded.
- HUMAN_TEST: NOT RUN — automated smoke and a layout capture do not show a human selecting an artifact, reviewing an unlisted share card, or copying share text.
- Blocker: no automated product-path blocker; human browser confirmation is still required.
- Next move: Arnav should perform one unlisted Create Identity run at `/profile`, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.
