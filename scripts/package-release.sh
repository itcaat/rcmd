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
app_path="${stage_dir}/rcmd.app"
contents_dir="${app_path}/Contents"
macos_dir="${contents_dir}/MacOS"
resources_dir="${contents_dir}/Resources"
iconset_path="${dist_dir}/AppIcon.iconset"
icon_path="${resources_dir}/AppIcon.icns"

rm -rf "$stage_dir" "$artifact_path" "$iconset_path"
mkdir -p "$macos_dir" "$resources_dir"

cp "$binary_path" "${macos_dir}/rcmd"
chmod +x "${macos_dir}/rcmd"
cp packaging/Info.plist "${contents_dir}/Info.plist"
cp README.md "${stage_dir}/README.md"
ln -s /Applications "${stage_dir}/Applications"

"${repo_root}/scripts/generate-app-icon.swift" "$iconset_path"
iconutil -c icns "$iconset_path" -o "$icon_path"
rm -rf "$iconset_path"

if [ "$tag" != "local" ]; then
  version="${tag#v}"
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${version}" "${contents_dir}/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${version}" "${contents_dir}/Info.plist"
fi

cat > "${stage_dir}/INSTALL.txt" <<'INSTALL'
This DMG contains an unsigned rcmd.app build.

Drag rcmd.app onto the Applications shortcut, then launch it normally from
/Applications.

The app requires macOS Accessibility permission before global keyboard
shortcuts can work.
INSTALL

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$app_path" >/dev/null 2>&1 || true
fi

hdiutil create \
  -volname "rcmd ${tag}" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$artifact_path"

echo "$artifact_path"
