#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
app_bundle="$repo_root/.build/Copper.app"
app_executable="$app_bundle/Contents/MacOS/Copper"
diagnostic_file="$(mktemp /tmp/copper-accessibility.XXXXXX)"

cleanup() {
  case "$diagnostic_file" in
    /tmp/copper-accessibility.*) rm -f "$diagnostic_file" ;;
  esac
}
trap cleanup EXIT

cd "$repo_root"

"$repo_root/Scripts/BuildApp.sh" >/dev/null

existing_pids="$(pgrep -f "^${app_executable}( |$)" || true)"
if [[ -n "$existing_pids" ]]; then
  print -u2 "AccessibilityTrustDiagnostic: REFUSED — Copper is already running (${(j:, :)${(@f)existing_pids}})"
  exit 1
fi

open -n -W "$app_bundle" --args \
  --background-ui-test \
  "--accessibility-diagnostic-output=$diagnostic_file" \
  --accessibility-diagnostic-exit

plutil -p "$diagnostic_file"

is_trusted="$(plutil -extract isTrusted raw -o - "$diagnostic_file")"
if [[ "$is_trusted" != "true" ]]; then
  print -u2 "AccessibilityTrustDiagnostic: FAIL — the running Copper bundle is not trusted by macOS TCC"
  exit 1
fi

keyboard_monitors_installed="$(plutil -extract keyboardMonitorsInstalled raw -o - "$diagnostic_file")"
if [[ "$keyboard_monitors_installed" != "false" ]]; then
  print -u2 "AccessibilityTrustDiagnostic: FAIL — background UI-test mode installed a keyboard monitor"
  exit 1
fi

print "AccessibilityTrustDiagnostic: PASS — exact bundle is trusted and background mode installed no keyboard monitors"
