#!/usr/bin/env python3
"""Guard the byte-identical invariant between the repo launcher and the packaged CLI.

bin/tokenbar is what runs during development; src/tokenbar/tokenbar is what the
wheel ships. They are two full copies of the same 600k script, so editing one
and building a release silently publishes the other. This check makes that
drift a build failure instead of a shipped regression.
"""
import hashlib
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BIN_CLI = ROOT / "bin" / "tokenbar"
SRC_CLI = ROOT / "src" / "tokenbar" / "tokenbar"
INSTALLED_CLI = Path(os.path.expanduser("~/.local/bin/tokenbar"))


def require(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    require(BIN_CLI.exists(), f"missing {BIN_CLI}")
    require(SRC_CLI.exists(), f"missing {SRC_CLI}")

    bin_sha = digest(BIN_CLI)
    src_sha = digest(SRC_CLI)
    require(
        bin_sha == src_sha,
        "bin/tokenbar and src/tokenbar/tokenbar have drifted, so a release would "
        "ship the packaged copy and not your edits.\n"
        f"       bin/tokenbar             {bin_sha}\n"
        f"       src/tokenbar/tokenbar   {src_sha}\n"
        "       fix: cp bin/tokenbar src/tokenbar/tokenbar",
    )
    require(
        os.access(SRC_CLI, os.X_OK),
        f"{SRC_CLI} is not executable, so the installed console script will not run",
    )

    print(f"PASS: launcher and packaged CLI are byte-identical ({bin_sha[:12]})")

    # The installed copy is machine state, not repo state, so it only warns.
    if INSTALLED_CLI.exists() and digest(INSTALLED_CLI) != bin_sha:
        print(
            f"WARN: {INSTALLED_CLI} is stale - reinstall to pick up this build "
            "(pip install --force-reinstall dist/*.whl)"
        )


if __name__ == "__main__":
    main()
