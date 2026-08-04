# TokenBar Prompt Playbook Library

TokenBar playbooks are copy-ready operating orders for AI coding agents. They reduce wasteful tokens by making budget, route, context, stop conditions, verification, and final evidence explicit before a run starts.

Privacy boundary:
- Never paste credentials, private keys, OAuth tokens, payment details, or personal contact lists into a playbook.
- Keep raw transcripts, source code, customer data, and local logs on the user's machine unless the project owner explicitly approves that exact action.
- External actions such as publishing, posting, purchasing, emailing, account changes, cloud provisioning, and paid compute require fresh approval at action time.
- Label source claims, local proof, public proof, inference, and human judgment separately.

## How To Use

Each card has a tier, a use case, a copy block, and the waste pattern it prevents. Free templates teach the basic operating style. Pro templates are premium workflows for launches, system prompts, context handoffs, cost control, and team comparison.

## Launch And Scope

### 001. Mission Lock
Tier: Free
Use when: a task could sprawl.
Copy: `Budget: Medium | Route: smallest useful implementation | Timebox: one bounded pass | Context cap: only directly affected files | Stop: destructive scope, credentials, paid services, or unclear ownership. First restate the outcome, then implement one verified improvement.`
Why it saves tokens: prevents broad exploration before the finish line is clear.

### 002. One-Screen Promise
Tier: Free
Use when: a UI feels like a dashboard.
Copy: `Define the product promise in one sentence, then redesign only the first screen so the primary action is obvious. Verify with a screenshot and one usability risk.`
Why it saves tokens: forces product intent before component churn.

### 003. Launch Gate Ledger
Tier: Pro
Use when: preparing Product Hunt, Macapp Supply, or a public launch.
Copy: `Audit launch readiness with gates: public URL, working core loop, download/build status, privacy/contact pages, screenshots, short video plan, pricing truth, and rollback. Do not submit. Return PASS/BLOCKED per gate with exact evidence.`
Why it saves tokens: prevents claiming launch readiness from local polish.

### 004. Core Loop First
Tier: Free
Use when: the app has many tabs but weak action.
Copy: `Find the one core loop. Improve only that loop. Keep navigation secondary. Verify that a first-time user can understand start, result, and next action without reading docs.`
Why it saves tokens: removes feature scatter.

### 005. Scope Receipt
Tier: Free
Use when: starting a long agent run.
Copy: `Before touching files, output a scope receipt: goal, files likely touched, files protected, verifier, blocker, and one stop condition. Continue only if the change fits that receipt.`
Why it saves tokens: avoids late discoveries that invalidate the run.

### 006. Tiny Shipping Slice
Tier: Free
Use when: ambition is outrunning closure.
Copy: `Choose one improvement that can be verified in under 20 minutes. Implement it, run one narrow check, and report the exact remaining blocker.`
Why it saves tokens: turns big plans into evidence.

### 007. Product Surface Split
Tier: Pro
Use when: there is a website, Mac app, CLI, and menu-bar app.
Copy: `Separate surfaces by job: menu bar for live usage, Mac app for reports/sharing, CLI for automation, website for launch/commerce. Improve one cross-link between surfaces and verify it.`
Why it saves tokens: prevents mixing every product job into one screen.

### 008. Audience Anchor
Tier: Free
Use when: copy sounds generic.
Copy: `Name the specific user, their anxious moment, and the decision they need. Rewrite the visible copy around that decision. Keep claims truthful and locally verifiable.`
Why it saves tokens: stops generic SaaS language rewrites.

### 009. No-Submit Launch Draft
Tier: Pro
Use when: filling launch forms later.
Copy: `Draft Product Hunt/Macapp Supply fields from verified product evidence only. Mark unknowns as TBD. Do not submit or upload. Return title, tagline, description, makers note, media checklist, and blockers.`
Why it saves tokens: prepares assets without accidental external actions.

### 010. Proof Before Polish
Tier: Free
Use when: visuals are improving but behavior is unknown.
Copy: `Run the narrowest behavioral proof first. Only polish copy or visuals after the feature has local evidence. Separate screenshot proof from functional proof.`
Why it saves tokens: avoids polishing broken flows.

### 011. Dirty Tree Respect
Tier: Free
Use when: editing an active repo.
Copy: `Check git status. Preserve unrelated changes. Touch only files needed for this goal. Never reset or revert user work. Report files changed by this run separately.`
Why it saves tokens: avoids expensive recovery after accidental overwrite.

### 012. Honest Demo Script
Tier: Pro
Use when: making a launch video.
Copy: `Write a 45-second demo script showing only working surfaces: problem, live menu-bar action, data story, budget reminder, playbook copy, and final CTA. Flag shots needing fresh capture.`
Why it saves tokens: keeps media production truthful.

### 013. First-Run Welcome Gate
Tier: Pro
Use when: onboarding feels abrupt.
Copy: `Design a first-run flow: one central Analyze action, progress state, two MCQ confirmation questions, then app entry. Keep sign-in optional and explain local evidence in one sentence.`
Why it saves tokens: avoids building settings before the user has context.

### 014. One-Line Claim Auditor
Tier: Free
Use when: marketing copy may overstate.
Copy: `For each claim, label it as verified local proof, public proof, inference, planned, or unsupported. Rewrite unsupported claims into planned or remove them.`
Why it saves tokens: prevents rework from inflated copy.

### 015. Launch Day Stop Rule
Tier: Pro
Use when: working under time pressure.
Copy: `For the next hour, allow only launch-critical changes. Stop on auth, paid services, broken build, or missing public URL. End with ready, blocked, and next human gate.`
Why it saves tokens: prevents launch-day rabbit holes.

## Cost And Budget Control

### 016. Cost Saver Header
Tier: Free
Use when: asking an agent for any nontrivial task.
Copy: `Budget: Low unless blocked | Route: inspect first, edit second | Context cap: 6 files max | Stop: secrets, paid services, or broad refactor. Return only decision-relevant output.`
Why it saves tokens: reduces needless context loading.

### 017. Token Waste Review
Tier: Pro
Use when: a session consumed too much.
Copy: `Review this task for waste patterns: unclear goal, repeated commands, broad file reads, failed verifier loops, oversized final answer, or premature design churn. Return top three fixes for next prompt.`
Why it saves tokens: turns wasted tokens into reusable rules.

### 018. Budget Reservoir
Tier: Pro
Use when: setting daily, weekly, monthly, or yearly caps.
Copy: `Convert my budget into reminders: cap, reset window, warning threshold, hard stop, allowed override, notification copy, and suggested action.`
Why it saves tokens: makes limits operational.

### 019. Cheap Decisive Experiment
Tier: Free
Use when: a task may need expensive compute.
Copy: `Find the cheapest decisive local experiment. Do not provision GPU, paid API, or cloud resources. Return what the experiment proves and what it cannot prove.`
Why it saves tokens: avoids expensive exploration.

### 020. Forecast With Uncertainty
Tier: Pro
Use when: projecting usage or cost.
Copy: `Build a forecast with best, expected, and danger ranges. Include assumptions, error bars, sample size, and the action to take if the danger range crosses budget.`
Why it saves tokens: avoids false precision.

### 021. Cost Passport
Tier: Pro
Use when: summarizing a date range.
Copy: `Create a cost passport for this range: total spend, peak day, provider split, command used, missing data, waste flags, and one cost-saving prompt for next run.`
Why it saves tokens: turns cost tables into decisions.

### 022. Quiet Day Is Not Failure
Tier: Free
Use when: interpreting inactive days.
Copy: `Explain quiet days separately from wasted days. Quiet means no measured activity; wasted means repeated work without evidence. Do not punish rest.`
Why it saves tokens: prevents misleading gamification.

### 023. Rate Limit Warning
Tier: Pro
Use when: quotas matter.
Copy: `Set a warning model for usage limits: current pace, reset window, time to threshold, confidence, notification copy, and safe fallback.`
Why it saves tokens: avoids lockouts mid-task.

### 024. Cost-Aware Model Route
Tier: Pro
Use when: choosing model effort.
Copy: `Pick the cheapest model/effort route that can solve this. State when to escalate, what evidence justifies escalation, and what smaller route failed.`
Why it saves tokens: stops defaulting to high effort.

### 025. Output Diet
Tier: Free
Use when: final answers are too long.
Copy: `Keep final output under 12 lines unless code or launch copy requires more. Include changed files, verifier, blocker, and one next action.`
Why it saves tokens: controls answer sprawl.

### 026. Repeat Prompt Detector
Tier: Pro
Use when: the same prompt gets reused often.
Copy: `Detect repeated prompt patterns and turn the best one into a reusable template with placeholders, validation, and stop conditions. Flag repeats that should be retired.`
Why it saves tokens: converts repetition into a product asset.

### 027. Context Compression Gate
Tier: Free
Use when: a task is getting long.
Copy: `Compress context into current goal, decisions, changed files, verification, blockers, and next action. Do not include raw logs unless needed for the next command.`
Why it saves tokens: keeps handoffs small.

### 028. Spend Approval Boundary
Tier: Free
Use when: a task could trigger payment or cloud usage.
Copy: `Do not spend money, consume paid credits, provision cloud resources, or start paid media. Prepare the plan and exact approval question only.`
Why it saves tokens: avoids unsafe external-action loops.

### 029. Wasteful Token Tagger
Tier: Pro
Use when: building analytics.
Copy: `Classify token usage as useful exploration, implementation, verification, recovery, repeated failure, or over-answering. Show only aggregate labels, never raw prompts.`
Why it saves tokens: makes waste measurable.

### 030. Budget Review Closeout
Tier: Free
Use when: ending a run.
Copy: `End with budget review: what consumed time/tokens, what proof was produced, what remains unknown, and the single cheapest next check.`
Why it saves tokens: prevents vague continuation.

## System Prompt And Constitution

### 031. System Prompt Hardener
Tier: Pro
Use when: improving an agent constitution.
Copy: `Review this system prompt for ambiguity, unsafe authority, missing stop conditions, credential exposure, and weak evidence boundaries. Patch only the highest-risk issue and verify behavior with one adversarial prompt.`
Why it saves tokens: hardens rules without rewriting the whole system.

### 032. Bounded Constitution Patch
Tier: Pro
Use when: a rule needs refinement.
Copy: `Change one constitution rule. Preserve existing intent. Add a short example, a stop condition, and a verifier. Do not broaden authority or weaken approval gates.`
Why it saves tokens: prevents constitution bloat.

### 033. Adversarial Prompt Critique
Tier: Pro
Use when: a campaign prompt may be too permissive.
Copy: `Critique this prompt as an adversary. Find ways it could cause scope creep, credential leakage, fabricated proof, external actions, or costly loops. Return fixes before implementation.`
Why it saves tokens: catches failure modes early.

### 034. Evidence Boundary Rewriter
Tier: Free
Use when: an agent mixes assumptions and proof.
Copy: `Rewrite the instruction so source claim, local proof, public proof, inference, and human judgment are separate. Add one verifier and one stop condition.`
Why it saves tokens: avoids repeated clarification.

### 035. Tool Authority Limit
Tier: Free
Use when: tools could mutate external state.
Copy: `Use tools for read-only inspection unless I explicitly approve a mutation. Before any mutation, state target, expected proof, rollback, and approval question.`
Why it saves tokens: prevents unsafe tool retries.

### 036. Skill Router
Tier: Pro
Use when: many skills/plugins exist.
Copy: `Choose at most two skills. Explain why each is necessary. Read their instructions before acting. If no skill fits, proceed with standard repo inspection.`
Why it saves tokens: avoids plugin collage.

### 037. Secret Hygiene
Tier: Free
Use when: credentials may be involved.
Copy: `Never print, store, screenshot, or transmit secrets. Check only secret presence through approved local routes. Treat credential availability as not permission to spend or publish.`
Why it saves tokens: avoids security cleanup.

### 038. External Action Lock
Tier: Free
Use when: launch, outreach, or payment may happen.
Copy: `Prepare drafts and checklists only. Do not post, submit, email, DM, buy, deploy, or change account settings without explicit action-time approval.`
Why it saves tokens: keeps planning separate from execution.

### 039. Claim Calibration
Tier: Free
Use when: product copy sounds too confident.
Copy: `Calibrate every claim. Use present tense only for verified behavior. Use planned, preview, or blocked for everything else.`
Why it saves tokens: reduces later copy correction.

### 040. Approval-Gated Automation
Tier: Pro
Use when: adding reminders or monitors.
Copy: `Design the automation with cadence, trigger, notification copy, data read, storage, and stop conditions. Do not schedule it until approval.`
Why it saves tokens: separates automation design from activation.

### 041. Prompt Constitution Header
Tier: Free
Use when: starting a complex thread.
Copy: `Budget: High only if needed | Route: inspect -> implement -> verify | Context cap: directly affected files | Stop: credentials, paid services, destructive changes, or unverifiable claims.`
Why it saves tokens: makes expectations visible.

### 042. Model Escalation Rule
Tier: Pro
Use when: model choice matters.
Copy: `Start cheap. Escalate only after a concrete blocker, failing verifier, or architectural uncertainty. Record why escalation is justified and what smaller route failed.`
Why it saves tokens: prevents unnecessary high-cost runs.

### 043. Safety Regression Test
Tier: Pro
Use when: editing trust/privacy code.
Copy: `Add or update one regression check proving the change does not expose raw transcripts, source code, credentials, or unapproved external actions.`
Why it saves tokens: catches trust bugs automatically.

### 044. Prompt Marketplace Guard
Tier: Pro
Use when: selling templates.
Copy: `Review a prompt pack for public safety: no secrets, no private raw data requirement, clear tier, exact output, stop conditions, and refund/unsupported boundaries.`
Why it saves tokens: makes commerce assets safer.

### 045. Agent Operating Order
Tier: Free
Use when: delegating to Codex.
Copy: `You are an implementation agent. Read the repo first, preserve user changes, make one bounded edit, verify it, and report only action, evidence, blocker, and next step.`
Why it saves tokens: avoids brainstorming when implementation is needed.

## Threads And Handoffs

### 046. Thread Handoff
Tier: Pro
Use when: offloading work to another task.
Copy: `Create a handoff with objective, repo, current files, decisions, blockers, verification run, exact next command, and stop conditions. Exclude raw transcripts and secrets.`
Why it saves tokens: prevents the next thread from rereading everything.

### 047. Resume Without Restarting
Tier: Free
Use when: returning after context loss.
Copy: `Continue from the latest verified state. Do not restart. First identify last changed files, last verifier, and current blocker, then proceed with one safe next edit.`
Why it saves tokens: avoids duplicate work.

### 048. Thread Title Upgrade
Tier: Pro
Use when: thread names are confusing.
Copy: `Rename threads with action + product + proof status. Avoid emergency words unless true. Examples: Build TokenBar Playbook Library, Verify Menu-Bar Forecast, Draft Launch Media.`
Why it saves tokens: improves navigation.

### 049. Board Column Rewrite
Tier: Pro
Use when: Kanban columns feel unclear.
Copy: `Replace vague columns with workflow states: Ready, Building, Waiting, Verified, Archived. Define entry and exit rules for each column.`
Why it saves tokens: reduces board interpretation overhead.

### 050. Drag Priority Rules
Tier: Pro
Use when: users rearrange thread boards.
Copy: `Design drag/drop rules: manual rank wins, stale items fade, active goals pin, blocked tasks show reason, and verified tasks collapse. Preserve read-only source data.`
Why it saves tokens: makes board behavior predictable.

### 051. Fork Decision
Tier: Free
Use when: one task is branching.
Copy: `Decide whether to continue here or fork. Fork only if the new objective has different files, verifier, or approval gate. Otherwise keep the work in this thread.`
Why it saves tokens: avoids fragmentation.

### 052. Handoff Receipt
Tier: Free
Use when: stopping mid-run.
Copy: `Write a receipt: done, changed files, commands run, commands not run, blockers, and the exact next command.`
Why it saves tokens: preserves continuity.

### 053. Timeline Evidence Thread
Tier: Pro
Use when: building a history view.
Copy: `Turn session metadata into a left-to-right timeline with date, project, token weight, proof badge, and why the identity changed. Use aggregates only.`
Why it saves tokens: avoids raw transcript dependency.

### 054. Gallery From Timeline
Tier: Pro
Use when: timeline cards feel boring.
Copy: `Create a gallery under the timeline with grouped days, top movement, identity shift, and one evidence image/texture per group. Keep it horizontally browsable.`
Why it saves tokens: gives visual structure to history.

### 055. Pause And Arrange
Tier: Pro
Use when: boards or timelines move too fast.
Copy: `Add pause, drag, and manual arrangement controls. Save customization separately from read-only source state.`
Why it saves tokens: avoids fighting automated layouts.

### 056. Thread Health Labels
Tier: Free
Use when: board language is confusing.
Copy: `Use plain labels: Ready, In progress, Needs answer, Checked, Done. Remove triage/rescue/unblock unless those words are directly explained.`
Why it saves tokens: reduces user confusion.

### 057. Long Thread Compression
Tier: Pro
Use when: a thread keeps continuing forever.
Copy: `Summarize long work into chapters with decisions, artifacts, evidence, and unresolved gates. Collapse repeated automation or idle turns.`
Why it saves tokens: trims endless scroll.

### 058. Active Goal Guard
Tier: Free
Use when: a task may drift.
Copy: `Restate the active goal and newest user request. If they conflict, follow the newest request. If they align, continue with the smallest verified step.`
Why it saves tokens: prevents ghost objectives.

### 059. Cross-Thread Offload
Tier: Pro
Use when: moving work from one agent to another.
Copy: `Prepare a minimal offload packet: objective, constraints, files owned by this thread, files protected, and validation command. Do not include hidden reasoning.`
Why it saves tokens: keeps collaboration safe.

### 060. Archive Candidate
Tier: Free
Use when: cleaning old tasks.
Copy: `Mark archive candidates only when final proof exists or the task is obsolete. Keep active launch, payment, or user-review blockers visible.`
Why it saves tokens: avoids losing live work.

## Verification And Evidence

### 061. Verifier First
Tier: Free
Use when: adding a feature.
Copy: `Before editing, identify the verifier. After editing, run it. If it is too slow, run the closest narrow check and state the limitation.`
Why it saves tokens: prevents unverified changes.

### 062. Local/Public Proof Split
Tier: Free
Use when: preparing launch copy.
Copy: `Separate local proof, public proof, and human proof. Do not call a public launch ready unless the public URL and core flow are tested.`
Why it saves tokens: avoids false readiness.

### 063. Slow Build Wrapper
Tier: Pro
Use when: builds hang.
Copy: `Run the build with a bounded timeout. If it times out without diagnostics, stop cleanly, check for lingering processes, and report no compiler proof.`
Why it saves tokens: avoids indefinite tool waits.

### 064. Screenshot Smoke
Tier: Pro
Use when: changing UI.
Copy: `Open the page/app, inspect one representative viewport, confirm key text and layout, note console/runtime errors, and distinguish existing errors from new ones.`
Why it saves tokens: gives visual proof without exhaustive QA.

### 065. Contract Verifier
Tier: Pro
Use when: preventing regressions.
Copy: `Write a small script that checks for required product contract strings and forbidden stale markers. Run it after edits.`
Why it saves tokens: catches product drift fast.

### 066. Privacy Proof
Tier: Free
Use when: analytics or reports read local data.
Copy: `Verify that the feature uses aggregate metadata only and does not expose raw prompts, transcripts, source code, credentials, or full private paths.`
Why it saves tokens: avoids trust regressions.

### 067. Evidence Card
Tier: Pro
Use when: building report UI.
Copy: `For each insight, show metric, source category, confidence, missing data, and one action. Avoid dumping raw logs.`
Why it saves tokens: turns data into decisions.

### 068. Fixture Honesty
Tier: Free
Use when: using demo data.
Copy: `Label fixture/demo data clearly. Do not present it as connected account, real spend, real usage, or live provider proof.`
Why it saves tokens: avoids later correction.

### 069. Accessibility Pass
Tier: Pro
Use when: shipping UI polish.
Copy: `Check keyboard access, focus states, labels, contrast, reduced motion, and text fit. Patch only the highest-risk accessibility issue.`
Why it saves tokens: focuses UI quality.

### 070. Regression Summary
Tier: Free
Use when: finishing.
Copy: `Report tests run, checks skipped, why skipped, and remaining risk. Do not imply full test coverage from narrow checks.`
Why it saves tokens: keeps final answers honest.

### 071. Command Echo Boundary
Tier: Free
Use when: showing terminal output.
Copy: `Summarize important command output. Do not paste secrets, giant logs, or noisy unchanged lines.`
Why it saves tokens: keeps results readable.

### 072. Broken State Triage
Tier: Pro
Use when: a verifier fails.
Copy: `Classify failure as code regression, environment issue, missing dependency, timeout, auth gate, or stale verifier. Fix only code regressions in scope.`
Why it saves tokens: stops random patching.

### 073. Public Claim Receipts
Tier: Pro
Use when: creating shareable reports.
Copy: `Attach receipts: generated at, data range, local-only fields, public fields, excluded data, and takedown/dispute path.`
Why it saves tokens: makes sharing defensible.

### 074. Diff Hygiene
Tier: Free
Use when: before finishing edits.
Copy: `Run a whitespace/diff hygiene check. Report unrelated dirty files separately and do not revert them.`
Why it saves tokens: avoids noisy cleanup.

### 075. Human Gate Marker
Tier: Free
Use when: machine proof is not enough.
Copy: `Name the next human/device gate explicitly: visual review, account login, launch submission, payment approval, app signing, or public smoke.`
Why it saves tokens: prevents premature done.

## Design And Data Storytelling

### 076. Data Story Slide
Tier: Pro
Use when: charts feel like tables.
Copy: `Turn one chart into a slide: title as decision, one visual metaphor, one measured number, one uncertainty note, and one action.`
Why it saves tokens: avoids stat dumping.

### 077. Liquid Composition
Tier: Pro
Use when: provider mix looks boring.
Copy: `Represent provider composition as a liquid donut or orbit. Keep measured lanes solid, setup lanes ghosted, and hover states exact.`
Why it saves tokens: gives visual rules before coding.

### 078. Forecast Ribbon
Tier: Pro
Use when: projection needs detail.
Copy: `Design a forecast ribbon with expected path, upper/lower error bars, budget threshold, reset window, and alert timing.`
Why it saves tokens: specifies the chart contract.

### 079. Cadence Waveform
Tier: Pro
Use when: rest/work rhythm matters.
Copy: `Show active days as pulses and quiet days as low marks. Label quiet days as not wasted. Add average work run and average quiet run.`
Why it saves tokens: avoids misleading streak mechanics.

### 080. Cost Passport Visual
Tier: Pro
Use when: cost breakdown needs a unique surface.
Copy: `Create a passport card for selected dates: stamp per provider, total cost, peak day, range drag handle, and command receipt.`
Why it saves tokens: replaces dense tables.

### 081. Memory Pressure Story
Tier: Pro
Use when: Chrome and agents overload the machine.
Copy: `Show memory pressure as grouped particles: apps cluster by pressure, explain the likely overload cause, and require approval before closing or restarting apps.`
Why it saves tokens: turns system state into a safe decision.

### 082. Identity Texture
Tier: Pro
Use when: identity cards feel generic.
Copy: `Assign each identity a texture language, not a rank: paper grain, stitched patch, circuit vellum, liquid metal, archive stamp, or field map. Explain what changed in the timeline.`
Why it saves tokens: prevents arbitrary titles.

### 083. No-Rank Identity
Tier: Free
Use when: gamification feels judgmental.
Copy: `State that identities are forms, not better/worse ranks. Comparison can show percentile on specific metrics, not human worth.`
Why it saves tokens: avoids toxic leaderboard copy.

### 084. MCQ Reveal
Tier: Pro
Use when: first-run analysis should feel interactive.
Copy: `After analysis reaches 100%, ask two MCQ questions that confirm the interpretation. Only then reveal the assigned identity and allow entry.`
Why it saves tokens: makes onboarding participatory.

### 085. Paper Gradient Audit
Tier: Pro
Use when: visuals feel flat.
Copy: `Apply one paper-gradient system: background texture, accent ink, card surface, and active state. Remove conflicting accent colors.`
Why it saves tokens: keeps the brand coherent.

### 086. Slideshow Story Flow
Tier: Pro
Use when: story view is awkward.
Copy: `Turn story into slides with fixed stage, chapter progress, left/right movement, one visual per slide, and no vertical scroll dependency.`
Why it saves tokens: specifies interaction.

### 087. Heat Map Profile
Tier: Pro
Use when: profile needs depth.
Copy: `Add a heat map grid showing active days, token intensity, project count, and identity shifts. Include hover details and a legend.`
Why it saves tokens: condenses history visually.

### 088. Landing Motion Rule
Tier: Free
Use when: adding animation.
Copy: `Use motion to explain token assembly, budget drift, or report reveal. Remove motion that is only decoration. Respect reduced motion.`
Why it saves tokens: prevents visual noise.

## Connectors, Accounts, And Local System

### 089. Account Clarity
Tier: Pro
Use when: multiple accounts are possible.
Copy: `Show current account, source, connection status, last refresh, and what data is measured. Refresh after sign-in. Never mix accounts silently.`
Why it saves tokens: prevents confusing provider data.

### 090. Connector Truth Table
Tier: Free
Use when: providers are partly configured.
Copy: `For each connector, label measured, connected, demo, setup needed, or unsupported. Never draw usage from unmeasured providers.`
Why it saves tokens: avoids fake chart segments.

### 091. Add Provider Lane
Tier: Pro
Use when: supporting a new IDE or agent.
Copy: `Add a provider lane with id, title, setup state, measured flag, data source, refresh action, and fallback copy. Do not invent usage.`
Why it saves tokens: standardizes connectors.

### 092. Plus Button Provider Flow
Tier: Pro
Use when: users need many IDEs.
Copy: `Design an Add Source flow: choose IDE/agent, explain data needed, connect/read locally, verify sample, then show measured status.`
Why it saves tokens: avoids hardcoding every future provider.

### 093. Cloud Sign-In Refresh
Tier: Pro
Use when: account sign-in does not update.
Copy: `After sign-in, refresh provider status, account label, token totals, last checked time, and error state. Show stale state if refresh fails.`
Why it saves tokens: reduces manual debugging.

### 094. Reminder Composer
Tier: Pro
Use when: budgets need user guidance.
Copy: `Build a guide that asks target budget, reset date, warning threshold, preferred notification tone, sound/haptic preference, and hard-stop behavior.`
Why it saves tokens: lets users configure once.

### 095. Sound Haptic Taste Test
Tier: Pro
Use when: feedback feels annoying.
Copy: `Offer quiet, crisp, cinematic, and off. Default off for sound and haptics. Preview locally. Respect system settings.`
Why it saves tokens: prevents taste churn.

### 096. App Download Cross-Sell
Tier: Free
Use when: menu bar should advertise the Mac app.
Copy: `Add a clear Download Mac app action from the menu-bar surface and website. Explain that the menu bar tracks usage and the Mac app turns it into reports.`
Why it saves tokens: clarifies product ecosystem.

### 097. Local Automation Safety
Tier: Pro
Use when: restarting apps or restoring windows.
Copy: `Design overload recovery as approval-gated: diagnose memory pressure, propose apps to close/reopen, list risks, ask approval, then restore state where possible.`
Why it saves tokens: avoids destructive automation.

### 098. CLI Premium Motion
Tier: Pro
Use when: terminal output feels basic.
Copy: `Improve CLI presentation with concise progress, semantic color, structured sections, cost badges, and a final receipt. Avoid noisy spinners in non-interactive output.`
Why it saves tokens: makes terminal UX useful.

### 099. Website To App Loop
Tier: Pro
Use when: web, CLI, and apps should feel connected.
Copy: `Create a loop: website explains, CLI installs, menu bar measures, Mac app reports, website hosts shareable proof. Add one link or command that closes a gap.`
Why it saves tokens: avoids disconnected surfaces.

### 100. Freemium Boundary
Tier: Pro
Use when: deciding paid vs free.
Copy: `Define Free: local tracking, basic budgets, four templates, private reports. Define Pro: public profiles, comparison engine, premium prompt library, reminders, team benchmarks, and advanced exports.`
Why it saves tokens: prevents unclear monetization.

