# OpenAI Build Week scope

Submission window: July 13–21, 2026.

## Pre-existing foundation

- TokenBar command-line and macOS usage/cost presentation.
- Local token accounting, forecast, and utility surfaces.

These establish the founder problem—model spending and builder activity were difficult to understand—but are not presented as new Build Week work.

## Post–July 13 extension

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
- Keep the pre-existing TokenBar utility clearly separated from the identity/passport extension in commits, README, demo, and Devpost.
- Never commit private source artifacts, prompts, transcripts, credentials, or filesystem paths selected by a user.
- Tag the final judged state only after the human privacy/share test and submission checklist pass.

## Founder story

The product began because discoveries were scattered between X and WhatsApp while terminal usage output did not explain where thousands of dollars or creative attention went. Builder Identity is meant to communicate taste, ambition, technical ability, and discernment without exposing the private material that produced them.
