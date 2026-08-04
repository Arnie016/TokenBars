# TokenBar Builder Identity Action

New after July 13: TokenBar has a narrow server-backed Builder Identity proof action.

The action turns a local `tokenbar.identity.v1` artifact into an inspectable proof-card run. It is intentionally smaller than the full profile system: one explicit action, one idempotent run id, ordered stages, a persisted proof card, and an opt-in share URL.

## Contract

`POST /api/actions`

```json
{
  "action": "builder_identity.proof_card.v1",
  "idempotencyKey": "sha256-of-safe-identity",
  "identity": {
    "schema": "tokenbar.identity.v1",
    "token": "TBAR-...",
    "privacy": {
      "rawTranscriptsIncluded": false,
      "sourceCodeIncluded": false
    }
  }
}
```

The server returns:

- `runId`
- `status`
- ordered `stages`
- `result.proofCardUrl`
- `proof` with safe aggregate facts
- `proof.builderStory` with evidence-backed identity axes

The CLI also sends `X-TokenBar-Owner-Key` when publishing. The raw key stays on
the device with `0600` permissions; the server stores only its SHA-256 owner
identifier. This binds later unpublishing to the device that created the proof.

The same owner binding protects `POST /api/profiles`. A public `TBAR-...` token
is a read-only proof pointer: anyone may use it to view the profile, For You
entry, or rankings placement, but it cannot authorize edits. Profile creation
and project-metadata updates require the private `X-TokenBar-Owner-Key` header,
and the server stores only its SHA-256 device identifier. Legacy unbound
profiles must be republished from the CLI before they can be edited.

To remove a public proof:

```json
{
  "action": "builder_identity.revoke.v1",
  "token": "TBAR-..."
}
```

The same owner-key header is required. A successful revocation scrubs the stored
proof payload and removes token, profile, feed, and ranking lookups. It does not
delete local identity JSON, HTML, PDF, Skill.md, or usage history.

`GET /api/actions` also returns a safe social payload built only from persisted proof cards:

- `feed`: public proof-card summaries for the For You surface
- `loopRankings`: proof cards ranked by loop maturity and proof strength
- `privacyBoundary`: explicit confirmation that raw transcripts and source code are not included

Durable storage is opt-in. By default the local smoke path uses `TOKENBAR_ACTION_STORE_PATH`
or `/tmp/tokenbar-action-store.json`. For production proof-action persistence:

1. Run `docs/tokenbar_actions_supabase.sql` in Supabase.
2. Set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
3. Set `TOKENBAR_ACTION_STORE=supabase`.
4. (Optional hardening) set `TOKENBAR_ACTION_WRITE_TOKEN=<random-32+ chars>` to require
   `Authorization: Bearer <token>` (or `X-TokenBar-Owner-Token`) on `POST /api/actions`.
5. Current TokenBar clients automatically bind each publish to a private device key. `TOKENBAR_ACTION_OWNER_ID=<stable-owner-id>` remains an optional server-managed fallback for legacy clients.
6. Check `GET /api/actions?health=1`.
7. Check `GET /api/profiles?health=1` and confirm `actionProofFallbackDurable = true`.

This explicit switch prevents a production profile database from accidentally
breaking proof actions before the proof-action table exists.

## Builder Story Schema

The action now emits `tokenbar.builder_story.v1`. It is not a vanity score and is not a leaderboard. It explains what the builder appears to be developing, how confident the system is, and what evidence is allowed to support that claim.

Axes:

- `craftTaste`
- `systemsThinking`
- `completion`
- `ambition`
- `learningVelocity`
- `discernment`

Each axis includes:

- `score`
- `confidence`
- `claim`
- `provenance`

The story also includes:

- `whatProved`
- `tradeoffs`
- `recovery`
- `nextFrontier`
- `uncertainties`
- `shareViews.private`
- `shareViews.public`
- `shareViews.selective`

## Privacy Boundary

The CLI sends a compact safe identity artifact. It strips large visual catalogs and never uploads raw prompts, raw transcripts, source code, raw diffs, `.env` files, credentials, or secrets.

The action rejects payloads that do not declare:

- `privacy.rawTranscriptsIncluded = false`
- `privacy.sourceCodeIncluded = false`
- `sessionAnalysis.rawTranscriptsIncluded = false` when session analysis is present
- `shippingAnalysis.sourceCodeIncluded = false` and `shippingAnalysis.rawDiffsIncluded = false` when shipping analysis is present

## Portable Proof Packet

`tokenbar proof` is the offline handoff for a Builder Identity. It does not call the
proof action or upload anything. The generated ZIP contains:

- `index.html`: self-contained, responsive Builder Identity overview
- `latest/*.identity.json`: sanitized generated identity and aggregate evidence only
- latest HTML report, Skill.md, and PDF when present
- `local-rankings.txt`, `compare-latest.txt`, and `timeline.html`
- `tokenbar-proof-manifest.json`: privacy boundary and package inventory
- `tokenbar-proof-verification.json`: SHA-256 and byte count for every payload

The original profile manifest is intentionally excluded because it contains local artifact
paths. The shareable identity copy removes raw prompt fields, transcript/source-code fields,
local paths, personal emails, credentials, and secret-like values.

```bash
tokenbar proof --output ~/Desktop/tokenbar-builder-proof.zip
tokenbar verify ~/Desktop/tokenbar-builder-proof.zip
```

Verification fails when a payload changes after packaging or a text payload exposes a local
filesystem path. The hash ledger proves packet integrity, not the human identity of its owner.

## Local Smoke

Fast one-command verifier using the latest local identity JSON:

```bash
python3 scripts/smoke_builder_identity_flow.py --port 8771
```

Full verifier that first creates a fresh private claim:

```bash
python3 scripts/smoke_builder_identity_flow.py --port 8771 --run-claim
```

Manual smoke:

```bash
TOKENBAR_ACTION_STORE_PATH=/tmp/tokenbar-action-store.json \
TOKENBAR_PROFILE_STORE_PATH=/tmp/tokenbar-profile-store.json \
  python3 scripts/tokenbar_local_server.py --port 8768

# In another terminal:
tokenbar claim
TOKENBAR_ACTION_URL=http://127.0.0.1:8768/api/actions \
TOKENBAR_PROFILE_UPLOAD_URL=http://127.0.0.1:8768/api/profiles \
  tokenbar publish-proof

# Remove the newest proof published by this device; local reports remain.
TOKENBAR_ACTION_URL=http://127.0.0.1:8768/api/actions \
  tokenbar revoke latest

curl -fsS 'http://127.0.0.1:8768/api/actions?run=run_...'
curl -fsS -H 'Accept: application/json' 'http://127.0.0.1:8768/api/actions?token=TBAR-...'
curl -fsS -H 'Accept: application/json' 'http://127.0.0.1:8768/api/profiles?token=TBAR-...'
curl -fsS 'http://127.0.0.1:8768/api/actions?health=1'
```

`publish-proof` is the product-facing command. `action latest` remains an advanced alias.

Observed local proof on July 14:

- run id: `run_2ecc99d4b1df7b01`
- stages: 6 complete
- sessions: 219
- tokens: 36.01B
- privacy: raw transcripts false, source code false

Observed real local proof on July 15:

- run id: `run_f3413f133f5caf31`
- token: `TBAR-CC6A49DE1965`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- stages: 6 complete
- sessions: 197
- tokens: 5.13B
- proof score: 59/100
- loop maturity: 66/100
- profile fallback: complete proof/profile/social/rankings/loop-ranking links
- privacy: raw transcripts false, source code false

Observed local proof-server smoke on July 15:

- local server: `python3 scripts/tokenbar_local_server.py --port 8768`
- automated verifier: `python3 scripts/smoke_builder_identity_flow.py --port 8771`
- run id: `run_bf77341d7c0cfc81`
- token: `TBAR-642165AB01B0`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- stages: 6 complete
- sessions: 197
- tokens: 5.16B
- proof score: 59/100
- loop maturity: 66/100
- proof card/profile/social/rankings/loop-ranking links: present in `/api/actions` feed
- uncertainty field: present for social proof cards
- privacy: raw transcripts false, source code false

Observed full fresh-claim verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8772 --run-claim`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- stages: 6 complete
- sessions: 197
- proof score: 59/100
- loop maturity: 66/100
- mounted pages checked: `/social`, `/rankings`, `/profile`, proof HTML, public profile HTML
- privacy: raw transcripts false, source code false

Observed rankings-entry verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8773`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- rankings page has its own `TBAR-...` token lookup plus proof/profile/loop-ranking mounts
- privacy: raw transcripts false, source code false

Observed social-share verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8774`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- social page includes a real share-proof action instead of inert feed buttons
- dynamic feed cards use proof/profile URLs and generated share copy when present
- privacy: raw transcripts false, source code false

Observed CLI quickstart verifier on July 15:

- repo launcher, packaged source, and installed CLI are byte-identical: `bin/tokenbar`, `src/tokenbar/tokenbar`, `/Users/arnav/.local/bin/tokenbar`
- `tokenbar quickstart` now describes the current `tokenbar claim` -> inspect -> `tokenbar publish-proof` -> paste `TBAR-...` flow
- command: `python3 scripts/smoke_builder_identity_flow.py --port 8775`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- privacy: raw transcripts false, source code false

Observed action-feed share verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8776`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- `/api/actions` feed includes `shareUrl`, `shareCopy`, proof/profile/social/ranking URLs, and uncertainty copy
- share copy explicitly says no raw transcripts or source code are uploaded
- privacy: raw transcripts false, source code false

Observed profile-command-center verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8777`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- `/profile` now frames the public handoff as `tokenbar claim` -> `tokenbar publish-proof` -> `tokenbar social`
- profile landing page shows private/selective/public share boundaries before heavier proof details
- judge-flow section explains local evidence -> server action -> selective profile -> reloadable proof
- privacy: raw transcripts false, source code false

Observed generated-profile story verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8778`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- `/api/profiles?token=...` now puts the builder story before the memorandum/PDF activation block
- public profile HTML includes a 60-second read: what kind of builder, what they proved, and what remains honest
- public profile HTML includes safe boundaries: no raw transcripts, no source code, safe aggregates only
- public profile HTML includes a share preview when the proof action supplies share copy
- privacy: raw transcripts false, source code false

Observed social-feed safety verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8779`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- `/social` static fallback cards include a visible safety receipt
- dynamic For You feed renderer includes the same safety receipt for action-feed cards
- feed cards spell out: no raw transcripts, no source code, generated proof artifact only
- privacy: raw transcripts false, source code false

Observed ranking-transparency verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8780`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- `/rankings` includes the `Proof beats spend` ranking contract and visible formula weights
- `/api/actions` feed cards include `rankingBreakdown` with proof, loop, specificity, verified outcomes, range, and capped token safety components
- token volume is capped at 2% of the composite ranking score, and verified outcomes are given primary weight
- privacy: raw transcripts false, source code false

Observed self-over-time verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8781`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- proof JSON and public profile JSON include `selfComparison` cards derived from safe aggregate windows
- proof HTML and public profile HTML include `Compared to yourself over time`
- comparison basis states safe aggregate windows only; no raw transcripts or source code
- privacy: raw transcripts false, source code false

Observed exact-URL quickstart verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8782`
- run id: `run_ae6abf1d7e35dbaa`
- token: `TBAR-7BF3DFF8FCFD`
- `tokenbar quickstart` prints exact `/profile`, `/social`, and `/rankings` URLs derived from the configured profile endpoint
- quickstart tells the builder to paste the returned `TBAR-...` token into the website instead of guessing route names
- privacy: raw transcripts false, source code false

Observed fresh-claim handoff verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8784 --run-claim`
- run id: `run_a7b3e60672d920c5`
- token: `TBAR-148A2D8E8183`
- `tokenbar claim` generated a fresh private identity JSON, stated that nothing public was uploaded, and pointed to `tokenbar publish-proof` as the safe public action
- `tokenbar claim` printed exact `/profile`, `/social`, and `/rankings` URLs derived from the configured profile endpoint
- `tokenbar help` now documents `tokenbar claim --publish-proof` and labels `tokenbar publish` as the advanced legacy profile JSON upload
- `tokenbar claim --publish-proof` ran the proof-card action path directly, not the legacy profile JSON upload path
- proof card: `http://127.0.0.1:8784/api/actions?token=TBAR-148A2D8E8183`
- profile: `http://127.0.0.1:8784/api/profiles?token=TBAR-148A2D8E8183`
- social: `http://127.0.0.1:8784/social`
- rankings: `http://127.0.0.1:8784/rankings`
- privacy: raw transcripts false, source code false

Observed selective-share verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8785 --run-claim`
- run id: `run_344fcf496bc38153`
- token: `TBAR-B80D3EAE9434`
- public proof path still runs from `tokenbar claim --publish-proof`
- selective update command: `tokenbar publish-proof <identity.json> --unlisted --hide-owner --hide-tokens --hide-sessions`
- the selective update keeps the same `TBAR` identity token but changes its public visibility to `unlisted`
- direct proof/profile lookup remains reloadable by token
- public `/api/actions` feed and loop rankings exclude the unlisted proof
- proof JSON carries `publicVisibility`, `shareControls`, `privacy.shareMode`, `privacy.redactions`, `tokenCountHidden`, and `sessionCountHidden`
- proof HTML shows a visible `Share mode` and `Redactions` privacy receipt
- privacy: raw transcripts false, source code false; tokens and sessions redacted on the selective public artifact

Observed share-mode web-surface verifier on July 15:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8786 --run-claim`
- run id: `run_f5c28dbdad687bad`
- token: `TBAR-5E91CAF4681C`
- identity: `Spike-Tolerant Prompt Stress Tester Guardian`
- sessions: 206
- proof score: 58/100
- loop maturity: 68/100
- `/profile` exposes copyable private, unlisted, and public share-mode commands
- `/social` exposes public-ranking and unlisted-proof copy actions near the feed handoff
- `/rankings` explains that public proofs enter rankings, unlisted proofs stay direct-link only, and private claims never leave the machine
- dynamic proof rendering shows the real `Share mode` and `Redactions` returned by the proof action
- privacy: raw transcripts false, source code false; unlisted token/session redactions verified

Observed verification-receipt verifier on July 16:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8787 --run-claim`
- run id: `run_0d7480c747f238fb`
- token: `TBAR-688B8637DF82`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- sessions: 192
- proof score: 59/100
- loop maturity: 66/100
- proof JSON includes `tokenbar.verification_receipt.v1`
- public profile JSON inherits the same verification receipt
- For You feed items carry the receipt for future social/ranking trust UI
- proof card HTML and public profile HTML render `Verification receipt`
- receipt states completed action stages, share mode, redactions, excluded raw materials, and the capped-token ranking policy
- privacy: raw transcripts false, source code false; unlisted redactions verified

Observed private-boundary verifier on July 16:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8788 --run-claim`
- public/unlisted run id: `run_c256ea541e258a40`
- private run id: `run_d211ebecede63af7`
- token: `TBAR-76049B5EDEE7`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- sessions: 192
- proof score: 59/100
- loop maturity: 66/100
- `tokenbar publish-proof <identity.json> --private` now prints a private audit URL instead of public proof/profile links
- private action runs remain reloadable by run id for local/server audit
- `/api/actions?token=<TBAR>` returns `403` for private proofs
- `/api/profiles?token=<TBAR>` returns `404` for private proofs
- public `/api/actions` feed excludes private proofs
- verification receipt states that token, profile, feed, and ranking lookups are disabled for private proofs
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed guided-token-activation verifier on July 16:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8789 --run-claim`
- public/unlisted run id: `run_f6d0326d5fbecaa9`
- private run id: `run_db9d935fc774cc09`
- token: `TBAR-89F8BA5F9928`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- sessions: 192
- proof score: 58/100
- loop maturity: 66/100
- profile, social, and rankings pages keep a `TBAR-...` token lookup path for public/unlisted proof surfaces
- token activation now checks the safe profile endpoint before navigation
- private-token lookup shows explicit guidance instead of dumping a raw 404/JSON page
- missing-token lookup tells the user to check the token or ask the builder to run `tokenbar publish-proof`
- successful lookup says the profile was found before opening the proof surface
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed public-action-index verifier on July 16:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8790 --run-claim`
- public run id: `run_5570cb16404b3887`
- private run id: `run_1c828535e9a78064`
- token: `TBAR-03ADC3F45E61`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- sessions: 192
- proof score: 58/100
- loop maturity: 66/100
- `/api/actions` public index includes the public action run
- `/api/actions` public index excludes unlisted action runs
- `/api/actions` public index excludes private action runs
- direct `/api/actions?run=<run_id>` reload remains available for private audit when the owner has the run id
- public feed, rankings, and loop rankings remain limited to public/listed proof cards
- privacy: raw transcripts false, source code false; unlisted redactions and private run-list boundary verified

Observed profile-link and share-token verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8791 --run-claim`
- public run id: `run_f23723ac7ecaa9cc`
- public token: `TBAR-4B97794C237D`
- unlisted token: `TBAR-CC587FE38AD6`
- private run id: `run_d1a655920f63174c`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- sessions: 192
- proof score: 59/100
- loop maturity: 66/100
- dynamic profile fallbacks now build `/api/profiles?token=<TBAR>` links instead of malformed `/api/profiles<TBAR>` links
- public, unlisted, and private proof actions derive distinct proof tokens from the identity token plus share controls
- unlisted redacted proofs cannot overwrite the public proof card for the same local identity artifact
- private proof tokens remain blocked from public token/profile lookup while the private run id remains reloadable for audit
- privacy: raw transcripts false, source code false; distinct share-token boundary verified

Observed shipped-work redaction verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8792 --run-claim`
- public run id: `run_328aa0441baaabe6`
- public token: `TBAR-EC579C3691BF`
- unlisted token: `TBAR-863D49646A5C`
- private run id: `run_d62bac9990d6329b`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- sessions: 192
- proof score: 59/100
- loop maturity: 66/100
- public feed items now include a shipped-work receipt with provenance for session surface, workload scale, repo evidence, or project range when available
- unlisted redacted proof stories now say `Hidden by owner` instead of leaking private session/token quantities through narrative copy
- dynamic social feed renderer includes the shipped-work receipt and keeps the raw-transcript/source-code safety strip
- privacy: raw transcripts false, source code false; unlisted story redactions and shipped-work provenance verified

Observed installed launcher verifier on July 17:

- command: `/Users/arnav/.local/bin/tokenbar help`
- installed launcher now matches `bin/tokenbar` and `src/tokenbar/tokenbar`
- help exposes `tokenbar claim`, `tokenbar claim --publish-proof`, `tokenbar publish-proof`, and `tokenbar social`
- `tokenbar status` explains tracking as new local indexing on/off instead of implying that historical usage is unavailable
- observed local status: app installed at `/Users/arnav/Applications/TokenBar.app`, process not running, usage index ready, tracking on, 8.97B tokens in the local 30-day trace, 192 indexed sessions
- command: `python3 scripts/smoke_builder_identity_flow.py --port 8793 --run-claim`
- public run id: `run_df20cdc25de73dca`
- public token: `TBAR-85E765D2C510`
- unlisted token: `TBAR-F53EBF1AA086`
- private run id: `run_0bb046343de85908`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- privacy: raw transcripts false, source code false; installed claim/proof flow and private token boundary verified

Observed proof/profile shipped-work verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8794 --run-claim`
- public run id: `run_1c144e6ad8ffb017`
- public token: `TBAR-233CE6E728B3`
- unlisted token: `TBAR-4C02C113BB01`
- private run id: `run_f60681568000919b`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- proof HTML now exposes a `Shipped-work receipt` section with safe provenance copy
- public profile HTML now exposes the same shipped-work receipt beneath the story-first profile read
- dynamic proof renderer now mounts `.proof-shipped-work` for interactive proof lookup
- public profile JSON carries `shippedWork` from the persisted proof card fallback
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed category leaderboard verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8795 --run-claim`
- public run id: `run_455bf76b3f4b698f`
- public token: `TBAR-F442E58C407E`
- unlisted token: `TBAR-B6137907E14D`
- private run id: `run_b32595d84443337e`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 58/100
- loop maturity: 66/100
- `/api/actions` now returns category leaderboards for overall proof, loop maturity, craft/taste, completion, ambition, and discernment
- `/rankings` now includes a `data-ranking-leaderboards` mount and copy that explains why different forms of builder excellence rank separately
- dynamic rankings renderer now reads `leaderboards` from the proof-action API and renders `.ranking-board-card` rows linked to proof/profile surfaces
- ranking boards use only public proof cards and safe `rankSignals`; unlisted and private proof boundaries remain verified
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed public identity passport verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8796 --run-claim`
- public run id: `run_69efaf8a2096eb96`
- public token: `TBAR-08D36886553E`
- unlisted token: `TBAR-BBC4816957F6`
- private run id: `run_adbde0fedb8b8a8f`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 58/100
- loop maturity: 66/100
- public profile now opens with a `Builder identity passport` block that shows the public token, archetype/NPC shape, proof posture, visibility, shareable surfaces, and `safe evidence only`
- smoke verifier now requires the passport, token, safe-evidence boundary, and share-surface summary on `/api/profiles?token=...`
- proof card, public profile, For You feed, rankings, category leaderboards, shipped-work receipt, verification receipt, unlisted redactions, and private-token boundary remain verified
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed For You story-card verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8798 --run-claim`
- public run id: `run_7104b3abf61fd34b`
- public token: `TBAR-1BDCF7307BFB`
- unlisted token: `TBAR-C2F58CDC4588`
- private run id: `run_5d8e47862993675c`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- `/api/actions` feed items now include a `feedStory` object with what shipped, why it matters, tradeoff, next frontier, and safe aggregate provenance
- dynamic For You feed cards now render `.feed-story-card` before score strips, so public proof reads as a builder story instead of only a metric row
- static `/social` fallback cards now include the same story labels: `What shipped`, `Why it matters`, and `Tradeoff`
- smoke verifier now requires feed story payload, static story cards, dynamic story cards, and raw-transcript/source-code boundaries in story provenance
- proof card, public profile, For You feed, rankings, category leaderboards, shipped-work receipt, verification receipt, unlisted redactions, and private-token boundary remain verified
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed installed-CLI proof-flow verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8799 --cli /Users/arnav/.local/bin/tokenbar --run-claim`
- installed CLI path: `/Users/arnav/.local/bin/tokenbar`
- public run id: `run_c19fc9cd660360e1`
- public token: `TBAR-06FF1F266E98`
- unlisted token: `TBAR-23E286058952`
- private run id: `run_5279b0d825db592d`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- smoke verifier now accepts `--cli` so judge tests can exercise the installed user-facing command as well as the repo launcher
- installed CLI completed `claim --publish-proof`, proof/profile reload, For You feed, rankings, category leaderboards, story cards, unlisted redactions, and private-token boundary
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed public share-contract verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8800 --run-claim`
- public run id: `run_afa837583d7e7074`
- public token: `TBAR-7A0118CBFCA9`
- unlisted token: `TBAR-143B0F8BD12E`
- private run id: `run_a4c775195b4cc2f8`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 58/100
- loop maturity: 66/100
- `/api/actions` now returns `shareContract` with public, unlisted, and private proof counts
- share contract states that public proofs enter the feed, unlisted/private proofs do not, and leaderboards use public proof cards only
- share contract explicitly marks raw transcripts, source code, private diffs, credentials, and env files as never-public material
- smoke verifier now requires the share contract, public claim classes, never-public data classes, unlisted exclusion, private exclusion, and private-token lookup failure
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed visible share-contract verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8801 --run-claim`
- public run id: `run_d1e5284ab8f79b99`
- public token: `TBAR-5A1989F412AC`
- unlisted token: `TBAR-52DDC793339C`
- private run id: `run_44e01c7d0db2a7f3`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 58/100
- loop maturity: 66/100
- `/social` now includes a visible `Public proof contract` panel beside the activation flow
- `docs/app.js` now renders the live `shareContract` from `/api/actions`, including public/unlisted/private counts and never-public material
- smoke verifier now requires `data-share-contract`, static never-public copy, dynamic `renderShareContract`, and dynamic `Never public` copy
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed token surface launcher verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8802 --run-claim`
- public run id: `run_8c85e9c44a64dcda`
- public token: `TBAR-1E720BF3B179`
- unlisted token: `TBAR-A7F52DA02227`
- private run id: `run_4d728f95b6062d0f`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- `/profile` now includes `data-token-surface-launcher` so a pasted `TBAR-...` token opens a proof bundle instead of feeling like a one-way redirect
- `docs/app.js` now renders `Proof card`, `Public profile`, `For You feed`, and `Rankings` links from the safe profile payload
- token launcher copy repeats the never-public boundary: raw transcripts, source code, credentials, private diffs, and env files stay out of the public bundle
- smoke verifier now requires the token surface launcher, proof-bundle surfaces, and updated success guidance
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed canonical surface-bundle verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8803 --run-claim`
- public run id: `run_95ce34a7f3ff82ef`
- public token: `TBAR-965D9C4034CE`
- unlisted token: `TBAR-812FE6DC5979`
- private run id: `run_07c19bcf5d44157a`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- `/api/profiles?token=...` now returns `surfaceBundle` with `Proof card`, `Public profile`, `For You feed`, `Rankings`, and `Loop rankings`
- `docs/app.js` now consumes `profile.surfaceBundle.surfaces` first and falls back only for older payloads
- smoke verifier now requires the surface bundle schema, all five surface keys, unlisted visibility inheritance, and raw-transcript/source-code boundaries
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed social feed surface-bundle verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8804 --run-claim`
- public run id: `run_74f544856cd17a9d`
- public token: `TBAR-D35C395E1800`
- unlisted token: `TBAR-C47F70E4647D`
- private run id: `run_4d5fc5b952e8bca8`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- proof cards now carry `surfaceBundle` at creation time
- `/api/actions` feed rows now carry the same `surfaceBundle` contract as `/api/profiles`
- action results expose `surfaceBundle` beside proof/profile/social/ranking URLs
- `docs/app.js` social cards now prefer bundled proof/profile/feed/ranking links through `surfaceFromBundle`
- smoke verifier now requires feed item surface-bundle schema, all five surface keys, privacy boundary flags, and the dynamic surface-bundle UI helper
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed CLI proof-bundle handoff verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8805 --run-claim`
- public run id: `run_22c891092c7e837a`
- public token: `TBAR-124FB1BCB782`
- unlisted token: `TBAR-7250CB28E867`
- private run id: `run_17996024e1eb3a5b`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- `tokenbar publish-proof` now prints `Safe token`, `Proof bundle`, `Proof card`, `Public profile`, `For You feed`, `Leaderboards`, and `Loop rankings`
- private publish output now prints `Proof bundle: disabled by --private` and disables public proof/profile/feed/leaderboard surfaces
- smoke verifier now requires the CLI handoff copy for public, unlisted, and private publish modes
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed safe-evidence receipt verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8806 --run-claim`
- public run id: `run_b657df56481ddc4e`
- public token: `TBAR-AD2F50841BF6`
- unlisted token: `TBAR-028BAD051481`
- private run id: `run_5177615a18a8285d`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- proof cards now carry `tokenbar.safe_evidence_receipt.v1` with used evidence, never-used material, public material, stage counts, surfaces, redactions, and privacy-boundary flags
- `/api/profiles?token=...` preserves the same safe-evidence receipt so the public profile can explain its evidence basis without exposing raw logs
- `/api/actions` feed rows now include the same safe-evidence receipt for For You/social cards
- `docs/app.js` renders the receipt in the social feed and token launcher; proof/profile HTML render Used and Never used evidence lists
- smoke verifier now requires receipt schema coverage in API JSON, profile JSON, feed JSON, proof HTML, public profile HTML, and dynamic JS surfaces
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed next-action plan verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8807 --run-claim`
- public run id: `run_36d580882d2881aa`
- public token: `TBAR-521F6328AEE6`
- unlisted token: `TBAR-B986922B486C`
- private run id: `run_334cde6d29051b37`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- proof cards now carry `tokenbar.next_action_plan.v1` with an Act / Verify / Share ladder, confidence, evidence requirements, and a privacy boundary stating raw transcripts and source code are not required
- `/api/profiles?token=...` preserves the same next-action plan so the public profile explains what the builder should do next after the current proof
- `/api/actions` feed rows now expose the same next-action plan, and `docs/app.js` renders it as an `Act next` card in the For You surface
- the share contract now lists `nextActionPlan` as a safe public claim class
- smoke verifier now requires next-action schema coverage in proof JSON, profile JSON, feed JSON, proof HTML, public profile HTML, dynamic social JS, and share-contract claims
- privacy: raw transcripts false, source code false; unlisted redactions and private token boundary verified

Observed correction/report feedback verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8812`
- public run id: `run_36d580882d2881aa`
- public token: `TBAR-521F6328AEE6`
- unlisted token: `TBAR-B986922B486C`
- private run id: `run_334cde6d29051b37`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- local proof server now routes `POST /api/report-feedback`
- proof-card HTML and public-profile HTML now show `Report or correct this profile` with a safe correction payload
- smoke verifier now requires the correction/report path in proof HTML and public profile HTML, rejects short feedback with `message_required`, and accepts a safe correction payload without requiring AgentMail
- privacy: the correction copy tells users not to paste raw transcripts, source code, credentials, private diffs, or environment files

Observed owner/social metadata verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8814`
- public run id: `run_1eb32a5a3aa38c7f`
- public token: `TBAR-521F6328AEE6`
- unlisted token: `TBAR-B986922B486C`
- private run id: `run_4187c834c4b67ae3`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- proof cards now carry a sanitized `ownerProfile` with nickname, handle, region, bio, and safe public links
- `/api/profiles?token=...` renders an owner card so the share surface identifies the builder, not only the archetype
- `/api/actions` feed rows now include owner handle, region, profile links, and bio for social proof cards
- `docs/app.js` renders safe profile links in the For You feed, and the smoke verifier requires the dynamic social renderer to expose `feed-profile-links`
- smoke verifier now requires owner metadata in proof JSON, profile JSON, feed JSON, and public-profile HTML
- privacy: the owner metadata path still verifies `raw transcripts false` and `source code false`; links are public URLs only

Observed regional leaderboard verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8815`
- public run id: `run_1eb32a5a3aa38c7f`
- public token: `TBAR-521F6328AEE6`
- unlisted token: `TBAR-B986922B486C`
- private run id: `run_4187c834c4b67ae3`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- `/api/actions` now returns `regionalLeaderboards` generated from public proof cards only
- a safe public `Singapore` owner region now enters both the `Singapore` and `Southeast Asia` boards while preserving the original profile region
- `/rankings` now exposes regional proof boards alongside category leaderboards, so the proof product has local/social competition without needing raw data
- `docs/app.js` now prefers action-feed regional boards over static examples when public proof cards exist
- smoke verifier now requires Global, Singapore, and Southeast Asia boards, the Singapore owner handle, the rankings regional mount, and the public/privacy boundaries
- privacy: unlisted and private proof cards still do not enter the public feed or regional leaderboards

Observed public rank-context verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8816`
- public run id: `run_1eb32a5a3aa38c7f`
- public token: `TBAR-521F6328AEE6`
- unlisted token: `TBAR-B986922B486C`
- private run id: `run_4187c834c4b67ae3`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- public `/api/actions?token=...` lookups now include derived `rankBadges` and `rankPlacements` for public proofs
- For You feed cards now render compact public rank badges for global, loop, and regional context
- proof-card HTML now renders a `Public rank context` panel when rank metadata is available
- smoke verifier now requires global, loop, Singapore, and Southeast Asia rank badges, proof-card rank context, and the dynamic feed badge renderer
- privacy: rank context is derived only from public proof-card aggregates; unlisted and private proof cards remain excluded from public ranking context

Observed public profile rank-context verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8817`
- public run id: `run_1eb32a5a3aa38c7f`
- public token: `TBAR-521F6328AEE6`
- unlisted token: `TBAR-B986922B486C`
- private run id: `run_4187c834c4b67ae3`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 59/100
- loop maturity: 66/100
- `/api/profiles?token=...` now enriches action-proof fallback profiles with the same derived public `rankBadges` and `rankPlacements` used by proof cards and feed rows
- public-profile HTML now renders a `Public rank context` panel with opt-in global, loop, Singapore, and Southeast Asia rank evidence
- smoke verifier now requires profile JSON rank badges, global rank placement, and profile HTML rank context
- privacy: profile rank context is computed from public proof-card aggregates only; unlisted and private tokens still stay out of public ranking context

Observed `tokenbar prove` shortcut verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8818 --run-claim`
- public run id: `run_66ba42756aa95d34`
- public token: `TBAR-A0C6EAF07E7E`
- unlisted token: `TBAR-3255B9B7F341`
- private run id: `run_9c73a865df182c34`
- identity: `Checklist-Driven Multi-Agent Conductor Guardian`
- proof score: 60/100
- loop maturity: 66/100
- sessions: 192
- `tokenbar prove` now aliases the full local claim plus safe proof action, so the public-token path is one command instead of `tokenbar claim --publish-proof`
- help, quickstart, profile, social, rankings, and docs pages now expose `tokenbar prove` as the simplest first move
- smoke verifier now runs the fresh claim through `tokenbar prove` and requires the shortcut in CLI help, quickstart, profile, social, and rankings surfaces
- privacy: the shortcut still uses the same generated-proof boundary; raw transcripts and source code remain false, unlisted proof stays out of rankings, and private proof disables public surfaces

Observed anonymous selective-share verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8819 --run-claim`
- public run id: `run_d50bd090f10a437b`
- public token: `TBAR-DDD4E20BD75D`
- unlisted token: `TBAR-DE379C867888`
- private run id: `run_b02b75d801b922f2`
- identity: `Checklist-Driven Multi-Agent Conductor Architect`
- proof score: 59/100
- loop maturity: 66/100
- sessions: 192
- `tokenbar publish-proof` now accepts `--hide-owner` / `--anonymous` in addition to token, session, and region redactions
- share labs now teach `tokenbar publish-proof --unlisted --hide-owner --hide-tokens --hide-sessions` for a direct-link proof that stays out of the public feed and hides owner metadata
- proof cards and public-profile fallbacks carry an `ownerRedacted` flag and replace handle, nickname, bio, and links with an anonymous owner profile when requested
- smoke verifier now checks that the unlisted proof does not leak the original handle `tokenbar-smoke` or the original GitHub link, while still preserving reloadable proof/profile surfaces
- privacy: raw transcripts false, source code false; owner, token, and session redactions verified; unlisted and private boundaries remain excluded from public rankings and feed surfaces

Observed share-receipt verifier on July 17:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8820 --run-claim`
- public run id: `run_37a809793b193d3f`
- public token: `TBAR-69EA23A7AD25`
- unlisted token: `TBAR-18B3E1FB4E4E`
- private run id: `run_da48a1552b61446f`
- identity: `Checklist-Driven Revenue Systems Captain Guardian`
- proof score: 58/100
- loop maturity: 66/100
- sessions: 192
- proof/profile/feed JSON now carries `tokenbar.share_receipt.v1`
- `tokenbar publish-proof` prints a `Share receipt` block with public material, stayed-local data classes, and copy-safe summary
- proof-card HTML and public-profile HTML now render the share receipt so a judge can see what the token exposes before trusting or sharing it
- smoke verifier requires public, unlisted, and private share-receipt modes, redaction fields, never-public data classes, proof/profile HTML receipt rendering, and CLI receipt output
- privacy: raw transcripts false, source code false; private proof remains non-token-addressable; unlisted proof remains excluded from public feed and rankings

Observed local proof-receipt recovery verifier on July 18:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8822 --run-claim`
- public run id: `run_9a625550f930d6f8`
- public token: `TBAR-1FF81DDDB7F1`
- unlisted token: `TBAR-6F6782B25E08`
- private run id: `run_63976783338b3267`
- identity: `Checklist-Driven Revenue Systems Captain Guardian`
- proof score: 59/100
- loop maturity: 66/100
- sessions: 192
- `tokenbar publish-proof` now writes `tokenbar.local_proof_receipt.v1` under the local TokenBar support directory
- `tokenbar proof latest` reprints the latest safe token, run id, proof/profile/feed/ranking links, share receipt, privacy boundary, and share copy without rerunning analysis or uploading anything
- `tokenbar proof latest --json` returns the same local receipt as machine-readable JSON for Codex/social handoff flows
- smoke verifier requires the local receipt schema, token/run match, safe surface links, raw-transcript/source-code upload flags set to false, and private latest receipts limited to the private audit surface only
- privacy: local receipt contains only safe proof handoff fields; raw transcripts and source code remain excluded from the published proof and the recovered receipt

Judge flow:

1. Local Codex evidence stays on the machine.
2. `tokenbar publish-proof` sends compact safe identity JSON only.
3. `/api/actions` validates privacy flags and persists an idempotent run.
4. The profile page can reload the run id or token.
5. The proof card exposes public, selective, and private share previews.
6. The social page can show the safe proof-card feed and loop rankings.
7. The HTML proof surface explains who the builder is, what was proved, why it matters, and what remains uncertain.

## Judge Framing

Primary Build Week framing: Apps for Your Life. TokenBar is a personal reflection and growth product for AI builders. The CLI, API, and server action are implementation surfaces for the identity loop, not the category itself.

## Post-July-13 Codex Threads Workboard

Implemented July 20, 2026 as a bounded local-first slice:

- `tokenbar threads` reads Codex's local thread state and goal ledger without changing either database
- `/threads` renders five lanes: in progress, needs attention, paused/backlog, recent, and done
- task cards show safe operational fields only: title, project basename, goal status, recency, and token weight
- `api/local_threads.py` is the single read-only snapshot contract and explicitly reports raw transcripts, source code, full paths, and uploads as excluded
- the hosted `/threads` page cannot read local state; it displays the exact localhost bridge command instead of fake data
- primary navigation now exposes the product as four clear surfaces: Usage, Threads, Identity, and For You

Judge test:

```bash
tokenbar threads
python3 scripts/tokenbar_local_server.py --port 8768
open http://127.0.0.1:8768/threads
```

Observed July 20 proof: local API returned `tokenbar.local_threads.v1`, five lanes, no full paths, no raw transcript/source payloads, and zero upload. Desktop rendered without page overflow; mobile kept the kanban in an intentional horizontal scroller.

## Device-Owned Proof Revocation

Implemented and verified July 23, 2026:

- command: `python3 scripts/smoke_builder_identity_flow.py --port 8838`
- public run: `run_854b0cf5923242c3`
- public token: `TBAR-F680B4FB98AC`
- revoked token: `TBAR-C07AAA5894A8`
- `tokenbar publish-proof` creates one private `0600` device key and sends it only as an ownership header
- the server persists only a SHA-256 owner identifier and omits it from public run responses
- a wrong device key receives HTTP `403` and leaves the proof intact
- `tokenbar revoke latest` or `tokenbar revoke TBAR-...` removes proof, profile, For You, rankings, and public-run surfaces
- the revoked server run stays inspectable with `status: revoked`, an empty proof payload, and `localArtifactsDeleted: false`
- local receipts are marked revoked and all open/latest commands skip them
- the private identity artifact remained byte-for-byte unchanged
- privacy: raw transcripts false, source code false; owner-bound revocation, unlisted redactions, and private-token boundaries verified
