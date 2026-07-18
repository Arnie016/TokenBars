# TokenBar Implementation Notes

## PDF export

`tokenbar profile --pdf` renders the local HTML builder profile to PDF using Chrome or Chromium headless. On macOS, TokenBar auto-detects:

`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`

If Chrome is somewhere else, set:

```bash
export TOKENBAR_CHROME_PATH="/path/to/chrome"
```

## AgentMail delivery

`tokenbar profile --email user@example.com` renders the profile PDF and sends it through AgentMail.

Required environment:

```bash
export AGENTMAIL_API_KEY="am_..."
export AGENTMAIL_INBOX_ID="tokenbar@agentmail.to"
```

AgentMail references:

- Send message endpoint: `POST https://api.agentmail.to/v0/inboxes/:inbox_id/messages/send`
- PDF attachments use base64 `content`, `filename`, and `content_type: application/pdf`.

## Report feedback

`POST /api/report-feedback` accepts report corrections, disputes, takedown requests, or misclassification feedback. It is for generated report tokens and user-written feedback only; users should not paste raw transcripts, source code, credentials, or private files.

The local judge server also routes this endpoint:

```bash
python3 scripts/tokenbar_local_server.py --port 8768
curl -X POST http://127.0.0.1:8768/api/report-feedback \
  -H 'Content-Type: application/json' \
  -d '{"token":"TBAR-...","category":"correction","message":"What should be corrected without raw logs."}'
```

Required Vercel env vars for AgentMail delivery:

```bash
AGENTMAIL_API_KEY=...
AGENTMAIL_INBOX_ID=...
TOKENBAR_REPORT_FEEDBACK_TO=support@your-domain.example
```

Payload:

```json
{
  "category": "correction",
  "token": "TBAR-...",
  "email": "user@example.com",
  "reportUrl": "https://...",
  "message": "What should be corrected."
}
```

## Public owner metadata

Proof cards may include optional public builder metadata. This is for profile identity, feed cards, and public proof links only; it does not authorize uploading raw transcripts, source code, private repo content, credentials, or private diffs.

Supported local env vars:

```bash
TOKENBAR_PUBLIC_HANDLE=your-handle
TOKENBAR_PUBLIC_REGION=Singapore
TOKENBAR_PUBLIC_GITHUB=https://github.com/yourname
TOKENBAR_PUBLIC_WEBSITE=https://your-site.example
TOKENBAR_PUBLIC_LINKEDIN=https://linkedin.com/in/yourname
TOKENBAR_PUBLIC_X=https://x.com/yourname
```

Local verifier:

```bash
python3 scripts/smoke_builder_identity_flow.py --port 8813
```

Expected boundary: proof JSON, public profile JSON, and For You feed JSON can carry sanitized public links, while `rawTranscriptsShared` and `sourceCodeShared` stay false.

## Stripe fulfillment

The starter webhook server is:

```bash
python3 scripts/tokenbar_fulfillment_webhook.py --port 8787
```

The deployable Vercel endpoint is:

```text
/api
```

After deploying, paste this into Stripe Workbench as:

```text
https://YOUR-VERCEL-PROJECT.vercel.app/api
```

Open `/api` in a browser to verify the deployment is alive before connecting Stripe.

Required environment:

```bash
export STRIPE_WEBHOOK_SECRET="whsec_..."
export TOKENBAR_ENTITLEMENTS_PATH="./tokenbar-entitlements.json"
```

For Vercel, set these in Project Settings -> Environment Variables:

```bash
STRIPE_WEBHOOK_SECRET=whsec_...
AGENTMAIL_API_KEY=am_...
AGENTMAIL_INBOX_ID=tokenbar@agentmail.to
```

Optional durable entitlement forwarding:

```bash
TOKENBAR_ENTITLEMENTS_WEBHOOK_URL=https://...
TOKENBAR_ENTITLEMENTS_WEBHOOK_TOKEN=...
```

Recommended Stripe events:

- `checkout.session.completed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `customer.subscription.trial_will_end`
- `invoice.paid`
- `invoice.payment_failed`

Stripe notes:

- Subscription access should be keyed from webhook state, not the redirect alone.
- `trialing` and `active` should provision access.
- `canceled`, `unpaid`, and terminal failure states should revoke access.

## Public identity profiles

Local profile generation stays local by default. The PDF/HTML memorandum is the primary private artifact:

```bash
tokenbar identity
tokenbar profile --pdf
```

The memorandum includes a themed visual system, score distribution, probability buckets, memorable aggregate facts, likely work-fit notes, growth edge, provider inventory, shipping evidence, and activation instructions.

Public sharing is opt-in and uploads only the generated `.identity.json`. That token activates the hosted profile view:

```bash
tokenbar share latest
tokenbar claim --publish
tokenbar publish --days 7 --pdf
tokenbar card
tokenbar bundle
tokenbar stats
```

Use `claim` for the simple local-first path: it generates fresh local HTML/JSON/Skill.md
artifacts and prints the share token. Use `claim --publish` or `publish` when the user
explicitly wants hosted activation. Use `share latest` when you already generated the local
memorandum and only want to activate the website profile.
Use `card` for a terminal-readable identity summary without opening the HTML/PDF report.
Use `bundle` to produce a portable zip that can be attached to applications, sent to reviewers,
or handed to another coding agent without exposing raw transcripts or source code.

The deployed API is:

```text
/api/profiles
```

Without a database, `/api/profiles` and `/api/actions` use ephemeral JSON files, which are only suitable for local development. For durable Vercel hosting, create the Supabase tables with:

```text
docs/tokenbar_profiles_supabase.sql
docs/tokenbar_actions_supabase.sql
```

Then set these Vercel environment variables:

```bash
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_SERVICE_ROLE_KEY=...
TOKENBAR_PUBLIC_BASE_URL=https://tokenbar-umber.vercel.app
TOKENBAR_ACTION_STORE=supabase
```

Verify the deployed storage boundary:

```bash
TOKENBAR_PROFILE_UPLOAD_URL=https://YOUR-VERCEL-PROJECT.vercel.app/api/profiles tokenbar hosted-doctor
curl -fsS https://YOUR-VERCEL-PROJECT.vercel.app/api/actions?health=1
```

The server-side API writes with the service role key. Browser/client writes remain disabled by row-level security. Public reads are allowed because the uploaded profile is already an explicit public artifact and does not contain source code or raw transcripts.

## Provider connectors

Current live source:

- Codex: local TokenBar/CodexLimitBar usage index.

Planned sources:

- Claude Code: expected local session logs under `~/.claude`.
- Cursor: local chat history is SQLite/export based; inspect Cursor user data and exported Markdown before enabling.
- Gemini CLI: official Gemini CLI telemetry supports local file output at `.gemini/telemetry.log` when configured with local telemetry.

Use:

```bash
tokenbar connectors
```

to see what sources are detected on the machine.
