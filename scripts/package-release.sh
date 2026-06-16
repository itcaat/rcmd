#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

input_version="${1:-${VERSION:-local}}"

if [ "$input_version" = "local" ]; then
  tag="local"
else
  version="${input_version#v}"
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must be a semantic version like 0.1.0." >&2
    exit 1
  fi
  tag="v${version}"
fi

swift build -c release

bin_path="$(swift build -c release --show-bin-path)"
binary_path="${bin_path}/rcmd-app"

if [ ! -x "$binary_path" ]; then
  echo "Release binary not found at ${binary_path}" >&2
  exit 1
fi

dist_dir="${repo_root}/dist"
stage_dir="${dist_dir}/rcmd-${tag}-macos"
artifact_path="${dist_dir}/rcmd-${tag}-macos.dmg"

rm -rf "$stage_dir" "$artifact_path"
mkdir -p "$stage_dir"

cp "$binary_path" "${stage_dir}/rcmd-app"
cp README.md "${stage_dir}/README.md"

cat > "${stage_dir}/INSTALL.txt" <<'INSTALL'
This DMG contains an unsigned SwiftPM-built rcmd-app executable.

Copy rcmd-app to a writable location and run it from Terminal:

  ./rcmd-app

The app requires macOS Accessibility permission before global keyboard
shortcuts can work.
INSTALL

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "${stage_dir}/rcmd-app" >/dev/null 2>&1 || true
fi

hdiutil create \
  -volname "rcmd ${tag}" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$artifact_path"

echo "$artifact_path"
