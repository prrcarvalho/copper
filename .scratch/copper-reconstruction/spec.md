# Copper native reconstruction

Status: implemented with explicit runtime and parity limitations

## Objective

Reconstruct the observable Copper macOS workflow for private personal use as a
native SwiftUI/AppKit app. Treat `docs/product-spec.md` and the retained official
frames as product evidence; do not claim access to the original source or exact
hidden behaviour.

## Product requirements

- Keep production as a nonactivating floating `NSPanel` across Spaces.
- Capture selected text into the active section with a configurable, globally
  safe shortcut and a nonactivating toast near the source selection.
- Preserve supported attributed formatting as Markdown, with a plain-text
  fallback for unsupported Accessibility values.
- Support search, sections, multi-selection, deterministic copy/list output,
  reversible completion, merge, move, inline edit, Expand and a distinct edit
  window.
- Keep the composer visually consistent with note cards, including its leading
  circular control.
- Persist notes and preferences locally, with no account, sync, telemetry,
  crash upload or note-content network traffic.
- Expose meaningful keyboard and VoiceOver semantics and respect Reduce Motion,
  increased contrast, non-colour differentiation and accessibility text sizes.

## Test-safety requirements

- Every automated UI launch uses `Scripts/LaunchBackgroundUITest.sh`, which
  selects `--background-ui-test`, enforces one Copper process and records its
  PID for `Scripts/StopBackgroundUITest.sh`.
- Background mode uses a normal-level `NSWindow`, no all-Spaces/full-screen
  collection behaviour, no source-app activation, no Accessibility prompt and
  no global or local keyboard monitor.
- Production retains the floating panel and global capture monitor.
- No test route posts or re-emits keyboard events.

## Acceptance and evidence

- `Scripts/BuildApp.sh`, `swift build`, release build and signature validation
  must pass.
- `swift test` must discover and execute the formal suite, not merely compile a
  test target.
- Runtime evidence and its limits are recorded only in
  `docs/ux-verification.md`.
- Plain selections have controlled runtime evidence in TextEdit, Safari,
  Chrome and an isolated Electron app. Styled cross-app conversion is covered
  by the attributed-string model test but remains a runtime limitation until a
  non-disruptive real styled selection can be repeated.
- Spoken VoiceOver, end-to-end focused keyboard navigation, exact
  selection-relative toast placement after the latest bounds change and live
  production full-screen/Space behaviour remain explicit limitations while the
  user is working on the Mac.
- Visual matching is an evidence-based approximation, not a claim of pixel- or
  hidden-behaviour parity.
