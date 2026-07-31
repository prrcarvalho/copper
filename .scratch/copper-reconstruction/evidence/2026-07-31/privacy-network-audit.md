# Privacy and network audit — 2026-07-31

## Scope

- Exact bundle: `.build/Copper.app`, rebuilt from the working tree based on
  commit `d2e0908`.
- Objective: check for native-app analytics, telemetry, crash uploads, sync,
  update traffic, or note-content network traffic.
- This is implementation evidence for the reconstructed app, not a claim about
  hidden behaviour in the official Copper product.

## Static evidence

- A source scan for `URLSession`, `URLRequest`, `NWConnection`,
  `Network.framework`, `CFNetwork`, WebSocket clients, analytics SDKs,
  telemetry SDKs, crash uploaders, sync, and upload call sites found no network
  implementation. Matches for analytics, upload, and sync in app source are
  user-facing privacy text in `SettingsView`.
- `otool -L .build/Copper.app/Contents/MacOS/Copper` lists AppKit,
  ApplicationServices, Combine, CoreFoundation, CoreGraphics, Foundation,
  SwiftUI, Symbols, and Swift runtime/system libraries. It does not list
  `Network.framework` or `CFNetwork.framework`.
- `nm -u` found no imported `URLSession`, `CFNetwork`, `NWConnection`,
  `NSURLRequest`, WebSocket, upload-task, or data-task symbol.
- `/usr/bin/strings` found no embedded `http://`, `https://`, `ws://`, or
  `wss://` URL in the app executable.
- `codesign -d --entitlements - .build/Copper.app` reported no entitlement
  payload.

## Runtime socket evidence

The exact bundle was started only through `Scripts/LaunchBackgroundUITest.sh`
with an isolated temporary store. Process cardinality was checked before,
during, and after the scenario:

```text
pre_count=0
LaunchBackgroundUITest: PASS — exactly one background-test PID 35409.
process_count_during=1
open_inet_socket_rows=0
StopBackgroundUITest: PASS — stopped PID 35409.
post_count=0
```

While PID `35409` was alive, the following command returned no TCP or UDP
socket rows:

```bash
lsof -nP -a -p 35409 -i
```

## Result and limitation

**PASS for the reconstructed app.** Source, binary imports/strings,
entitlements, and a controlled runtime socket observation all agree that the
app has no implemented network, analytics, telemetry, crash-upload, sync, or
note-content upload path. The runtime observation is a finite scenario, so it
is corroborating evidence rather than a universal proof about every possible
future execution.
