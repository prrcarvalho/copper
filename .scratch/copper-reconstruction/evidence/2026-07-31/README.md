# Evidence index — 2026-07-31

This directory retains both successful final observations and intermediate
diagnostics that led to fixes. A failed or superseded report is intentionally
kept rather than rewritten as a success.

## Evidence used by `docs/ux-verification.md`

- `textedit-real-rich-capture.json` — real TextEdit bold/italic selection;
  exactly one note and toast, selection preserved, clipboard unchanged, Copper
  inactive and toast non-key.
- `safari-capture.json` — real Safari/WebKit text-marker selection; one rich
  Markdown note and one toast with valid selection bounds.
- `chrome-capture-fixed.json` — repeated Chrome run after AX font and zero-bounds
  fixes; bold Markdown plus valid selection-relative toast placement.
- `background-main-current.jpeg` and `background-window-current.json` — current
  safe background `NSWindow`, current visual hierarchy and AX semantics.
- `background-accessibility-current.jpeg` and
  `background-window-accessibility-current.json` — current forced Reduce
  Motion, Differentiate Without Color, Increased Contrast and accessibility
  scale route on display 2 of 2; the accompanying current AX read showed one
  semantic element per card, with no duplicated visual check/text children.
- `privacy-network-audit.md` — source/binary/entitlements inspection and current
  controlled runtime socket observation.
- `production-window-foreground.json` and
  `production-main-foreground.jpeg` — the exact production bundle as an
  inactive, visible, non-key floating `NSPanel`, level 3, collection behaviour
  257, with one global and zero local keyboard monitors.
- `production-live-capture-repeat-two-intentional-gestures.json` — two
  physically repeated default double-Shift gestures. The user confirmed that
  both gestures were intentional; the cumulative report contains two successes
  and the latest gesture contains one note and one toast. The first report was
  observed at `gestureCount=1` before the intentional repetition.
- `production-live-capture-custom-safe.json` — one physical
  `Command-Control-Shift-C` gesture; exactly one rich note and one toast,
  preserved selection and clipboard, unchanged active TextEdit, inactive
  Copper, non-key toast and zero local monitors.
- `production-composer-keyboard-fixed.jpeg`,
  `production-keyboard-tab-trail.json` and
  `production-tab-options-focused.jpeg` — production keyboard focus after the
  key-panel fix: Composer + Return, Space, Command-Space, Return,
  Command-Return, and the complete Tab loop through Options, section headers,
  cards and Composer controls.
- `production-copy-keyboard-observation.md`,
  `production-copy-keyboard-fixed.jpeg` and
  `production-copy-as-list-keyboard-fixed.jpeg`,
  `production-copy-custom-keyboard-fixed.jpeg`, with
  `production-window-copy-keyboard-command-route.json` and
  `production-window-final-keyboard.json` — final rebuilt production route for
  focused `Command-C`, focused `Shift-Command-C`, custom `Command-Shift-K`,
  deterministic clipboard order/completion, one toast per action and the
  native text-field copy guard before and after customisation.
- `production-copy-list-foreground.jpeg`,
  `production-merge-foreground.jpeg`,
  `production-edit-new-window-foreground.jpeg` and
  `production-persistence-store.json` — real foreground UI action paths,
  numbered clipboard output/completion/toast, Merge, Move, inline/separate
  edit states and relaunch persistence.
- `production-panel-fullscreen.jpeg` and
  `production-fullscreen-source.jpeg` — the production panel remained visible
  and AX-addressable in TextEdit's actual full-screen Space.

The successful capture fixtures do not contain Markdown punctuation whose
literal escaping changed in the subsequent plain-fallback hardening, so their
rich conversion output is unchanged by that later model fix. The literal plain
fallback itself is currently formal-test evidence only and remains marked as a
runtime limitation.

## Intermediate and negative evidence

- `textedit-rich-capture.json`, `textedit-rich-capture-fixed.json` and
  `textedit-rich-probe.json` record the all-regular TextEdit setup attempts that
  exposed the need for a genuinely styled selection.
- `chrome-capture.json` records the initial Chrome result with a missing bold AX
  trait and invalid zero-sized bounds; `chrome-capture-fixed.json` is the
  successful repeated result.
- `safari-capture-final.json` is a later **negative** read: the prior visible
  selection was no longer exposed to AX, so it correctly records
  `captured=false`, `noteDelta=0` and `toastPresentationDelta=0`.
  `safari-capture-final.jpeg` is the matching read-only screenshot. This is not
  used as success evidence.
- `background-window-initial.json`, `ui-flow-window.json` and the path/PID text
  files record setup and cleanup history. The named temporary Chrome and VS Code
  processes were scoped by exact command line and terminated; the user's
  existing app instances were not modified.
- `production-window-copy-keyboard.json`,
  `production-window-copy-keyboard-fixed.json` and
  `production-window-copy-keyboard-panel-handler.json` record the superseded
  keyboard-routing iterations before the final command route. They are not
  success evidence.
- `production-live-capture-custom.json`,
  `production-live-capture-custom-unsafe-combination.json` and
  `production-custom-shortcut-unsafe-source.jpeg` retain the failed
  `Control-Option-C` trial. The global monitor fired once but the source app
  handled the same non-consumed shortcut, replaced the selected fixture and
  exposed no selection to Copper. That observation led to rejecting the
  VoiceOver modifier and requiring Command plus another modifier for custom
  global shortcuts. It is negative evidence, not a successful capture.
