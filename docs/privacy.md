# Copper Reconstruction privacy boundary

This document applies to the native personal reconstruction in this repository.

## Native app

- Notes and preferences are stored in the local JSON file under
  `~/Library/Application Support/Copper-Reconstruction/`.
- The app has no account, cloud sync, licensing/update service, analytics SDK,
  telemetry, crash-report upload, note-content upload, or network client.
- macOS Accessibility is used only to read the current selection after the user
  grants access. The configured capture gesture is observed by one AppKit
  global monitor, which cannot consume or replace events. The app installs no
  local event monitor and never synthesises or reposts keyboard input.
- Because a global monitor cannot prevent the source app from handling the same
  key, custom capture shortcuts require Command plus another modifier.
  Control-Option combinations are rejected as the VoiceOver modifier. This
  reduces source-input interference but cannot prove that a shortcut is unused
  by every third-party application.
- Clipboard writes are local `NSPasteboard` operations initiated by Copy or
  Copy as List. Capturing a selection does not write to the clipboard.
- The explicit `--capture-diagnostic-output` and
  `--live-capture-diagnostic-output` test routes write the selected test fixture
  and capture/cardinality metadata to a caller-supplied local path. They are
  opt-in command-line diagnostics used only with controlled fixtures; normal
  production launches do not enable them and do not log note content.

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
