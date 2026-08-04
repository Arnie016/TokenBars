# TokenBar

TokenBar is a local-first macOS app and CLI for understanding how you build with
coding agents. It combines usage visibility with a private Builder Story, Codex
thread control, inspectable proof, and opt-in sharing.

## Native macOS preview

Install or refresh TokenBar from the live repo script:

```bash
curl -fsSL https://raw.githubusercontent.com/Arnie016/TokenBar/main/install.sh | bash
```

The public GitHub release asset is still pending. Until a signed ZIP exists on
the TokenBar repo, use the install script and repo link instead of stale preview
download URLs.

This preview adds a full native companion alongside the original TokenBar menu-bar
and CLI utilities:

- **Builder Story** turns safe local aggregates into a concise identity narrative.
- **Threads** shows active goals, forks, Git review state, Codex deep links, and
  follow-up drafts saved only on your Mac. Unlimited boards and the Thread Store
  turn recurring workflows into installable local control layouts.
- **Usage** gives one adjustable time-window total and explains pace/cost without
  pretending volume equals output.
- **Storage** maps generated build/cache weight, protects source and session
  history, and moves only a confirmed known generated folder to recoverable Trash.
- **Report** keeps identity analysis private until you explicitly publish a
  redacted artifact.
- **Opportunities** turns a project brief into a bounded Codex kickoff without
  automatically cloning, running, or posting anything.

The preview requires macOS 14 or newer on Apple silicon. Unzip it, move
`TokenBar.app` to Applications, then open it. The build is ad-hoc signed and not
yet notarized, so macOS may require **Control-click > Open** the first time.

Raw transcripts, source code, credentials, and project briefs are not uploaded.
The native app reads TokenBar's generated artifacts and Codex's local thread index;
sharing remains an explicit action.

Build details and native architecture live in
[`macos/TokenBarMac`](macos/TokenBarMac/README.md).

## CLI and menu-bar utility

It gives you a quick terminal view of token usage, budget status, reset timing, power estimate, and natural-language prompts like:

```bash
will I run out?
why spike?
show folders
set daily limit 100M
heat?
```

An exported multi-agent usage table can also become a concise Builder Pulse or
a privacy-safe payload for the social profile surface:

```bash
tokenbar usage usage-report.txt
tokenbar usage usage-report.txt --json
```

The import distinguishes input/output from cache traffic, labels reported costs
as estimates, and never includes the raw report, transcripts, source code, or
local paths in the JSON output.

## Identity profiles

TokenBar can generate a local-first AI builder identity memorandum from your indexed coding-agent usage.
The serious artifact is the local report: HTML, true PDF, identity JSON, portable `Skill.md`, and a share manifest. The hosted profile is activated later from the generated token/JSON, without uploading raw transcripts or source code.
The PDF is designed as a premium dossier: themed profile art, score distribution, probability buckets, memorable session facts, career-fit notes, growth edge, provider inventory, and shipping evidence.

For the shortest reproducible product walkthrough, use the
[60-second judge flow](docs/JUDGE_FLOW.md).

```bash
pip install tokenbar
tokenbar quickstart
tokenbar readiness
tokenbar claim
tokenbar identity
tokenbar profile --pdf
tokenbar publish-proof
tokenbar share latest
tokenbar card
tokenbar skill
tokenbar history
tokenbar rankings
tokenbar timeline
tokenbar compare latest
tokenbar compare old.identity.json new.identity.json
tokenbar bundle
tokenbar proof
tokenbar verify
tokenbar api
tokenbar api --snapshot --output tokenbar-safe-bundle.json
tokenbar publish --days 7 --pdf
tokenbar profile --days 30 --focus "agent infrastructure" --open
```

`tokenbar quickstart` prints the end-to-end local identity workflow, the configured
upload endpoint, detected provider sources, and the privacy boundary before anything
is shared.
`tokenbar readiness` checks whether local identity reports, Skill.md, timeline, proof
packet, shipping evidence, and hosted share configuration are ready.

The profile engine ranks multiple archetypes probabilistically, adds an NPC-style class,
scores multidimensional traits, and keeps raw transcripts/source code out of the exported
artifact unless you explicitly share later.

`tokenbar claim` creates a local identity packet and share token without uploading.
`tokenbar identity` creates the local identity memorandum. `tokenbar profile --pdf`
creates the boardroom-ready PDF. `tokenbar publish-proof` uploads only the safe generated
identity artifact to the Builder Identity action and returns a proof-card URL plus scoped
public surfaces based on visibility (direct link only for unlisted/private, broader surfaces
for public). `tokenbar share latest` remains the advanced direct JSON upload.
`tokenbar publish --days 7 --pdf` combines fresh local report generation, PDF export,
and safe hosted-profile activation in one command.
The hosted endpoints accept the same safe schema for durable Supabase storage.
Profiles use `docs/tokenbar_profiles_supabase.sql`; proof actions use
`docs/tokenbar_actions_supabase.sql` plus `TOKENBAR_ACTION_STORE=supabase`.

`tokenbar card` prints the latest identity JSON as a compact terminal card with the label
rationale, top probabilities, trait drivers, session signals, and local artifact paths.
`tokenbar skill` previews or exports the latest portable identity `Skill.md` so another
agent or teammate can understand your working style without raw transcripts or source code.

`tokenbar compare` diffs two identity snapshots so repeat reports can show how your
archetype, dimensions, behavior patterns, provider coverage, and usage changed over time.
Use `tokenbar history` to list local snapshots and `tokenbar compare latest` to diff the
newest two reports without copying file paths.

`tokenbar timeline` exports a local HTML timeline across recent identity snapshots so
repeat reports become a visible profile evolution, not just individual files.
`tokenbar rankings` summarizes local snapshots into archetype, NPC, operating-mode,
rarest-bucket, and specificity rankings before any public upload.

`tokenbar bundle` creates a portable zip with the HTML report, identity JSON, Skill.md,
PDF when present, and a bundle manifest that restates the privacy boundary.
`tokenbar proof` creates the share-ready local portfolio packet. Its `index.html` is a
self-contained TokenBar-styled overview; the packet also includes a sanitized identity JSON,
latest report artifacts, local rankings, newest-vs-previous comparison, timeline, privacy
manifest, and a SHA-256 file ledger. The sanitized identity copy strips raw prompt fields,
transcripts, source code, local paths, personal emails, credentials, and secret-like values.

`tokenbar verify` audits an identity JSON, share manifest, or proof packet. For proof ZIPs it
also checks every packaged payload against the SHA-256 ledger and fails on local-path leakage
or tampering.

```bash
tokenbar proof --output ~/Desktop/tokenbar-builder-proof.zip
tokenbar verify ~/Desktop/tokenbar-builder-proof.zip
```

After unzipping, open `index.html`. Nothing is uploaded by these commands.

## One identity contract, four surfaces

| Surface | Use it for | Entry point |
| --- | --- | --- |
| Native macOS app | Read Builder Story, usage, thread boards/store, storage, report state, and the server action receipt | TokenBar.app |
| CLI | Analyze locally, build a portable report, and verify it | `tokenbar report`, `tokenbar proof`, `tokenbar verify` |
| Local API | Read sanitized identity and aggregate usage from local software | `tokenbar api` → `/v1/bundle` |
| Codex MCP | Let Codex inspect the same read-only sanitized contract | `codex mcp add tokenbar -- tokenbar mcp` |

## Safe local API and Codex MCP

`tokenbar api` exposes a read-only localhost contract for the native app, local web
surfaces, and inspectable scripts. `tokenbar mcp` exposes the same sanitized material
as three read-only tools for Codex and other MCP clients. Both package only generated Builder
Identity fields and aggregate usage statistics:

```bash
tokenbar api
curl http://127.0.0.1:8769/v1/bundle
tokenbar api --snapshot --output tokenbar-safe-bundle.json
codex mcp add tokenbar -- tokenbar mcp
```

Resources are `/v1/identity`, `/v1/stats`, `/v1/bundle`, and `/health`. The server
binds to `127.0.0.1` by default and refuses a remote bind unless `--allow-remote` is
explicitly provided. Raw prompts, transcripts, source code, local paths, emails,
identity tokens, and secret-like values are excluded. Set
`TOKENBAR_API_ALLOWED_ORIGIN` only when a specific local web origin needs CORS.

The MCP server implements newline-delimited JSON-RPC over stdio and advertises
`tokenbar_get_builder_identity`, `tokenbar_get_usage_stats`, and
`tokenbar_get_builder_bundle`. It has no write, publish, transcript, or source-code
tool. Remove the Codex registration with `codex mcp remove tokenbar`.
