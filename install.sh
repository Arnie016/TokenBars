#!/usr/bin/env bash
set -euo pipefail

download_url="https://github.com/Arnie016/codex-goated-skills/releases/download/v0.1.0/CodexLimitBar-macOS-arm64-2026-05-20.zip"
launcher_url="https://raw.githubusercontent.com/Arnie016/TokenBar/main/bin/tokenbar"
install_dir="$HOME/Applications"
bin_dir="$HOME/.local/bin"
app_path="$install_dir/TokenBar.app"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/tokenbar-install.XXXXXX")"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

echo "Downloading TokenBar..."
curl -fL "$download_url" -o "$tmp_dir/TokenBar.zip"

echo "Unpacking TokenBar..."
ditto -x -k "$tmp_dir/TokenBar.zip" "$tmp_dir/unpacked"

source_app="$(find "$tmp_dir/unpacked" -maxdepth 2 -name '*.app' -type d | head -n 1)"
if [[ -z "$source_app" ]]; then
  echo "Could not find a .app bundle in the downloaded zip." >&2
  exit 1
fi

mkdir -p "$install_dir" "$bin_dir"
rm -rf "$app_path"
ditto "$source_app" "$app_path"

curl -fsSL "$launcher_url" -o "$bin_dir/tokenbar"
chmod +x "$bin_dir/tokenbar"

echo "Installed TokenBar to:"
echo "  $app_path"
echo
echo "Installed terminal command:"
echo "  $bin_dir/tokenbar"
echo
if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
  echo "Add this to your shell profile if tokenbar is not found:"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  echo
fi
echo "Open TokenBar now with:"
echo "  tokenbar"
