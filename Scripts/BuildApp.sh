#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
app_bundle="$repo_root/.build/Copper.app"
bundle_identifier="com.pedrocarvalho.copper-reconstruction"
designated_requirement='=designated => identifier "com.pedrocarvalho.copper-reconstruction"'
icon_master="$repo_root/.build/AppIcon-master.png"
iconset="$repo_root/.build/AppIcon.iconset"
icon_file="$repo_root/.build/AppIcon.icns"

cd "$repo_root"

swift build
binary_path="$(swift build --show-bin-path)/Copper"

# Keep the supplied artwork as the source of truth and derive the complete
# native icon set deterministically before the bundle is signed.
swift "$repo_root/Scripts/GenerateAppIcon.swift" \
  "$repo_root/Resources/AppIcon-source.png" \
  "$icon_master" >/dev/null
rm -rf "$iconset"
mkdir -p "$iconset"
for spec in \
  "16:icon_16x16.png" \
  "32:icon_16x16@2x.png" \
  "32:icon_32x32.png" \
  "64:icon_32x32@2x.png" \
  "128:icon_128x128.png" \
  "256:icon_128x128@2x.png" \
  "256:icon_256x256.png" \
  "512:icon_256x256@2x.png" \
  "512:icon_512x512.png" \
  "1024:icon_512x512@2x.png"; do
  size="${spec%%:*}"
  name="${spec#*:}"
  sips -z "$size" "$size" "$icon_master" --out "$iconset/$name" >/dev/null
done
iconutil -c icns "$iconset" -o "$icon_file"

mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"
cp "$binary_path" "$app_bundle/Contents/MacOS/Copper"
cp "$repo_root/Resources/Info.plist" "$app_bundle/Contents/Info.plist"
cp "$icon_file" "$app_bundle/Contents/Resources/AppIcon.icns"

# A plain ad-hoc signature defaults its Designated Requirement to the binary's
# CDHash. That makes macOS TCC treat every rebuild as a different application.
# Pin a local-development requirement to the bundle identifier so the personal
# build keeps one Accessibility identity across rebuilds.
codesign --force --deep --sign - \
  --identifier "$bundle_identifier" \
  --requirements "$designated_requirement" \
  "$app_bundle"

codesign --verify --deep --strict "$app_bundle"
test -s "$app_bundle/Contents/Resources/AppIcon.icns"
print "$app_bundle"
