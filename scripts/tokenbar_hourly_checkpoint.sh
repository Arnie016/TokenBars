#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

TRACKED_PATHS=(
  "README.md"
  "BUILD_WEEK_SCOPE.md"
  "SUBMISSION_CHECKLIST.md"
  "DEVPOST_PROGRESS.md"
  "DEVPOST_VOICE_NOTES.md"
  "SUPPORT.md"
  "api/"
  "docs/"
  "scripts/"
  "src/"
  "bin/"
)

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repository: $ROOT_DIR"
  exit 1
fi

git fetch origin >/dev/null 2>&1 || true

REMOTE_NAME="source"
if git remote | grep -qx 'origin'; then
  REMOTE_NAME="origin"
fi

if ! git status --short -- "${TRACKED_PATHS[@]}" | grep -q .; then
  echo "No tracked TokenBar checkpoint changes to commit."
  exit 0
fi

git add --all -- "${TRACKED_PATHS[@]}"

if git status --short --cached -- "${TRACKED_PATHS[@]}" | grep -q .; then
  now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  msg="build-week: tokenbar hourly checkpoint $now"
  git commit -m "$msg" >/dev/null

  if git remote | grep -qx "$REMOTE_NAME"; then
    echo "Committed. Attempting push to $REMOTE_NAME."
    git push "$REMOTE_NAME" "$(git rev-parse --abbrev-ref HEAD)" || echo "Push to $REMOTE_NAME failed; commit remains local."
  else
    echo "Committed locally only; no source remote configured."
  fi
else
  echo "No staged changes after add; nothing committed."
fi
