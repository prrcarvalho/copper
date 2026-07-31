# Copper Reconstruction — UX Verification

Date: 2026-07-31

This matrix records evidence for the reconstruction against
[`docs/product-spec.md`](product-spec.md) and the supplied frames under
`docs/copper-official/`. It deliberately separates implementation evidence
from behaviour that needs a real cross-application run. The public reference
does not provide enough information to claim pixel- or behaviour-level
one-to-one parity for every internal detail.

## Build and formal model validation

```text
Scripts/BuildApp.sh                                      PASS
swift build                                              PASS
swift build -c release                                   PASS
swift test                                                PASS (10 tests executed)
swift test list                                           PASS (10 tests discovered)
swiftc -parse-as-library Sources/CopperCore/Models.swift \
  Scripts/CopperSmoke.swift -o .build/CopperSmoke && \
  .build/CopperSmoke                                        PASS
Scripts/AccessibilityTrustDiagnostic.sh                  NOT RERUN in this round (prior PASS; foreground UI forbidden)
git diff --check                                          PASS
```

The formal cases cover active-section routing and persistence, reversible
completion toggling including the focused-card Space endpoint, capture-shortcut
syntax/safety/conflict/reset handling and live matching updates, deterministic
move order, separate Expand state, attributed-to-Markdown conversion with
plain-text fallback, and the no-duplicate/no-repost keyboard invariant. SwiftPM
discovers and executes the suite through the pinned official Swift Testing
6.3.3 package; this replaces the previous build-only target and duplicated
local runner.

## Background Computer Use mode

Every Copper UI launch used for this task must use:

```bash
Scripts/LaunchBackgroundUITest.sh
Scripts/StopBackgroundUITest.sh
```

The debug branch creates a standard `NSWindow` at `NSWindow.Level.normal`,
with an empty `collectionBehavior`, and calls `orderFront(nil)` followed by
`NSApp.deactivate()`. It does not call `orderFrontRegardless()`, join all
Spaces, or join full-screen Spaces. Production remains the original floating
`NSPanel` path (`.floating`, `.canJoinAllSpaces`, `.fullScreenAuxiliary`, and
`orderFrontRegardless()`). A current Computer Use observation confirmed that
TextEdit remained visually above the background test window; the source-level
invariant is also checked in the final diff.

Background UI-test launches install no global or local keyboard monitor. This is
the strongest non-interference guard for Computer Use: the test window remains
inspectable, but it cannot observe, consume or re-emit keys from another app.
Production keeps the configurable monitor: default double-Shift registers only
`flagsChanged`, a configured key shortcut registers only `keyDown`, registration
is idempotent, and both global/local monitors have an explicit stop path on
termination. The repeated-key regression test injects two identical events and
asserts one callback with no repost; the original live incident stopped when
Copper was terminated, but its historical causal chain cannot be reconstructed
from the pre-repository build.

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

## Acceptance matrix

| Area | Current evidence | Status |
| --- | --- | --- |
| Active section routes composer and capture notes | `CopperStore.activeSectionID`, persistence, formal case, and a live section-header selection in Computer Use | **PASS (model/UI)** |
| Space completion is reversible | `handleCardSpace` selects the focused card when needed and calls `toggleSelectedCompletion()`; both directions pass formally | **PASS (model); focused end-to-end key routing unverified** |
| Configurable capture shortcut, conflict validation and reset | One domain parser/matcher, production `GlobalCaptureMonitor.update`, draft-only Settings validation/reset, conflict checks, unsafe bare-key rejection and formal matching-update cases | **PASS (code/model/UI); live global gesture pending** |
| Cross-app formatting conversion with safe fallback | AX attributed-string and WebKit text-marker paths, `MarkdownConverter`, plain-string fallback and formal attributed-string case; controlled app captures proved only plain selections | **PARTIAL — implementation/model PASS; real styled cross-app conversion unverified** |
| Non-activating toast near source app | Dedicated nonactivating floating toast panel; prior reports show `visible=true`, `isKeyWindow=false` and `applicationActive=false`; latest code asks AX for selected-range bounds before element-frame fallback | **PARTIAL — nonactivation runtime PASS; exact selection-relative placement not rerun** |
| Expand vs Edit in New Window | Expand sets `expandedID`; New Window opens `EditorView`; formal state case and both Computer Use assertions | **PASS (code/model/UI)** |
| Composer circle and layout refinement | The empty circle, editor and optional submit affordance now share one rounded card; automatic scroll indicators and semantic body fonts are implemented; frame 030 was inspected directly | **APPROXIMATION — source/asset comparison only after latest change** |
| Accessibility | Cards expose completion/selection values and named actions; `⌘Space` changes selection while plain `Space` toggles completion; Reduce Motion, non-colour differentiation, increased contrast and accessibility-scale render paths exist | **PARTIAL — code/prior AX tree PASS; focused keyboard and spoken VoiceOver unverified** |
| Privacy wording and implementation boundary | README/Settings/docs distinguish native app from official website Vercel Analytics | **PASS (docs/static review)** |
| TextEdit runtime | Controlled selection captured `Copper TextEdit runtime fixture 2026-07-31`; one new note, background Copper inactive, zero keyboard monitors, visible non-key toast | **PASS (diagnostic route)** |
| Safari runtime | Controlled real selection captured `Example Domain` through WebKit's selected-text-marker range; one new note, background Copper inactive, zero keyboard monitors, visible non-key toast | **PASS (diagnostic route; WebKit marker implementation)** |
| Chrome runtime | Isolated `example.com` tab with a real CUA text selection; report captured exactly one `Example Domain` note in the active section, with Copper inactive, zero keyboard monitors and one visible non-key toast; the selection remained in Chrome afterwards | **PASS (diagnostic route)** |
| Electron runtime | Isolated VS Code profile with extensions disabled and screen-reader mode enabled; real AX selection captured exactly one `Copper Electron runtime fixture 2026-07-31` note in the active section, toast non-key, Copper inactive, zero monitors, selection preserved | **PASS (diagnostic route)** |
| Spaces/full-screen/multiple monitors | Two displays observed; background window positioned on display 2 and reported `NSWindow`, level `0`, collection behaviour `0`, non-key/non-floating and inactive. Production full-screen/Spaces behaviour remains source-verified | **PASS multi-monitor/background; live production full-screen/Spaces not exercised** |
| Visual one-to-one parity | Supplied frames support an approximation of hierarchy, not hidden/internal behaviour | **APPROXIMATION** |

## Runtime evidence and remaining routes

TextEdit, Safari and Chrome were exercised through the test-only capture route
above. It deliberately does not prove that Computer Use can emit the production
global gesture; it proves the downstream capture path without enabling a global
listener during UI automation. Safari required the AX WebKit text-marker
parameterised attributes rather than the ordinary selected-text range. Chrome
used a newly created `example.com` tab, a real drag selection verified as
`Example Domain`, and exactly one diagnostic process. The persisted store held
exactly one matching new note in the active section. The toast report was
`visible=true`, `isKeyWindow=false`, level `3`, while Copper reported
`applicationActive=false` and `keyboardMonitorsInstalled=false`; the Chrome
selection was still `Example Domain` afterwards. The isolated tab was closed
and the Copper PID was terminated.

The Electron route used a separate temporary VS Code `--user-data-dir`, an
empty extensions directory and a repository fixture at
`Tests/Fixtures/electron-capture.md`. Screen Reader Optimized Mode exposed the
editor text to AX; the selected fixture remained selected after capture. The
diagnostic recorded exactly one matching note, `applicationActive=false`,
`keyboardMonitorsInstalled=false`, and a visible non-key toast. All isolated VS
Code and Copper processes were then terminated.

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
screen. The report showed `windowClass=NSWindow`, `windowLevel=0`,
`collectionBehaviorRawValue=0`, `isFloatingPanel=false`, `isKeyWindow=false`,
`applicationActive=false` and `keyboardMonitorsInstalled=false`. Computer Use
read the full card labels, values and actions without foregrounding Copper.
This prior AX inspection validates the VoiceOver-facing accessibility
structure, but does not claim that spoken VoiceOver phrasing was manually
audited. End-to-end keyboard focus/Space routing remains an explicit limitation
because a valid live check would require focusing the test window while the
user is working. No UI was foregrounded and no physical key was synthesised in
the final verification round. Likewise, production full-screen and cross-Space
placement were not activated; their configuration remains source-verified.

## Accessibility/TCC boundary

`Scripts/AccessibilityTrustDiagnostic.sh` builds and launches the exact signed
`.build/Copper.app` bundle and records `AXIsProcessTrusted()`. The stable local
designated requirement is identifier-based, so rebuilds do not silently become
a different TCC identity. The diagnostic passed after the exact bundle was
removed and re-added in System Settings. It was not rerun after the final
no-focus hardening because even a normal test window was prohibited in this
round. The remaining limitation is not the visible toggle itself: the global
double-Shift gesture, focused keyboard routing, styled selection and latest
selection-relative toast bounds require a controlled interaction and cannot be
inferred from a static Accessibility row.

## Intentional scope boundary

This personal clone does not implement Copper's commercial licensing or
update-download service. It keeps notes local and has no app analytics,
telemetry, crash uploads, note-content uploads, network sync, or website
Vercel Analytics dependency.
