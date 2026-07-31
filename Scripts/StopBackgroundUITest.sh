#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
app_executable="$repo_root/.build/Copper.app/Contents/MacOS/Copper"
pid_file="$repo_root/.build/CopperBackgroundUITest.pid"

if [[ ! -f "$pid_file" ]]; then
  print "StopBackgroundUITest: no recorded background test instance."
  exit 0
fi

pid="$(<"$pid_file")"
if [[ "$pid" != <-> ]]; then
  print -u2 "StopBackgroundUITest: REFUSED — invalid PID file."
  exit 1
fi

command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
if [[ -z "$command" ]]; then
  rm -f -- "$pid_file"
  print "StopBackgroundUITest: recorded process is no longer running."
  exit 0
fi

if [[ "$command" != "$app_executable"* ]]; then
  print -u2 "StopBackgroundUITest: REFUSED — PID $pid is not the recorded Copper executable."
  exit 1
fi

kill -TERM "$pid"
for attempt in {1..50}; do
  kill -0 "$pid" 2>/dev/null || break
  sleep 0.1
done

if kill -0 "$pid" 2>/dev/null; then
  print -u2 "StopBackgroundUITest: FAIL — PID $pid did not terminate."
  exit 1
fi

rm -f -- "$pid_file"
print "StopBackgroundUITest: PASS — stopped PID $pid."
