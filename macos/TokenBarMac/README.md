# TokenBar for macOS

TokenBar is a native, local-first Builder Intelligence app. It reads the safe
aggregate artifacts produced by the TokenBar CLI and presents five focused
surfaces:

- **Builder Story**: a compact six-axis identity card, strongest signal, next frontier, proof, and loop maturity.
- **Threads**: a read-only board backed by Codex's local thread and goal index,
  with active goals, forks, automation sources, Git review state, session IDs,
  workspace paths, native Codex deep links, and persistent local follow-up drafts.
- **Usage**: local token pace with proof-aware commentary.
- **Proof**: private report and opt-in share surfaces with explicit privacy boundaries.
- **Opportunities**: import a local project brief and prepare a bounded Codex kickoff.

Published proofs can be removed from the native **Proof** view. The action calls
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

The **Copy /side and open Codex** action copies an explicit side-chat prompt and
opens the original task through `codex://threads/<thread-id>`. It does not write
to Codex's database or interrupt the main task.

## Install the preview

The current downloadable preview targets Apple silicon and macOS 14 or newer:

[Download TokenBar-macOS.zip](https://github.com/Arnie016/TokenBars/releases/download/macos-app-preview-v0.1.1/TokenBar-macOS.zip)

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
tokenbar claim --days 7
```

The app invokes the installed `tokenbar` CLI only after the user presses the
analysis button. Importing or accepting a project brief does not clone a repo,
run code, or post externally. It stores the brief locally and copies a structured
kickoff prompt for Codex.
