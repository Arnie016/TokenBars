#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
dist_dir="$repo_root/dist"
build_root="${TMPDIR:-/tmp}/tokenbar-judge-package"
artifact_name="tokenbar-macos-judge-package-$(date +%Y%m%d).zip"
artifact_path="$dist_dir/$artifact_name"
download_url="https://github.com/Arnie016/codex-goated-skills/releases/download/v0.1.0/CodexLimitBar-macOS-arm64-2026-05-20.zip"

cleanup() {
  rm -rf "$build_root"
}
trap cleanup EXIT

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required tool not found: $1" >&2
    exit 1
  fi
}

need curl
need ditto

mkdir -p "$dist_dir"
rm -rf "$build_root"
mkdir -p "$build_root/package"

tmp_zip="$build_root/TokenBar-macOS.zip"
tmp_unpack="$build_root/unpacked"
mkdir -p "$tmp_unpack"

echo "Downloading judge package baseline from existing release bundle..."
curl -fL "$download_url" -o "$tmp_zip"
ditto -x -k "$tmp_zip" "$tmp_unpack"

app_path="$(find "$tmp_unpack" -maxdepth 3 -name '*.app' -type d | head -n 1 || true)"
if [[ -z "$app_path" ]]; then
  echo "No .app bundle found in release zip." >&2
  exit 1
fi

package_root="$build_root/package"
mkdir -p "$package_root"
cp "$repo_root/install.sh" "$package_root/install.sh"
cp "$repo_root/README.md" "$package_root/README.md"
cp "$repo_root/PRIVACY.md" "$package_root/PRIVACY.md"
cp "$repo_root/bin/tokenbar" "$package_root/tokenbar"
cp -R "$app_path" "$package_root/TokenBar.app"
chmod +x "$package_root/install.sh" "$package_root/tokenbar"

echo "Building macOS judge zip package: $artifact_path"
rm -f "$artifact_path"
ditto -c -k --sequesterRsrc --keepParent "$package_root" "$artifact_path"

artifact_size="$(wc -c < "$artifact_path" | awk '{print $1}')"
if (( artifact_size > 325 * 1024 * 1024 )); then
  echo "Built artifact exceeds 325MB: $artifact_size bytes" >&2
  exit 1
fi

echo "Built package size: $artifact_size bytes"
echo "$artifact_path"
