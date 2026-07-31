# Copper Reconstruction privacy boundary

This document applies to the native personal reconstruction in this repository.

## Native app

- Notes and preferences are stored in the local JSON file under
  `~/Library/Application Support/Copper-Reconstruction/`.
- The app has no account, cloud sync, licensing/update service, analytics SDK,
  telemetry, crash-report upload, note-content upload, or network client.
- macOS Accessibility is used only to read the current selection and listen for
  the configured capture gesture after the user grants access.
- Clipboard writes are local `NSPasteboard` operations.

## Official website distinction

The supplied product analysis notes that the official Copper website may use
Vercel Analytics for page-view measurement. That website policy is separate
from this native app. No Vercel Analytics dependency or website telemetry is
included in this repository.

## Scope and evidence

The claims above describe the current source and package, not a claim about
Copper's private implementation. Runtime cross-app capture remains subject to
macOS TCC and is tracked in [`ux-verification.md`](ux-verification.md).
