#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
app_bundle="$repo_root/.build/Copper.app"
app_executable="$app_bundle/Contents/MacOS/Copper"
pid_file="$repo_root/.build/CopperBackgroundUITest.pid"

find_test_pids() {
  pgrep -f "^${app_executable}( |$)" || true
}

typeset -a existing_pids
existing_output="$(find_test_pids)"
if [[ -n "$existing_output" ]]; then
  existing_pids=("${(@f)existing_output}")
else
  existing_pids=()
fi
if (( ${#existing_pids} > 0 )); then
  print -u2 "LaunchBackgroundUITest: REFUSED — Copper is already running (${(j:, :)existing_pids})"
  print -u2 "Stop that exact test instance with Scripts/StopBackgroundUITest.sh before relaunching."
  exit 1
fi

"$repo_root/Scripts/BuildApp.sh"
open -n "$app_bundle" --args --background-ui-test "$@"

typeset -a launched_pids
for attempt in {1..50}; do
  launched_output="$(find_test_pids)"
  if [[ -n "$launched_output" ]]; then
    launched_pids=("${(@f)launched_output}")
  else
    launched_pids=()
  fi
  (( ${#launched_pids} == 1 )) && break
  sleep 0.1
done

if (( ${#launched_pids} != 1 )); then
  print -u2 "LaunchBackgroundUITest: FAIL — expected exactly one Copper process, found ${#launched_pids}."
  for pid in "${launched_pids[@]}"; do
    [[ "$pid" == <-> ]] && kill -TERM "$pid" 2>/dev/null || true
  done
  exit 1
fi

print -r -- "${launched_pids[1]}" > "$pid_file"
print "LaunchBackgroundUITest: PASS — exactly one background-test PID ${launched_pids[1]}."
print "Stop it with: $repo_root/Scripts/StopBackgroundUITest.sh"
