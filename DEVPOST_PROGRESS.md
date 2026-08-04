# TokenBar Builder Identity progress

## 2026-07-23 — real-profile lifecycle and recursive public-payload audit

- Real compatibility proof: the newest private identity completed the six-stage analyze-to-proof action with 423 indexed sessions and 10.17B tokens in the recent seven-day window, then reloaded its proof, profile, feed, rankings, local receipt, and owner-bound revocation.
- Privacy hardening: the smoke harness now recursively rejects forbidden raw-prompt/transcript/source fields, local filesystem paths, owner keys, API-key/credential patterns, and transcript-shaped text across public run, proof, profile, feed, selective-share, private-boundary, and submitted-profile responses.
- Tests: deterministic fixture flow passed on port 8793; real local identity flow passed on port 8794; the original private identity remained byte-for-byte unchanged and the temporary public proof returned `404` after revocation.
- Judge handoff: `docs/JUDGE_FLOW.md` contains the isolated automated proof, visual local journey, offline verified ZIP path, revocation command, privacy contract, and post-July-13 eligibility list.
- Deployment: none. The installed app and hosted site were not replaced.

## 2026-07-23 — native Thread Store, adjustable usage, and safe storage map

- Change: the native Threads page now supports unlimited persisted boards and a Thread Store with four installable workflow kits. The ten-seat Crew Room was installed through the rendered UI and persisted with `Leading`, `In flight`, and `Handoffs` lanes.
- Collaboration boundary: seats are a real local ownership/handoff layout. Live people, invitations, and presence are intentionally labeled as requiring the future Clerk-backed workspace rather than simulated.
- Change: Usage now centers one animated total with a 1–30 day slider; Report uses a short `tokenbar report` command, a human-readable report ID, “evidence strength,” and a local verified download.
- Change: Storage now scans a fixed allowlist of generated dependency/build/cache folders under indexed Codex workspaces, shows a weighted bubble map, and offers only per-folder, confirmed, recoverable Move to Trash actions. Sessions, source, reports, receipts, and credentials cannot be removed there.
- Native proof: the isolated release build mapped 145 storage areas, identified 9.08 GB as reviewable generated weight, and kept 101.78 GB of Codex sessions protected and inspect-only. No file was trashed during verification.
- Tests: `swift build`, release `build-app.sh`, CLI parity/shell syntax, and `git diff --check` passed. Computer Use verified the Thread Store, Crew Room persistence, adjustable usage, Report, and Storage surfaces. The installed app and hosted site were not replaced.

## 2026-07-23 — native verified proof export and portable identity contract

- Change: the native Proof page now exports a local proof ZIP through a macOS save panel, runs the bundled `tokenbar proof` command, verifies it with `tokenbar verify`, and reveals only a verified artifact in Finder.
- Package: `index.html` is a responsive TokenBar-styled identity overview; the ZIP carries a sanitized identity JSON, latest report artifacts, rankings, comparison, timeline, explicit privacy manifest, and per-file SHA-256/byte-count receipt.
- Privacy fix: `tokenbar proof` and `tokenbar bundle` no longer copy the original path-bearing profile manifest or full 1.77 MB identity JSON. The sanitized identity is about 37 KB and removes raw prompt fields, transcript/source fields, local paths, personal emails, credentials, and secret-like values.
- Tests: debug and release macOS builds passed; strict code-sign verification passed; packaged CLI proof generation/verification passed; deliberate README tampering failed SHA-256 and byte-count verification; API, MCP, and full Builder Identity proof-action smokes passed; a clean wheel install reported `tokenbar 0.1.1` and generated/verified its own proof packet.
- Responsive proof: Playwright inspection passed at 1440 px and 390 px after fixing signal-row overflow; the final self-contained page has no external resources or console errors.
- Deployment: none. The installed app and hosted site were not replaced.

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

## 2026-07-18 — private passport preview no longer offers a share surface

- Change: the browser Create Identity preview now renders a private generation as `Owner-only`, with no token value, proof link, or copy-share control. Unlisted and public previews retain their direct-link/share controls.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed; `node --check docs/app.js` and `git diff --check` passed. The smoke now asserts that private previews gate all share controls.
- Browser artifact: none this run — no fresh browser capture was made. Existing layout-only proof remains `outputs/builder-identity-create-journey-20260718-1715.png` and contains no selected local artifact or private evidence.
- Privacy boundary: private mode does not render the returned token or actionable proof URL in the browser preview; raw transcripts, source code, credentials, private diffs, and local paths remain excluded.
- HUMAN_TEST: NOT RUN — no human manually selected an artifact, reviewed an unlisted share card, or copied its share text.
- Blocker: no automated product-path blocker; human browser confirmation is required.
- Next move: Arnav should perform one unlisted Create Identity run at `/profile`, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-18 — picker no longer echoes a private local filename

- Change: Create Identity now confirms a chosen artifact with the generic `Identity JSON selected locally` label instead of rendering its local filename. This keeps client, repository, or experiment names out of the page and any browser screenshot.
- Tests: `python3 scripts/smoke_builder_identity_flow.py`, `node --check docs/app.js`, and `git diff --check` passed. The smoke now rejects any browser-path filename echo.
- Browser artifact: none this run — the existing layout-only proof contains no selected artifact, token, transcript, source, secret, or private path.
- Privacy boundary: the browser still reads only the deliberate safe identity JSON after selection; raw transcripts, source code, credentials, private diffs, local paths, and now the selected local filename remain excluded from rendered proof.
- HUMAN_TEST: NOT RUN — no human manually selected an artifact, reviewed an unlisted share card, or copied its share text.
- Blocker: no automated product-path blocker; human browser confirmation is required.
- Next move: Arnav should perform one unlisted Create Identity run at `/profile`, verify the generic selection label, share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-19 — safe share-copy fallback works in local browser previews

- Change: the Create Identity passport’s explicit `Copy share preview` action now falls back to a temporary, selected safe-text field when the browser rejects Clipboard API access (common on local HTTP previews). The fallback never touches the selected identity JSON, local filename, path, raw transcript, source code, credential, or private diff.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed after the change; `node --check docs/app.js` and `git diff --check` passed. The smoke asserts both Clipboard API and safe local-preview fallback hooks.
- Browser artifact: `outputs/builder-identity-create-journey-20260719-0120.png` — fresh Chrome headless capture of local `http://127.0.0.1:8892/profile`; it shows the safe artifact picker, privacy choices, disabled preflight submit, and four concise stages with no selected artifact, token, transcript, source, secret, or private path.
- Privacy boundary: the fallback receives only the existing generated safe share summary; it cannot read or render private local evidence.
- HUMAN_TEST: NOT RUN — this automated capture does not prove a human selected an unlisted artifact, reviewed the generated share card, and copied its share text.
- Blocker: the closest missing gate remains manual browser verification of the unlisted Create Identity journey.
- Next move: Arnav should run one unlisted `/profile` flow, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share text, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-19 — share-copy result is announced without exposing the share text

- Change: the generated unlisted/public passport now includes a polite live status beside `Copy share preview`. It reports only whether the already-safe preview was copied; it never announces or renders the copied share text, selected artifact, filename, path, transcript, source, credential, or private diff.
- Tests: `python3 scripts/smoke_builder_identity_flow.py`, `node --check docs/app.js`, and `git diff --check` passed.
- Browser artifact: `outputs/builder-identity-create-journey-20260719-1334.png` — Chrome headless loaded the local `/profile` surface with no selected artifact or private evidence. This is a page-load capture only; it does not demonstrate the copy interaction.
- Privacy boundary: the live status contains success/failure wording only. Clipboard and fallback paths continue to receive only the existing safe share summary.
- HUMAN_TEST: NOT RUN — no human has selected an unlisted artifact, reviewed its share card, and confirmed the copied text.
- Blocker: the closest missing gate remains manual browser verification of the unlisted Create Identity journey.
- Next move: Arnav should complete one unlisted `/profile` flow, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share result, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-19 — spotlight privacy regression matches bounded local inference

- Change: corrected the builder-identity smoke assertion for the docs spotlight path. It now verifies the actual contract — raw session files are not uploaded — without falsely claiming that the local, bounded session inference is never read.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed (`run_7570975f50be1c45`, public `TBAR-173958CF86A9`, unlisted `TBAR-0534D618ECAA`); `node --check docs/app.js` and `git diff --check` passed.
- Browser artifact: `outputs/builder-identity-create-journey-20260719-1433.png` — fresh Chrome headless page-load proof of local `/profile`; no selected artifact, token, transcript, source, secret, or private path is shown.
- Privacy boundary: selected session material may be used only for bounded local inference; raw session files, transcripts, source, secrets, and private paths are not uploaded or rendered.
- HUMAN_TEST: NOT RUN — automated smoke and page-load capture do not prove a person selected an unlisted artifact, reviewed its share card, and confirmed the copied text.
- Blocker: the closest missing gate remains manual browser verification of the unlisted Create Identity journey.
- Next move: Arnav should complete one unlisted `/profile` flow, verify the share contract, title, TBAR token, safe-proof link, exclusion line, and copied share result, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-19 — changing privacy mode invalidates the prior share-card preview

- Change: after generating a passport, changing Private/Unlisted/Public now clears the prior preview and marks the share stage `Regenerate preview`. The earlier passport is explicitly described as unchanged, so a user must generate again before treating the selected privacy mode as the previewed share contract.
- Tests: `python3 scripts/smoke_builder_identity_flow.py` passed before and after the change; `node --check docs/app.js`, `python3 -m py_compile scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed. The smoke now asserts the privacy-change stale-preview guard.
- Browser artifact: none this run — no Chrome/Chromium executable was found for a fresh headless capture.
- Privacy boundary: changing privacy mode clears only the browser-rendered safe preview. It does not re-read or upload the artifact, and raw transcripts, source code, credentials, private diffs, local paths, and filenames remain excluded.
- HUMAN_TEST: NOT RUN — no human has selected an artifact, generated an unlisted passport, changed privacy mode, and reviewed the explicit regenerate state.
- Blocker: the closest missing gate remains manual browser verification of the unlisted Create Identity journey.
- Next move: Arnav should complete one unlisted `/profile` flow, verify the share contract, title, TBAR token, safe-proof link, exclusion line, copied share result, and the privacy-change regenerate behavior, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-19 — opening generated proof preserves the passport review

- Change: the unlisted/public `Open proof` action now opens the generated safe proof in a new tab with `noopener noreferrer`, keeping the Create Identity passport preview and its copy action available for review in the original tab.
- Tests: `python3 scripts/smoke_builder_identity_flow.py --port 8825` passed (`run_e14a8405e9a7e3cc`, public `TBAR-7610E49084F8`, unlisted `TBAR-534066BE0C16`); `node --check docs/app.js`, `python3 -m py_compile scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed. The smoke asserts the new-tab proof handoff.
- Browser artifact: none this run — no Chrome/Chromium executable was available for a fresh local capture.
- Privacy boundary: only the already-generated safe proof URL is opened. The selected artifact, raw transcripts, source code, credentials, private diffs, filenames, and local paths are neither included in the link nor rendered.
- HUMAN_TEST: NOT RUN — automated smoke does not prove a person selected an unlisted artifact, reviewed its share card, opened proof, and confirmed the copy result.
- Blocker: the closest missing gate remains manual browser verification of the unlisted Create Identity journey.
- Next move: Arnav should complete one unlisted `/profile` flow, verify the share contract, title, TBAR token, safe-proof link, exclusion line, copy result, and the retained passport preview after opening proof, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-19 — generated passports restate their share scope

- Change: the generated 60-second passport now includes a short `Share scope` receipt inside the card itself. An unlisted card says it is direct-link only and hidden from public discovery, feeds, and rankings, so that boundary remains visible after the journey scrolls to the card.
- Tests: `python3 scripts/smoke_builder_identity_flow.py`, `node --check docs/app.js`, and `git diff --check` passed. The smoke asserts the in-card unlisted scope copy.
- Browser artifact: `outputs/builder-identity-share-scope-20260719-1520.png` — fresh Chrome headless page-load proof of local `/profile`; it contains no selected artifact, token, transcript, source, secret, or private path. It is layout-only proof, not a generated-card interaction test.
- Privacy boundary: the receipt derives solely from the selected visibility mode and repeats no artifact content, filename, path, raw transcript, source code, credential, or private diff.
- HUMAN_TEST: NOT RUN — automated smoke and a page-load screenshot do not prove a person selected an unlisted artifact, reviewed its generated share card, and copied the share text.
- Blocker: the closest missing gate remains manual browser verification of the unlisted Create Identity journey.
- Next move: Arnav should complete one unlisted `/profile` flow, verify the in-card direct-link-only scope, title, TBAR token, safe-proof link, exclusion line, copied share result, and privacy-change regenerate behavior, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-20 — passport submit control names the selected privacy mode

- Change: once a safe local identity artifact passes its browser-only privacy check, the Create Identity submit control now says `Generate private/unlisted/public 60-second passport`. This keeps the choice legible at the exact generation step; before validation it remains neutral.
- Tests: `python3 scripts/smoke_builder_identity_flow.py --port 8827` passed (`run_24934a54b3113191`, public `TBAR-616DCB838998`, unlisted `TBAR-C48C1A2C91A5`); `node --check docs/app.js`, `python3 -m py_compile scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed. The smoke asserts the privacy-mode submit label.
- Browser artifact: `outputs/builder-identity-privacy-submit-20260720-0704.png` — fresh local Chrome headless capture of `/profile` with the mounted Create Identity entry surface visible and no selected artifact, token, transcript, source, secret, filename, or private path. It is layout proof only, not an interaction test.
- Privacy boundary: the label derives only from the selected privacy radio choice. It does not read, render, or upload artifact contents, filenames, paths, raw transcripts, source code, credentials, or private diffs.
- HUMAN_TEST: NOT RUN — automated smoke and layout capture do not prove a human selected an unlisted artifact, generated a passport, reviewed the share card, opened the proof, and confirmed copied text.
- Blocker: the closest missing gate remains manual browser verification of the unlisted Create Identity journey.
- Next move: Arnav should complete one unlisted `/profile` flow, verify the explicit unlisted submit label, share contract, title, TBAR token, safe-proof link, exclusion line, copy result, and retained passport preview after opening proof, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-20 — generated passport gives a safe final-review cue

- Change: generated passport cards now include a concise `Review next` receipt. Unlisted/public cards direct the builder to confirm the share scope, open the safe proof, then copy the already-safe share preview; private cards direct owner-only review before closing.
- Tests: `python3 scripts/smoke_builder_identity_flow.py --port 8827`, `node --check docs/app.js`, `python3 -m py_compile scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed.
- Browser artifact: `outputs/builder-identity-review-next-20260720-0732.png` — fresh local Chrome headless layout capture of `/profile`; it contains no selected artifact, token, transcript, source, secret, filename, or private path. It is layout proof only, not a generated-card interaction test.
- Privacy boundary: review text is derived only from the selected visibility mode. It neither reads nor displays artifact content, filenames, paths, raw transcripts, source code, credentials, or private diffs.
- HUMAN_TEST: NOT RUN — automated checks and layout capture do not prove a human selected an unlisted artifact, generated a passport, reviewed its share card, opened proof, and confirmed copied text.
- Blocker: the closest missing gate remains manual browser verification of the unlisted Create Identity journey.
- Next move: Arnav should complete one unlisted `/profile` flow, confirm the review cue, title, TBAR token, safe-proof link, exclusion line, copy result, and retained passport preview after opening proof, then explicitly approve any `HUMAN_TEST=PASS` claim.

## 2026-07-20 — exported multi-agent usage becomes an honest Builder Pulse

- Change: `tokenbar usage REPORT.txt` now parses the box-table Coding (Agent) CLI Usage Report into a concise terminal pulse; `tokenbar usage REPORT.txt --json` emits `tokenbar.usage_pulse.v1` for a future social/profile card. The payload separates input/output from cache traffic, labels reported costs as estimates, and includes provider mix, peak day, seven-day pace, commentary, and an explicit quality disclaimer.
- Evidence: the supplied 700-line report produced `80.24B` measured tokens, `14.06B` over the latest seven days, `5.54B` input/output, `74.70B` cache traffic, `93.1%` cache share, and Codex at `98.8%` of attributed usage. The parser warns that volume does not prove useful output.
- Tests: file import, stdin import, JSON assertions, `bash -n bin/tokenbar`, source/installed-launcher sync checks, `git diff --check`, and `python3 scripts/smoke_builder_identity_flow.py` passed (`run_af3062529ff553c9`, public `TBAR-5886EC01F8D1`, unlisted `TBAR-520DEA551169`).
- Privacy boundary: the JSON contract marks the raw report, raw transcripts, and source code as excluded. It contains aggregate usage evidence only and does not include local paths.
- HUMAN_TEST: NOT RUN — no human reviewed a rendered social card made from `tokenbar.usage_pulse.v1`.
- Next move: mount this aggregate payload as an optional proof-card module only after the existing manual unlisted Create Identity journey passes; keep shipped-work and verification evidence above raw token volume.

## 2026-07-20 — proof handoff discloses its new-tab behavior

- Change: the generated unlisted/public passport’s `Open proof` action now visibly says `(new tab)` and exposes the same behavior in its accessible label. The browser keeps the in-progress passport review in its original tab by design.
- Tests: `python3 scripts/smoke_builder_identity_flow.py --port 8827`, `node --check docs/app.js`, `python3 -m py_compile scripts/smoke_builder_identity_flow.py`, and `git diff --check` passed.
- Browser artifact: none this run — no local Chrome/Chromium executable was available for a fresh capture.
- Privacy boundary: the disclosure derives only from the already-safe proof action. It does not read, render, or upload artifact contents, filenames, paths, raw transcripts, source code, credentials, or private diffs.
- HUMAN_TEST: NOT RUN — automated checks do not prove a human selected an unlisted artifact, generated a passport, reviewed its share card, opened proof, and confirmed copied text.
- Blocker: the closest missing gate remains manual browser verification of the unlisted Create Identity journey.
- Next move: Arnav should complete one unlisted `/profile` flow, confirm the new-tab disclosure, share scope, title, TBAR token, safe-proof link, exclusion line, copy result, and retained passport preview, then explicitly approve any `HUMAN_TEST=PASS` claim.
