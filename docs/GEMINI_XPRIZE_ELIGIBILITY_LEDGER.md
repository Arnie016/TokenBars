# Build with Gemini XPRIZE eligibility ledger

Last official-rules check: 2026-07-23 (SGT)

## Candidate decision

**Conditional candidate:** TokenBar Builder Identity, in **Entrepreneurship & Job Creation** or **Small Business Services**. This is not an eligibility conclusion and is not a submission claim.

The older **TOK GPT** described in prior LinkedIn proof is explicitly excluded. It predates the competition start and is not this candidate.

## Official rule evidence

Source of truth: [Official Rules](https://xprize.devpost.com/rules) and [official FAQ](https://xprize.devpost.com/details/faq).

| Gate | Official requirement checked 2026-07-23 | Current TokenBar evidence | Status |
| --- | --- | --- | --- |
| Submission window | May 19, 2026 at 10:00 AM Pacific through Aug 17, 2026 at 1:00 PM Pacific | Deadline recorded; no submission action taken | Verified rule |
| New business | The business must be newly created after the submission period began; a new repo alone is insufficient | Earliest local commit `03d23eabcff06af95feea931d1fe74dc4872209a` is 2026-05-20 06:28:48 +08:00 (2026-05-19 22:28:48 UTC), after the 2026-05-19 17:00:00 UTC cutoff. Public repo `Arnie016/TokenBars` reports `created_at: 2026-07-21T11:15:23Z`. Neither timestamp alone proves when the business activity began. | **Unverified business-creation gate** |
| Business activity | A business provides goods or services to interested parties in exchange for financial payment | No arms-length customer or payment evidence found in the inspected submission files | Unverified |
| Google Cloud | The project must use at least one Google Cloud product | No production Google Cloud evidence found | Blocked |
| Deployed Gemini call | If the project has LLM functionality, at least one Gemini API call must exist in the deployed application | No deployed Gemini API call or production API-usage record found | Blocked |
| Real operations | AI must transform business workflows; judges assess AI live in production executing key decisions | Local code, smoke tests, and Build Week proof exist, but these do not prove continuous production AI operations | Unverified |
| Users and revenue | Submission requires real-user evidence plus revenue/expense disclosures; zero marketing spend must still be disclosed | No user count, consented testimonial, arms-length revenue record, or XPRIZE-period P&L verified | Blocked |

## Creation evidence still required

Before treating TokenBar as eligible, a human must supply contemporaneous evidence that the **TokenBar business activity itself** began after 2026-05-19 10:00 AM Pacific. Suitable evidence could include a dated product brief, domain or service creation receipt, first customer-facing offer, or other immutable record. Do not backfill or infer this date from Git history.

Record the evidence reference here without customer personal data:

- Evidence type: `PENDING`
- Source/receipt identifier: `PENDING`
- Timestamp and timezone: `PENDING`
- What it proves: `PENDING`
- Human attestation that no TokenBar business work began before cutoff: `PENDING`

### Evidence review rubric

Accept only a contemporaneous source whose original timestamp can be independently
checked and whose content identifies the new TokenBar business activity. Record a
privacy-safe reference or redacted copy plus its SHA-256 hash; do not copy customer
contact details into this repository.

| Evidence | Decision |
| --- | --- |
| Dated first customer-facing offer, service/domain receipt, or product brief that identifies TokenBar Builder Identity and is after the cutoff | Potentially sufficient after human review |
| Git commit, repository creation date, generated file timestamp, or current written attestation by itself | Insufficient |
| Older TOK GPT, prior TokenBar token-accounting work, or undated LinkedIn material | Reject as proof of the new business |

Human review result: `PENDING`

- Reviewer: `PENDING`
- Reviewed at and timezone: `PENDING`
- Source timestamp independently checked: `PENDING`
- SHA-256 of retained/redacted evidence: `PENDING`
- Decision and reason: `PENDING`

## Reuse disclosure

- `/Users/arnav/Desktop/higgfield` is used only as an evidence/orchestration source; it is not evidence that TokenBar is a new business or that Gemini is deployed.
- Existing TokenBar Build Week materials, local smoke fixtures, HTML/CSS patterns, and packaging helpers must be disclosed if reused. They are not customer, revenue, production, or human-test proof.
- No date, user, customer, revenue, deployment, Gemini call, Google Cloud resource, or billing state may be inferred from templates or mock data.

## Closest blocker and next acceptance test

**Closest blocker:** establish the post-cutoff creation date of the business itself. Do not enable billing, deploy, publish, change accounts, or submit while this remains unresolved.

**Acceptance test:** a human-reviewed, contemporaneous source shows TokenBar's business activity began after 2026-05-19 10:00 AM Pacific, and its timestamp/source are recorded above without exposing personal data. Only then should the next bounded pass choose between a Google Cloud architecture record and an approval-gated deployed Gemini call.
