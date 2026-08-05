# Copper Reconstruction privacy boundary

This document applies to the native personal reconstruction in this repository.

## Native app

- Notes and preferences are stored in the local JSON file under
  `~/Library/Application Support/Copper-Reconstruction/`.
- The app has no account, cloud sync, licensing/update service, analytics SDK,
  telemetry, crash-report upload, note-content upload, or network client.
- macOS Accessibility is used first to read the current selection after the
  user grants access. Editors that do not expose a selection through AX use a
  narrow fallback that posts a transient Command-C to the still-frontmost
  source app and restores the previous pasteboard contents immediately. The
  configured Shift gesture is observed by one AppKit global monitor, which
  cannot consume or replace that originating event; Copper installs no local
  event monitor.
- Because a global monitor cannot prevent the source app from handling the same
  key, custom capture shortcuts require Command plus another modifier.
  Control-Option combinations are rejected as the VoiceOver modifier. This
  reduces source-input interference but cannot prove that a shortcut is unused
  by every third-party application.
- Clipboard writes are local `NSPasteboard` operations initiated by Copy, Copy
  as List, or the transient inaccessible-editor capture fallback. The fallback
  restores the user's previous pasteboard contents before completing capture.
- The explicit `--capture-diagnostic-output` and
  `--live-capture-diagnostic-output` test routes write the selected test fixture
  and capture/cardinality metadata to a caller-supplied local path. They are
  opt-in command-line diagnostics used only with controlled fixtures; normal
  production launches do not enable them and do not log note content.
- Production's regular activation policy, Dock icon and local frame autosave do
  not add a network or analytics boundary. The supplied icon is copied into the
  local bundle, and `Scripts/InstallApp.sh` only builds, signs, registers and
  opens that local bundle; it does not contact a Copper service.

## Official website distinction

The supplied product analysis notes that the official Copper website may use
Vercel Analytics for page-view measurement. That website policy is separate
from this native app. No Vercel Analytics dependency or website telemetry is
included in this repository.

## Scope and evidence

The claims above describe the current source and package, not a claim about
Copper's private implementation. They were checked against source, linked
frameworks, imported symbols, executable strings, code-signing entitlements and
a controlled runtime socket observation. The retained report is
[`privacy-network-audit.md`](../.scratch/copper-reconstruction/evidence/2026-07-31/privacy-network-audit.md).
Runtime cross-app capture remains subject to macOS TCC and is tracked in
[`ux-verification.md`](ux-verification.md).
