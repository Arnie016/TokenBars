# TokenBar

TokenBar is a local-first CLI token usage and budget bar for coding agents and developer workflows.

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
share manifest, PDF when present, and a bundle manifest that restates the privacy boundary.
`tokenbar proof` creates a fuller local portfolio packet with the latest identity artifacts,
local rankings, newest-vs-previous comparison, and an HTML timeline.

`tokenbar verify` audits an identity JSON or share manifest before upload/bundling. It
fails if the artifact claims to include raw transcripts, source code, or secret-like tokens.
