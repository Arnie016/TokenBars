# OpenAI Build Week scope

Submission window: July 13–21, 2026.

## Build Week implementation

All capabilities presented in this submission were built during the July 13–21 Build Week window. Earlier repository shells, references, or unrelated experiments are not part of the judged claim.

- Builder Identity product surface instead of token accounting alone.
- Browser-first Create Identity journey from a deliberately selected local artifact.
- Safety preflight that accepts bounded evidence and excludes raw prompts, transcripts, source, credentials, private diffs, and filesystem paths.
- Public, unlisted, and private discovery boundaries explained before generation.
- Identity passport, TBAR token, proof link, exclusion line, and share-card preview.
- Guarded retry, duplicate-request prevention, oversized-file rejection, replacement-state clearing, and metadata continuity.
- Deterministic `scripts/smoke_builder_identity_flow.py` proof and submission ledgers.

## Current gate

Automated proof passes, but the core experience remains `HUMAN_TEST=NOT RUN` until Arnav completes one unlisted browser file-picker flow and confirms the title, TBAR token, safe-proof link, exclusion line, and copied share text.

## Commit policy

- Use `build-week:` commit subjects for Builder Identity work.
- Keep the submitted TokenBar and identity/passport capabilities traceable through commits, README, demo, and Devpost.
- Never commit private source artifacts, prompts, transcripts, credentials, or filesystem paths selected by a user.
- Tag the final judged state only after the human privacy/share test and submission checklist pass.

## Founder story

The product began because discoveries were scattered between X and WhatsApp while terminal usage output did not explain where thousands of dollars or creative attention went. Builder Identity is meant to communicate taste, ambition, technical ability, and discernment without exposing the private material that produced them.
