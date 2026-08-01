# Copper native reconstruction

Status: implemented and polished with explicit runtime and parity limitations

## Objective

Reconstruct the observable Copper macOS workflow for private personal use as a
native SwiftUI/AppKit app. Treat `docs/product-spec.md` and the retained official
frames as product evidence; do not claim access to the original source or exact
hidden behaviour.

## Product requirements

- Keep production as a regular, normal-level `CopperPanel`. It may be ordered
  in front by a capture/show action without activating Copper, but clicking
  the window, selecting Copper from the Dock, or using Command-Tab activates
  and focuses it normally; switching to another app moves focus away.
- Use a regular production activation policy so the personal app has a Dock
  icon and participates in Command-Tab, while background UI-test launches set
  the policy to accessory and use a normal-level `NSWindow`.
- Give the production panel a native titled/resizable/closable/miniaturizable
  shell with hidden traffic lights, a `320×420` minimum, a `430×760` first-run
  size, a `620` maximum width and visible-screen frame clamping. Restore the
  saved frame when possible; this is a usability improvement and not a claim
  about the original Copper's hidden window implementation.
- Capture selected text into the active section with a configurable, globally
  safe shortcut and a nonactivating toast near the source selection.
- Preserve supported attributed formatting as Markdown, with a plain-text
  fallback for unsupported Accessibility values.
- Support search, sections, multi-selection, deterministic copy/list output,
  reversible completion, merge, move, full-prompt popup editing and a distinct
  edit window. A double-click or Return on a selected card opens the popup;
  Command-Return keeps the distinct edit window.
- Escape closes an open prompt popup and clears explicit task selection and
  card focus in the same step, without treating text editor focus as task
  selection. Command-Delete deletes selected tasks;
  Command-Z and Command-Shift-Z undo/redo reversible store mutations.
- Keep the composer visually consistent with note cards, including its leading
  circular control.
- Persist notes and preferences locally, with no account, sync, telemetry,
  crash upload or note-content network traffic.
- Expose meaningful accessibility semantics and respect Reduce Motion,
  increased contrast, non-colour differentiation and accessibility text sizes.

## Test-safety requirements

- Every automated UI launch uses `Scripts/LaunchBackgroundUITest.sh`, which
  selects `--background-ui-test`, enforces one Copper process and records its
  PID for `Scripts/StopBackgroundUITest.sh`.
- Background mode uses a normal-level `NSWindow`, no all-Spaces/full-screen
  collection behaviour, no source-app activation, no Accessibility prompt and
  no global or local keyboard monitor.
- Production retains one normal-level activatable panel and one observational
  global capture monitor. In-app shortcuts use native menu/key handlers; no
  local event monitor consumes or replaces their events. The panel can move
  only through its narrow header drag strip, not by dragging arbitrary
  background content.
- Custom global shortcuts require Command plus another modifier;
  Control-Option is rejected as the VoiceOver modifier. Since the monitor is
  observational, no implementation can guarantee that an accepted combination
  is unused by every source application.
- No test route posts or re-emits keyboard events.
- Build the supplied `Resources/AppIcon-source.png` into a deterministic native
  `.icns` resource and expose it through the bundle metadata. Installation to
  `/Applications/Copper.app` is local-only and keeps an older bundle in Trash.

## Acceptance and evidence

- `Scripts/BuildApp.sh`, `swift build`, release build and signature validation
  must pass.
- `swift test` must discover and execute the formal suite, not merely compile a
  test target. The current suite discovers and executes 28 cases, including
  native panel style, geometry and close contracts.
- Runtime evidence and its limits are recorded only in
  `docs/ux-verification.md`.
- Real rich-text selections have controlled runtime evidence in TextEdit,
  Safari, Chrome and a real VS Code Electron editor. Every current capture report records one note, one capture
  toast, an unchanged clipboard, a preserved source selection, an inactive
  Copper app and zero keyboard monitors in the background route. The plain AX
  fallback remains model-tested; the Electron runtime now confirms the plain
  source path when AX exposes no formatting traits.
- Selection-relative toast placement was repeated after the AX-bounds fix in
  TextEdit, Safari and Chrome. The authorised foreground block proved the
  default and safe custom physical gestures, Settings validation/reset,
  production Composer and card-key routing, focused `Command-C` and
  `Shift-Command-C`, a persisted custom in-app Copy shortcut (including native
  text-field copy before and after customisation), Tab order, the core
  action flows, relaunch persistence, a real full-screen Space, physical panel
  dragging and multi-monitor movement. One physical `Control-Right` transition
  was completed and the production panel remained visible and AX-addressable in
  the new Space.
  The current Electron run used a real Untitled editor in the existing VS Code
  process; no user document was touched.
- Visual matching is an evidence-based approximation, not a claim of pixel- or
  hidden-behaviour parity.
