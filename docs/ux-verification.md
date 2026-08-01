# Copper Reconstruction — UX Verification

Date: 2026-08-01

This matrix records evidence for the reconstruction against
[`docs/product-spec.md`](product-spec.md) and the supplied frames under
`docs/copper-official/`. It deliberately separates implementation evidence
from behaviour that needs a real cross-application run. The public reference
does not provide enough information to claim pixel- or behaviour-level
one-to-one parity for every internal detail.

## Build and formal model validation

```text
Scripts/BuildApp.sh                                      PASS
Scripts/InstallApp.sh                                    PASS (bundle installed and validated at /Applications/Copper.app)
swift build                                              PASS
swift build -c release                                   PASS
swift test                                                PASS (28 tests executed)
swift test list                                           PASS (28 tests discovered)
swiftc -parse-as-library Sources/CopperCore/Models.swift \
  Scripts/CopperSmoke.swift -o .build/CopperSmoke && \
  .build/CopperSmoke                                        PASS
codesign --verify --deep --strict .build/Copper.app       PASS
Scripts/AccessibilityTrustDiagnostic.sh                  PASS (exact bundle; trusted; zero background monitors)
zsh -n Scripts/*.sh                                      PASS
git diff --check                                          PASS
```

The formal cases cover active-section routing and persistence, successive
composer-equivalent inserts and search, reversible completion including the
focused-card Space endpoint, capture-shortcut syntax/safety/conflict/reset and
matching updates, deterministic copy/list/merge/move order, list completion and
toast state only after a successful pasteboard write, full-prompt popup and
new-window state, attributed AX text conversion and literal plain fallback,
exactly-one capture ingestion, double-Shift
deduplication, conflicting-modifier rejection, rejection of source-destructive
custom combinations, the no-repost invariant, and the production panel's
normal-level activation/lifecycle contract. The added cases cover explicit
Escape selection/focus cleanup, text-responder routing for Delete/Undo/Redo,
multi-note deletion cleanup, persisted undo/redo restoration, redo
invalidation, and the background/production window policy values.

## Production companion shell polish

The previous 2026-07-31 signed-bundle diagnostic recorded the old floating,
nonactivating configuration; that report is historical and is superseded by
this task's normal-window contract. The current source/formal contract is:
`activationPolicy=0` (regular), `windowClass=CopperPanel`, no
`.nonactivatingPanel`, normal level, empty collection behaviour,
`isFloatingPanel=false`, hidden close/miniaturize/zoom buttons,
`isMovable=true`, `isMovableByWindowBackground=false`, `isResizable=true`,
autosave name `CopperCompanionPanel`, `320×420` minimum, `620` maximum width,
and the existing visible-screen geometry limits. The formal geometry case
covers the first-launch centered `430×760` frame. The drag strip remains an
AppKit `CopperDragStripView`, and only that narrow header strip moves the
window.

The normal AppKit lifecycle is intentionally left in place: the closable and
miniaturizable style mask routes `⌘W` through `performClose` and `⌘M` through
the native miniaturize action, while no Copper command claims `⌘Q`, so quit
remains the standard application command. The regular activation policy gives
the app Dock/Command-Tab identity. These contracts were verified by formal
source/model tests; no new foreground physical-key run was performed.

The native edge-resize path is present and the panel's minimum/maximum limits
are enforced in the exact-bundle diagnostic. A real user pointer drag has since
confirmed that the dedicated AppKit drag strip moves the panel and that the
saved frame is restored afterwards.

## Background Computer Use mode

Every non-production Copper UI launch used for this task uses:

```bash
Scripts/LaunchBackgroundUITest.sh
Scripts/StopBackgroundUITest.sh
```

The debug branch creates a standard `NSWindow` at `NSWindow.Level.normal`,
with an empty `collectionBehavior`, and calls `orderFront(nil)` followed by
`NSApp.deactivate()`. It does not call `orderFrontRegardless()`, join all
Spaces, or join full-screen Spaces. Production now also uses a normal-level
`CopperPanel`, empty collection behaviour, and `orderFront(nil)`; a show/order
operation therefore does not force Copper above the frontmost application.
Current background reports show the test window inactive and non-key, and
current capture reports show the same frontmost application before and after
capture; the source-level invariant is also checked in the final diff.

Background UI-test launches install no global or local keyboard monitor. This is
the strongest non-interference guard for Computer Use: the test window remains
inspectable, but it cannot observe, consume or re-emit keys from another app.
Production keeps one configurable observational global monitor: default
double-Shift registers only `flagsChanged`, while a configured key shortcut
registers only `keyDown`. AppKit global monitors cannot consume or replace an
event. The previous local event monitor, which returned `nil` for handled Copper
shortcuts, was removed; native menu/key handlers now own in-app shortcuts.
Registration is idempotent, termination removes the global monitor, and no code
posts a replacement event. Formal cases reject modified double-Shift gestures
and deduplicate repeated matching events.

Foreground observation exposed why an arbitrary modifier is not sufficient:
`Control-Option-C` reached TextEdit, replaced the selected fixture and left no
selection for Copper. That negative run is retained. Settings now rejects the
Control-Option VoiceOver modifier and requires Command plus at least one other
modifier. This reduces source-input interference; it cannot prove a shortcut is
unused by every third-party app.

Cross-application capture checks use a test-only route rather than synthesising
the production shortcut:

```bash
Scripts/LaunchBackgroundUITest.sh \
  --capture-on-launch \
  --capture-application-bundle-id=com.google.Chrome \
  --store-path=/tmp/copper-runtime/notes.json \
  --capture-diagnostic-output=/tmp/copper-runtime/capture.json
Scripts/StopBackgroundUITest.sh
```

Before each run the process list is checked, exactly one Copper PID is allowed,
and that PID is terminated afterwards. The diagnostic route calls the same AX
selection, Markdown conversion, active-section insertion and toast code as the
production callback, but never installs a keyboard monitor, activates the
source app or asks macOS to foreground an Accessibility permission prompt. The
selection must already be exposed by the source app's AX tree; otherwise the
report records that limitation.

## Selection, keyboard history, and current lifecycle contract

The store now owns a reversible transaction seam for persistent mutations. It
records exact section/note/preference/active-section snapshots and the
selection context needed by deletion undo; restored and reapplied snapshots
are written to the same JSON file with original IDs and sort order. Focus,
`expandedID` and toast state are not history entries. The current coverage
includes add/update/delete, completion, merge, move, capture, active section,
and successful list-copy completion mutations; direct preference field edits
followed only by `save()` remain outside history.

`Escape` closes the prompt popup and clears `selectedIDs` and the separate
`focusedCardID` in one step, including the combined text-editor route, while
the native text responder may still receive `cancelOperation`. Plain Delete is
not a Copper command. Command-Delete routes to task deletion only outside text
editing; with an `NSTextView`/`NSTextField` first responder it remains on the
native `deleteToBeginningOfLine:` path.
Command-Z and Command-Shift-Z route to the store only outside text editing and
to the native text responder otherwise. No physical keys, local/global event
reposting, or foreground UI run was used for these new checks.

## Acceptance matrix

| Area | Current evidence | Status |
| --- | --- | --- |
| Active section routes composer and capture notes | Formal persistence/routing case; every controlled capture wrote one note to the active section | **PASS (model/runtime diagnostic)** |
| Search, sections and successive composer notes | Foreground Search filtered to the TOML card; a section was created by its native sheet and became active; the fixed key-capable production panel accepted Composer text + Return and created one note | **PASS (foreground runtime)** |
| Space and Command-Space | A focused production card changed to selected/completed with Space; Command-Space deselected it without changing completion and selected it again | **PASS (foreground runtime)** |
| Escape, deletion, undo, and redo | Deterministic formal cases clear explicit selection/card focus, preserve text-editor routing, delete multiple notes with cleanup, persist exact-ID undo/redo, and invalidate redo after a divergent store mutation | **PASS (formal model; no new foreground key run)** |
| Capture shortcut, conflict validation and reset | Settings rejected an unmodified key, a Copper conflict and Control-Option; Reset restored double Shift; physical default and `Command-Control-Shift-C` gestures both captured successfully | **PASS for the two controlled production gestures; unknown third-party shortcut conflicts remain possible** |
| Rich conversion and plain fallback | Real TextEdit bold/italic, Safari marker-attributed bold and Chrome AX bold converted to Markdown; real VS Code Electron plain selection captured through the supported AX path; plain fallback also passes formally | **PASS for supported rich/plain runtime paths; fallback when AX exposes no attributed text remains formal-only** |
| Capture cardinality, selection, clipboard and Copper activation | Background TextEdit/Safari/Chrome plus physical production default/custom TextEdit runs record one note and toast per gesture, preserved selection/clipboard, inactive Copper and unchanged active source app | **PASS (background and production runtime)** |
| Capture toast position/nonactivation | TextEdit, Safari and fixed Chrome reports contain non-empty selection bounds; the 128 × 38 toast starts 12 points below the selection in top-left screen coordinates, is visible and never key | **PASS (background diagnostic route)** |
| Copy, Copy as List, completion, Merge and Move | In the final exact bundle, focused `Command-C` copied one selected card without completing it and exposed one `Copied` toast; focused `Shift-Command-C` emitted two notes in visual order as a numbered list, completed both and exposed one `Copied as List` toast. Settings then persisted custom Copy `Command-Shift-K`, which copied once; real Search-field selections still used native `Command-C` before and after customisation. Merge and Move also ran in the visible UI | **PASS (foreground runtime)** |
| Prompt popup and Edit in New Window | The 2026-08-01 background Computer Use run opened the full prompt with double-click and Return; the popup exposed a scrollable text editor, Save, Cancel and Close. Escape closed it and returned to the panel without the selection. Command-Return remains covered by the model/key-routing contract; no new foreground run was made after this integration | **PASS (background popup run; Command-Return formal/source)** |
| Composer and core visual hierarchy | The 2026-08-01 background run showed a compact short composer with no visible scrollbar; a multiline value grew naturally and exposed a scrollbar only after overflow. Search, headers, cards, circles, spacing and the card-like composer remain an evidence-based visual approximation | **PASS for observed composer states; approximation for exact pixels** |
| Accessibility variants and semantics | Forced modes cover Reduce Motion, Differentiate Without Color, Increased Contrast and accessibility scale; AX exposes one labelled/value/action element per card; complete Tab routing is observed | **PASS (rendered/AX/keyboard)** |
| Privacy/network | Source/binary/entitlements audit plus a controlled zero-socket run; docs distinguish native app from website analytics | **PASS for current reconstruction** |
| TextEdit runtime | Real selection captured `Copper **Rich Bold** and *italic* fallback fixture 2026-07-31` | **PASS (rich diagnostic route)** |
| Safari runtime | Real `Example Domain` selection captured as `**Example Domain**` through `attributedTextMarker` | **PASS (rich diagnostic route)** |
| Chrome runtime | Temporary `example.com` tab exposed `attributedRange`; after AX font/bounds fixes it captured `**Example Domain**` with real selection bounds | **PASS (rich diagnostic route)** |
| Electron/plain runtime | Real VS Code Electron Untitled editor selection captured exactly one plain note and one `Captured` toast; clipboard and selection were preserved, Copper stayed inactive/non-key and background monitors were zero | **PASS (runtime); no-AX-attributed-text branch remains formal-only** |
| Spaces/full-screen/multiple monitors | The prior floating build was observed across Spaces and displays; the current accepted normal-level window intentionally has empty collection behaviour and has not been foreground re-run for Space parity | **NOT RE-RUN after lifecycle change** |
| Production shell, lifecycle and install | Formal/source contracts prove regular activation policy, normal level, activatable `CopperPanel`, native closable/miniaturizable mask, hidden traffic lights, empty collection behaviour, `⌘W`/`⌘M` native affordances, no Copper `⌘Q` override, normal `orderFront(nil)`, and narrow-strip-only dragging. Prior install/signature evidence remains historical | **PASS (formal/source; foreground lifecycle not re-run)** |
| Visual one-to-one parity | Supplied frames support an approximation of hierarchy, not hidden/internal behaviour | **APPROXIMATION** |

## Visual comparison register

The 47 supplied 1 FPS frames and contact sheet were inspected before code
changes. The current `background-main-current.jpeg` was then compared directly
with the complete sheet and at original resolution with representative frames,
including frame 030 for cards/composer and frames 037–043 for selection,
context-menu, completion and toast states.

| Observable | Current comparison | Classification |
| --- | --- | --- |
| Panel proportions/corners/shadow | The production foreground image shows the 430 × 760 borderless panel, 28-point logical outer radius and AppKit shadow. | **Observed approximation** |
| Material/colour | Cool translucent hierarchy is present, but compressed video, desktop wallpaper and colour management prevent canonical token extraction. | **Approximation** |
| Search/options/section headers | Current screenshot reproduces the search pill, circular ellipsis control, uppercase tracked headers and divider rules. | **Observed approximation** |
| Cards/circular controls/Markdown | Current screenshot shows white rounded cards, leading circles and bold/italic preview. Type/line wrapping varies with macOS scaling. | **Observed approximation** |
| Composer | The short-state screenshot shows the leading empty circle and compact card-like field without a visible scrollbar; the overflow screenshot shows the field growing with an automatic vertical scrollbar. | **Observed runtime approximation** |
| Scroll behaviour/indicators | The public evidence does not establish inertia, virtualisation or persistent indicator rules; the main reconstruction hides persistent indicators. | **Unknown exact behaviour** |
| Selected/completed cards | Foreground multi-selection showed two blue outlines; Copy as List then showed blue checks and strikethrough. | **Observed approximation** |
| Context menu | The current source exposes Copy, Copy as List, Mark as Done, Open, Edit in New Window, Merge Notes and Move to; the new background AX tree exposed Open and Edit in New Window on each card. | **Observed action inventory; exact visual parity unknown** |
| Capture toast | Current TextEdit/Safari/Chrome reports plus live Computer Use observation show the dark non-key capsule next to the real selection. | **PASS as observed approximation** |
| Copy toast | The foreground Copy as List screenshot and AX tree show the light `Copied as List` toast exactly once. | **Observed approximation** |
| Settings | Unsafe/conflict/reset/custom flows were exercised in the native sheet; the public frames do not expose an exact reference design. | **Runtime PASS; visual parity unknown from public evidence** |

## Runtime evidence and remaining routes

TextEdit, Safari and Chrome were exercised through the test-only capture route
above. It proves the same downstream AX/conversion/store/toast path without
enabling the production listener. In TextEdit, a real styled selection produced
`Copper **Rich Bold** and *italic* fallback fixture 2026-07-31`. Safari required
WebKit's text-marker range and produced `**Example Domain**`. Chrome initially
exposed an AX font dictionary and a zero-sized range; that observation led to
support for AX font flags/name traits and rejection of invalid range bounds.
The repeated Chrome run produced `**Example Domain**`, `selectionSource` =
`attributedRange` and a 234 × 36 selection frame.

Each final background report records exactly one new note and one toast, one
matching note, an unchanged clipboard, a preserved real selection,
`applicationActive=false`, `keyboardMonitorsInstalled=false`, the same
frontmost app before/after and a visible non-key toast. Because the source apps
were deliberately addressed by bundle identifier while another app remained
frontmost, these reports prove that Copper did not activate or disturb the
current frontmost app. The temporary Chrome tab was closed. The Electron/plain
route was then completed in a real Untitled editor in the existing VS Code
Electron process. Screen Reader Optimized Mode exposed the editor text to AX;
the selected plain fixture remained selected after capture. The evidence
recorded exactly one matching note, one `Captured` toast,
`applicationActive=false`, `keyboardMonitorsInstalled=false`, unchanged
clipboard and a non-key toast. No user document was touched. The no-AX-
attributed-text fallback remains covered by the formal converter test rather
than being claimed as a separate runtime condition.

The authorised production block then exercised the previous exact signed
floating panel build. It is retained as historical capture evidence and is not
evidence for the current normal-level lifecycle. Two physically repeated
default double-Shift gestures were intentional,
as confirmed by the user; the cumulative report contains `gestureCount=2` and
`successCount=2`, while each latest-gesture delta is one note and one toast. A
single physical `Command-Control-Shift-C` run contains `gestureCount=1`,
`successCount=1`, one matching rich note, one toast, unchanged clipboard and
selection, the same active TextEdit before/after, inactive Copper, a visible
non-key toast and zero local monitors. The attempted `Control-Option-C` custom
shortcut is retained as negative evidence because TextEdit handled the
non-consumed key and altered the selected fixture; the UI now rejects that
VoiceOver-modifier combination.

The historical foreground Computer Use run also exercised Search, section creation, sequential
Composer inserts, multi-selection, Copy as List and its real numbered
clipboard, completion, Merge, Move, Expand, inline Edit and Edit in New Window.
The initial borderless panel could display focus but not receive keyboard input;
the then-current `CopperPanel` could become key without becoming main. After
that historical fix,
Composer + Return, card Space, Command-Space, Return and Command-Return passed,
and Tab traversed Search, Options, both section headers, all cards, the Composer
button and its field. Relaunching the same isolated store preserved the active
section, content, edit result and completion. The production panel remained
visible and AX-addressable in a real TextEdit full-screen Space.

The final menu-routing repetition used the rebuilt signed bundle. A focused
`Command-C` copied exactly one selected incomplete card, left it incomplete and
showed exactly one `Copied` toast. A focused `Shift-Command-C` copied two
selected cards in top-to-bottom order as a numbered list, completed exactly
those two cards and showed exactly one `Copied as List` toast. Selecting the
literal `Native field copy` in Search then copied that literal through the
native `NSTextView` field editor, rather than invoking card copy.

The final customisation repetition changed Copy in Settings to
`Command-Shift-K`, verified the persisted `⌘⇧K` value, and used targeted
`super+shift+k` to copy the selected card once with one toast. With that custom
card shortcut active, a real `Custom copy guard` Search selection still copied
through standard `Command-C`.

The background window diagnostic was also run with:

```bash
Scripts/LaunchBackgroundUITest.sh \
  --force-reduce-motion \
  --force-differentiate-without-color \
  --force-high-contrast \
  --force-accessibility-scale \
  --background-ui-test-screen-index=1 \
  --window-diagnostic-output=/tmp/copper-window.json
Scripts/StopBackgroundUITest.sh
```

It observed two screens and placed the 430 × 792 test window inside the second
screen. The current report showed `windowClass=NSWindow`, `windowLevel=0`,
`collectionBehaviorRawValue=0`, `isFloatingPanel=false`, `isKeyWindow=false`,
`applicationActive=false`, `keyboardMonitorsInstalled=false`,
`globalCaptureMonitorInstalled=false` and
`localKeyboardMonitorInstalled=false`. Computer Use saved a screenshot and read
the current full card labels, completion/selection values and the actions
Select, Mark done, Copy, Copy as List, Open, Edit in New Window and Move
without foregrounding Copper. Each card is now one AX element rather than a
card plus duplicated visual check/text children. This validates the current AX
structure and forced render paths. No physical key was synthesised in background
mode. Production full-screen was observed. The user then performed one real
`Control-Right` transition; Computer Use found the production `CopperPanel` still
visible and AX-addressable in the new Space. A subsequent real multi-monitor
check confirmed that the production panel also remains usable across displays.

## 2026-08-01 integration run

The integration branch was built with `Scripts/BuildApp.sh` and launched with
`Scripts/LaunchBackgroundUITest.sh`; the exact instance was stopped with
`Scripts/StopBackgroundUITest.sh`. Computer Use inspected the resulting AX
tree and screenshot without foregrounding Copper. The short composer showed no
visible scrollbar. After entering multiline content, its height grew to the
contract maximum and the AX tree exposed an automatic vertical scrollbar only
once the content overflowed.

A double-click on a long card opened the full-prompt sheet. The sheet exposed
the complete prompt in a scrollable text editor and showed Save, Cancel and
Close controls. Selecting a card and pressing Return opened the same sheet.
Pressing Escape closed the sheet and returned to the panel; the card no longer
had the selection state. The model suite separately covers invalid note IDs,
prompt opening, update persistence with undo/redo, deletion of an open prompt,
and the combined text-responder Escape route. No claim is made here about
pixel-perfect parity or a new foreground `Command-Return` run.

Current evidence is retained under
`.scratch/copper-reconstruction/evidence/2026-07-31/`, including:

- `README.md`, which distinguishes successful, superseded and negative runs;
- `textedit-real-rich-capture.json`;
- `safari-capture.json`;
- `chrome-capture-fixed.json`;
- `background-main-current.jpeg` and `background-window-current.json`;
- `background-accessibility-current.jpeg` and
  `background-window-accessibility-current.json`;
- `production-window-foreground.json` and `production-main-foreground.jpeg`;
- `production-live-capture-repeat-two-intentional-gestures.json`;
- `production-live-capture-custom-safe.json`;
- `production-keyboard-tab-trail.json` and
  `production-composer-keyboard-fixed.jpeg`;
- `production-copy-keyboard-observation.md`,
  `production-copy-keyboard-fixed.jpeg` and
  `production-copy-as-list-keyboard-fixed.jpeg`,
  `production-copy-custom-keyboard-fixed.jpeg`, with
  `production-window-copy-keyboard-command-route.json` and
  `production-window-final-keyboard.json`;
- `production-copy-list-foreground.jpeg`,
  `production-edit-new-window-foreground.jpeg` and
  `production-panel-fullscreen.jpeg`;
- `privacy-network-audit.md`.
- `production-panel-polish.json` and `background-window-polish.json`, the exact
  final shell diagnostics;
- `icon-and-install-polish.md` and `companion-lifecycle-polish.md`, the icon,
  installation and lifecycle handoff notes.

## Accessibility/TCC boundary

`Scripts/AccessibilityTrustDiagnostic.sh` rebuilt and launched the exact signed
`.build/Copper.app` bundle after the final monitor change. It reported the exact
bundle/executable paths, `isTrusted=true`, `backgroundUITest=true`,
`keyboardMonitorsInstalled=false`, `globalCaptureMonitorInstalled=false` and
`localKeyboardMonitorInstalled=false`, then terminated the process. This proves
the current bundle's TCC identity and background-monitor guard. The authorised
foreground block separately proved default/custom live gestures, Settings,
focused keyboard routing, production full-screen, one physical cross-Space
transition and multi-monitor movement.

## Deferred parity work

The following items are intentionally postponed and are not blockers for the
current personal reconstruction:

- pixel-level visual matching: exact material/colour tokens, dimensions,
  typography and line wrapping, shadows, composer treatment, toast/context-menu
  visuals and settings visuals;
- exact original Copper behaviour that public evidence cannot establish:
  scroll inertia/virtualisation, section lifecycle, search matching, merge and
  move semantics, multi-note `Copy` formatting, selection gestures,
  archive/restore, capture behaviour for secure or inaccessible text, rich-text
  conversion rules, launch-at-login, import/export, update handling and
  licensing UX.

These are parity and reverse-engineering follow-ups, not evidence of an
incomplete core implementation.

## Intentional scope boundary

This personal clone does not implement Copper's commercial licensing or
update-download service. It keeps notes local and has no app analytics,
telemetry, crash uploads, note-content uploads, network sync, or website
Vercel Analytics dependency.
