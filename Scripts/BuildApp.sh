#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
app_bundle="$repo_root/.build/Copper.app"
bundle_identifier="com.pedrocarvalho.copper-reconstruction"
designated_requirement='=designated => identifier "com.pedrocarvalho.copper-reconstruction"'

cd "$repo_root"

swift build
binary_path="$(swift build --show-bin-path)/Copper"

mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$binary_path" "$app_bundle/Contents/MacOS/Copper"
cp "$repo_root/Resources/Info.plist" "$app_bundle/Contents/Info.plist"

# A plain ad-hoc signature defaults its Designated Requirement to the binary's
# CDHash. That makes macOS TCC treat every rebuild as a different application.
# Pin a local-development requirement to the bundle identifier so the personal
# build keeps one Accessibility identity across rebuilds.
codesign --force --deep --sign - \
  --identifier "$bundle_identifier" \
  --requirements "$designated_requirement" \
  "$app_bundle"

codesign --verify --deep --strict "$app_bundle"
print "$app_bundle"
