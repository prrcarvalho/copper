#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_bundle="$repo_root/.build/Copper.app"
install_bundle="/Applications/Copper.app"
bundle_identifier="com.pedrocarvalho.copper-reconstruction"
build_executable="$build_bundle/Contents/MacOS/Copper"
installed_executable="$install_bundle/Contents/MacOS/Copper"
trash_dir="$HOME/.Trash"
timestamp="$(date +%Y%m%d-%H%M%S)"
backup_bundle="$trash_dir/Copper.app-$timestamp"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
staging_bundle="/Applications/.Copper.app.install.$$"
old_bundle_moved=false

cleanup() {
  if [[ -d "$staging_bundle" ]]; then
    rm -rf "$staging_bundle"
  fi
}
trap cleanup EXIT

running_pids_for() {
  local executable="$1"
  pgrep -f "^${executable}( |$)" || true
}

for executable in "$build_executable" "$installed_executable"; do
  existing_pids="$(running_pids_for "$executable")"
  if [[ -n "$existing_pids" ]]; then
    print -u2 "InstallApp: REFUSED — Copper is running: $existing_pids"
    print -u2 "Quit Copper and rerun this installer so the bundle is replaced safely."
    exit 1
  fi
done

if [[ ! -d "/Applications" || ! -w "/Applications" ]]; then
  print -u2 "InstallApp: REFUSED — /Applications is not writable by this user."
  exit 1
fi

"$repo_root/Scripts/BuildApp.sh" >/dev/null

codesign --verify --deep --strict "$build_bundle"
test -s "$build_bundle/Contents/Resources/AppIcon.icns"
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$build_bundle/Contents/Info.plist")" == "$bundle_identifier" ]]

mkdir -p "$trash_dir"
mkdir "$staging_bundle"
ditto "$build_bundle" "$staging_bundle/Copper.app"

if [[ -e "$install_bundle" ]]; then
  mv "$install_bundle" "$backup_bundle"
  old_bundle_moved=true
fi

if ! mv "$staging_bundle/Copper.app" "$install_bundle"; then
  if [[ "$old_bundle_moved" == true && ! -e "$install_bundle" ]]; then
    mv "$backup_bundle" "$install_bundle"
  fi
  print -u2 "InstallApp: FAIL — atomic bundle replacement failed."
  exit 1
fi

codesign --verify --deep --strict "$install_bundle"
test -s "$install_bundle/Contents/Resources/AppIcon.icns"
[[ "$(plutil -extract CFBundleIconFile raw -o - "$install_bundle/Contents/Info.plist")" == "AppIcon.icns" ]]
[[ "$(plutil -extract CFBundleDisplayName raw -o - "$install_bundle/Contents/Info.plist")" == "Copper" ]]

if [[ -x "$lsregister" ]]; then
  "$lsregister" -f "$install_bundle" >/dev/null
  registration_dump="$("$lsregister" -dump 2>/dev/null || true)"
  if [[ "$registration_dump" != *"$install_bundle"* ]]; then
    print -u2 "InstallApp: FAIL — Launch Services did not register $install_bundle."
    exit 1
  fi
else
  print -u2 "InstallApp: FAIL — Launch Services registration tool is unavailable."
  exit 1
fi

if [[ "$old_bundle_moved" == true ]]; then
  print "InstallApp: previous installation moved to $backup_bundle"
fi
print "InstallApp: installed and validated $install_bundle"
open "$install_bundle"
