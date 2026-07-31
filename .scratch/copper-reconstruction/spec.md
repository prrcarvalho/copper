# Copper native reconstruction

Status: implemented with explicit runtime and parity limitations

## Objective

Reconstruct the observable Copper macOS workflow for private personal use as a
native SwiftUI/AppKit app. Treat `docs/product-spec.md` and the retained official
frames as product evidence; do not claim access to the original source or exact
hidden behaviour.

## Product requirements

- Keep production as a nonactivating floating `NSPanel` across Spaces. The
  concrete `CopperPanel` may become key for focused controls without becoming
  the main window or activating the app.
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
- Production retains the floating panel and one observational global capture
  monitor. In-app shortcuts use native menu/key handlers; no local event
  monitor consumes or replaces their events.
- Custom global shortcuts require Command plus another modifier;
  Control-Option is rejected as the VoiceOver modifier. Since the monitor is
  observational, no implementation can guarantee that an accepted combination
  is unused by every source application.
- No test route posts or re-emits keyboard events.

## Acceptance and evidence

- `Scripts/BuildApp.sh`, `swift build`, release build and signature validation
  must pass.
- `swift test` must discover and execute the formal suite, not merely compile a
  test target. The current suite discovers and executes 18 cases.
- Runtime evidence and its limits are recorded only in
  `docs/ux-verification.md`.
- Real rich-text selections have controlled runtime evidence in TextEdit,
  Safari and Chrome. Every current capture report records one note, one capture
  toast, an unchanged clipboard, a preserved source selection, an inactive
  Copper app and zero keyboard monitors in the background route. The plain AX
  fallback is model-tested but still needs a current Electron/plain-selection
  runtime repetition.
- Selection-relative toast placement was repeated after the AX-bounds fix in
  TextEdit, Safari and Chrome. The authorised foreground block proved the
  default and safe custom physical gestures, Settings validation/reset,
  production Composer and card-key routing, focused `Command-C` and
  `Shift-Command-C`, a persisted custom in-app Copy shortcut (including native
  text-field copy before and after customisation), Tab order, the core
  action flows, relaunch persistence and a real full-screen Space. Spoken
  VoiceOver and an actual cross-Space transition were requested but not
  physically confirmed.
  A current isolated Electron/plain-only runtime repetition also remains
  unavailable because Computer Use resolves the user's existing VS Code process
  for the shared bundle identifier.
- Visual matching is an evidence-based approximation, not a claim of pixel- or
  hidden-behaviour parity.
