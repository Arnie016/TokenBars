# TokenBar for macOS

TokenBar is a native, local-first Builder Intelligence app. It reads the safe
aggregate artifacts produced by the TokenBar CLI and presents six focused
surfaces:

- **Builder Story**: a compact six-axis identity card, strongest signal, next frontier, proof, and loop maturity.
- **Threads**: a read-only board backed by Codex's local thread and goal index,
  with active goals, forks, automation sources, Git review state, session IDs,
  workspace paths, native Codex deep links, persistent local follow-up drafts,
  unlimited saved boards, and an installable Thread Store.
- **Profile**: one adjustable local token total, daily motion, cost, and
  evidence-aware commentary.
- **Storage**: a bounded local map of generated build/cache weight with
  per-folder review and recoverable Move to Trash actions.
- **Report**: private report and opt-in share surfaces with explicit privacy boundaries.
- **Thread Store**: browse installable thread workflows, import a project brief,
  and prepare a bounded Codex kickoff without claiming live multiplayer sync.

The native **Report** view first renders a privacy-safe unlisted preview. Publishing
requires a second confirmation, then calls `tokenbar publish-proof --unlisted
--hide-owner --hide-region` and reloads the persisted receipt with its TBAR token
and server action run ID. The same receipt is restored after an app restart.
The published view also renders the six completed server stages, the exact safe
material sent, the data classes that stayed local, and the device-bound ownership
state. **Copy receipt** produces a compact, inspectable handoff for judges or peers.

Published proofs can be removed from the native **Report** view. The action calls
the owner-bound `tokenbar revoke` lifecycle: public card/profile/feed/ranking
surfaces are removed while private local reports and usage history are retained.

Raw transcripts, source code, credentials, and imported project briefs are not
uploaded by the macOS app.

The Threads surface reads `~/.codex/state_5.sqlite` through macOS's bundled
`sqlite3` in read-only mode. Its lanes are intentionally conservative: Focus
means an active Codex goal, Recent means touched within 24 hours, and Review
means paused, blocked, limited, or older. Git state is gathered with a read-only
`git status` call. TokenBar does not infer that a task shipped from token volume.

Follow-up drafts are stored at:

```text
~/Library/Application Support/CodexLimitBar/thread-follow-up-drafts.json
```

Custom boards and installed Thread Store kits are stored at:

```text
~/Library/Application Support/CodexLimitBar/thread-boards.json
```

Thread Store kits install real local boards with named lanes. The ten-seat Crew
Room is an ownership and handoff layout today. Live collaborators, invitations,
and presence require the future signed-in workspace backend; the preview does
not claim that local board persistence is real-time multi-user sync.

The **Copy /side and open Codex** action copies an explicit side-chat prompt and
opens the original task through `codex://threads/<thread-id>`. It does not write
to Codex's database or interrupt the main task.

## Install the preview

The current downloadable preview targets Apple silicon and macOS 14 or newer:

[Download TokenBar-macOS.zip](https://github.com/Arnie016/TokenBars/releases/download/macos-app-preview-v0.1.2/TokenBar-macOS.zip)

1. Unzip `TokenBar-macOS.zip`.
2. Move `TokenBar.app` into Applications.
3. Control-click the app and choose **Open** on first launch if Gatekeeper asks.

This preview is ad-hoc signed but not Apple-notarized. A later public distribution
build should use a Developer ID certificate and Apple notarization.

## Build

Requires macOS 14 or newer and Xcode.

```bash
cd macos/TokenBarMac
./build-app.sh
```

Artifacts:

```text
dist/TokenBar.app
dist/TokenBar-macOS.zip
```

The local build is ad-hoc signed. A public release still needs a Developer ID
signature and Apple notarization before first launch can avoid Gatekeeper warnings.

## Local data

The app reads generated artifacts from:

```text
~/Library/Application Support/CodexLimitBar/
```

Create or refresh a Builder Story from the app's **Analyze this week** button,
or run:

```bash
tokenbar report
```

The app invokes the installed `tokenbar` CLI only after the user presses the
analysis button. Importing or accepting a project brief does not clone a repo,
run code, or post externally. It stores the brief locally and copies a structured
kickoff prompt for Codex.

Builder Story now reads the same `tokenbar.builder_bundle.v1` contract exposed by
`tokenbar api`. It tries the read-only localhost endpoint first, then the packaged
`tokenbar api --snapshot` command, and finally the newest private local identity
file. The active evidence source is visible on the Builder Story card. The app
bundle includes the CLI snapshot module, so this path does not depend on a newer
global TokenBar installation.

The **Connect Codex** action copies a `codex mcp add` command that points to the CLI
inside the currently running app. That MCP server is read-only and returns the same
sanitized Builder Identity, aggregate usage, and privacy receipt as the local API;
it has no publish action and cannot expose raw prompts, transcripts, source code,
local paths, or secrets.

The Report page's **Download report** action opens a native save panel, runs the
bundled `tokenbar proof` exporter, verifies the resulting ZIP with `tokenbar verify`,
and reveals the verified artifact in Finder. The packet stays local until the user
separately chooses to share it.

The Storage surface scans only a fixed allowlist of generated dependency, build,
coverage, and cache directory names under indexed Codex workspaces. Source
folders, Codex sessions/logs, Builder Identity reports, and share receipts are
inspect-only. TokenBar never empties Trash and asks before moving one recognized
generated folder.
