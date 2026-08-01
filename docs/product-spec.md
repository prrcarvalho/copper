# Copper — Product, UX and Reverse-Engineering Specification

**Target:** `https://shadcn.com/copper`  
**Document type:** Evidence-based product and UI hand-off  
**Intended use:** Reconstruct Copper's observable macOS experience from public materials  
**Analysis date:** 30 July 2026  

> This document describes observable behaviour and a plausible implementation plan. It does not claim access to Copper's source code, private APIs, exact storage schema, or internal architecture.

---

## 1. Evidence Model

Every material claim is classified as one of the following:

| Label | Meaning |
|---|---|
| **[P] Product page** | Explicitly stated on the public Copper product page. |
| **[V] Video** | Directly visible or explicitly written in the supplied 47-second product video. |
| **[R] Privacy page** | Explicitly stated in Copper's public privacy policy. |
| **[I] Inference** | A reasonable implementation or UX inference that is not publicly confirmed. |

### Primary sources

1. Product page: <https://shadcn.com/copper>
2. Privacy page: <https://shadcn.com/copper/privacy>
3. Supplied product video: `copper.mp4`, 1920×1080, 30 fps, approximately 47.25 seconds
4. Extracted evidence frames: see `frames/` and the frame index in section 14

---

## 2. Product Definition

Copper is a macOS utility that combines the useful parts of a to-do list, clipboard and scratchpad for AI-assisted work. It is designed to sit beside tools such as ChatGPT, Claude, Cursor, Chrome and other apps, chats and tabs. **[P][V]**

The core workflow is:

1. Capture text that may be useful later without interrupting the current task.
2. Store snippets and manually written follow-up prompts in a compact side window.
3. Organise items into sections.
4. Select one or more queued prompts.
5. Copy them back into an AI chat, optionally as a numbered list.
6. Mark processed items as completed. **[P][V]**

### Core job to be done

> While working across AI conversations and applications, preserve useful context and stage future prompts without opening a full note-taking system or losing the current train of thought.

### Problems addressed

- **Context fragmentation:** answers, links, ideas and follow-up prompts become scattered across apps and tabs. **[P]**
- **Interruption cost:** saving a snippet in a conventional notes app requires app switching and manual organisation. **[I]**
- **Prompt staging:** a user may think of several next prompts before the current AI response is complete. **[P][V]**
- **Execution tracking:** queued prompts can be checked off as they are used. **[P][V]**

---

## 3. Confirmed Capability Inventory

| Capability | Evidence | Confidence | Notes |
|---|---:|---:|---|
| Native Mac app | [V] | High | The closing feature frame explicitly says “Native Mac App”. The exact framework is unknown. |
| macOS 14 or later | [P] | High | Public system requirement. |
| Global selected-text capture | [P][V] | High | Demonstrated from another active application. |
| Default capture shortcut: `Shift`, then `Shift` | [P][V] | High | Presented as “Shift + Shift” in the video. |
| Accessibility permission | [P] | High | Used to read selected text and listen for shortcuts. |
| Floating companion window | [V] | High | Shown as an independent compact window beside the active app. |
| Scratchpad / manual prompt entry | [P][V] | High | Persistent bottom composer. |
| To-do completion state | [P][V] | High | Circular control becomes a filled blue checkmark; completed text is struck through. |
| Sections | [V] | High | Explicitly listed and demonstrated with `RESEARCH` and `CONFIGURATION FORMATS`. |
| Search | [V] | High | Search field is always visible at the top in the demonstrated layout. |
| Markdown | [V] | High | Explicitly listed; bold and italic text are visibly rendered in cards. |
| Multi-selection | [V] | High | Two cards are selected simultaneously with blue outlines. |
| Copy | [V] | High | Context-menu action with `⌘C`. |
| Copy as List | [V] | High | Context-menu action with `⇧⌘C`; output is a numbered list. |
| Automatic completion after Copy as List | [V] | High for demonstrated flow | Both copied items become checked and struck through after the action. |
| Merge Notes | [V] | High | Appears in the context menu and closing feature list. |
| Move to | [V] | High | Context-menu submenu, likely for moving notes between sections. |
| Edit | [V] | High | Context-menu action. |
| Edit in New Window | [V] | High | Context-menu action. |
| Expand | [V] | High | Context-menu action; disabled in the demonstrated multi-selection state. |
| Custom shortcuts | [V] | High as a claimed feature | Listed in closing frame; the settings UI is not shown. |
| Keyboard-first operation | [V] | High as positioning | Explicitly listed in closing frame. |
| Local file storage | [P][R][V] | High | Notes are saved to a file on the Mac. Exact format and path are unknown. |
| No account | [P][R][V] | High | No account is required. |
| No note sync | [P][R] | High | The local file is described as the only copy. |
| No in-app analytics/telemetry | [R][V] | High | No analytics, telemetry, crash reports or usage data in the app. |
| Update checking/downloading | [R] | High | Copper checks a server for a newer version and downloads it. |
| Free updates | [V] | High as a marketing claim | Explicitly listed in the product video. |
| License activation through Lemon Squeezy | [R] | High | The install flow sends the license key to Lemon Squeezy. |

---

## 4. End-to-End User Flows

### 4.1 Capture selected text

**Preconditions**

- Copper is running.
- Accessibility access has been granted. **[P]**
- The user has selected text in another macOS application. **[V]**

**Observed sequence**

1. User highlights a passage in the active source application. **[V]**
2. User presses `Shift` twice. **[P][V]**
3. A small dark toast reading `Captured` appears close to the source content. **[V]**
4. The selected passage is added as a card in Copper. **[V]**
5. Rich text/Markdown emphasis from the source is visibly preserved in the card preview. **[V]**
6. The workflow is demonstrated repeatedly without manually focusing Copper first. **[V]**

**Do not overstate**

- The video demonstrates global capture while another app is active, but it does not conclusively prove every detail of focus preservation, clipboard preservation, unsupported-app handling or error recovery.

### 4.2 Write follow-up prompts before they are ready to send

1. The user activates the bottom composer labelled `Add a note or a prompt (development)`. **[V]**
2. The composer expands into an editable card with a blue focus ring. **[V]**
3. The user types a prompt.
4. Committing the entry adds it to the list and restores a new empty composer at the bottom. **[V]**
5. The user can repeat this to build a queue of prompts. **[P][V]**

The exact commit key is not shown clearly enough to claim, although `Return` is a likely implementation. **[I]**

### 4.3 Select multiple prompts and copy them as a list

1. User selects two cards; both receive a blue outline. **[V]**
2. User opens the contextual menu. **[V]**
3. User invokes `Copy as List` (`⇧⌘C`). **[V]**
4. Copper writes a numbered plain-text list to the clipboard. **[V]**
5. The selected cards change to completed state: blue checkmark and strikethrough. **[V]**
6. A light toast reads `Copied as List`. **[V]**
7. Pasting into the target chat produces:

```text
1. How should configuration migrations work?
2. Should plugins own their configuration schema?
```

**[V]**

### 4.4 Search and section organisation

- A search field occupies the top-left area of the Copper window. **[V]**
- A circular ellipsis button sits at the top-right. **[V]**
- Notes are grouped below uppercase section headers separated by horizontal rules. **[V]**
- Demonstrated sections include `RESEARCH` and `CONFIGURATION FORMATS`. **[V]**
- `Move to` strongly indicates that cards can move between sections. **[V]**
- The exact section creation, renaming, deletion and reordering interactions are not shown. **[I]**

---

## 5. UI Anatomy

### 5.1 Window

- Independent compact macOS utility window positioned beside the user's main workspace. **[V]**
- Highly rounded outer corners and a soft drop shadow. **[V]**
- Semi-translucent or material-backed body that allows the desktop colour to influence the panel. **[V]**
- The video consistently places it on the right, but it is not proven to be permanently edge-docked. Prefer the term **floating companion window**, not **side-docked overlay**. **[V]**
- No standard macOS traffic-light controls are visible on the Copper panel in the demonstrated state. **[V]**

### 5.2 Top toolbar

```text
┌──────────────────────────────────────────────┐
│ [⌕  Search________________________]   [•••] │
└──────────────────────────────────────────────┘
```

- Search uses a rounded pill field with magnifying-glass icon. **[V]**
- The options button is a circular light control containing three horizontal dots. **[V]**

### 5.3 Section header

```text
RESEARCH  ─────────────────────────────────────
```

- Uppercase, small, semibold grey label. **[V]**
- Thin divider extends from the label toward the right edge. **[V]**
- Section content follows vertically. **[V]**

### 5.4 Note card

```text
┌──────────────────────────────────────────────┐
│  ○   Markdown-rendered note or prompt       │
│      spanning one or more lines…            │
└──────────────────────────────────────────────┘
```

Observed properties:

- White or near-white rounded rectangle. **[V]**
- Circular state control aligned toward the leading/top edge. **[V]**
- Multiline body text with Markdown emphasis. **[V]**
- Long content is clipped and ends with an ellipsis. **[V]**
- Cards use comfortable internal padding and a narrow vertical gap. **[V]**

### 5.5 Card states

| State | Observable treatment |
|---|---|
| Default | Empty grey circular control; neutral card. |
| Editing/composer active | Blue focus ring; insertion caret; empty-state circle remains visible. |
| Selected | Bright blue outline around card; multiple cards can be selected. |
| Completed | Filled blue circle with white check; body text struck through and de-emphasised. |

### 5.6 Bottom composer

- Anchored at the bottom of the window. **[V]**
- Placeholder: `Add a note or a prompt (development)`. **[V]**
- Visually uses the same card language as stored items. **[V]**
- Expands vertically while text is entered. **[V]**

### 5.7 Toasts

Two distinct toast treatments are shown:

- **Capture toast:** small black capsule with white `Captured` text, displayed over the source application. **[V]**
- **Copy toast:** small light capsule with a dark icon and `Copied as List`, displayed near the selected cards. **[V]**

### 5.8 Context menu

The demonstrated menu appears to use the standard macOS contextual-menu visual language and contains:

| Action | Shortcut shown | Observed state |
|---|---:|---|
| Copy | `⌘C` | Enabled |
| Copy as List | `⇧⌘C` | Enabled |
| Mark as Done | `Space` | Enabled |
| Expand | None shown | Disabled during multi-selection |
| Edit | `Return` symbol | Enabled |
| Edit in New Window | `⌘Return` | Enabled |
| Merge Notes | `⇧⌘M` | Enabled |
| Move to | Submenu arrow | Enabled |

**[V]**

---

## 6. Interaction and Keyboard Model

### Confirmed shortcuts

| Operation | Shortcut | Evidence |
|---|---:|---:|
| Capture selected text | `Shift`, then `Shift` | [P][V] |
| Copy | `⌘C` | [V] |
| Copy as List | `⇧⌘C` | [V] |
| Mark selected note(s) as done | `Space` | [V] |
| Edit | `Return` | [V] |
| Edit in new window | `⌘Return` | [V] |
| Merge notes | `⇧⌘M` | [V] |

### Claimed but not demonstrated in settings

- Custom shortcut configuration. **[V]**
- The exact allowed key combinations, conflict handling and reset-to-default behaviour remain unknown.

### Likely selection behaviour

The video proves multi-selection but does not show enough pointer detail to determine whether it uses:

- `⌘Click`,
- `Shift+Click`,
- click-to-toggle selection,
- or a dedicated selection mode.

Treat this as an unresolved behaviour rather than assuming conventional list semantics. **[I]**

---

## 7. Observable State Model

A reconstructed note needs at least these UI states:

```text
NORMAL
  ├──> SELECTED
  ├──> EDITING
  └──> COMPLETED

SELECTED
  ├──> NORMAL
  ├──> COMPLETED
  ├──> COPIED
  ├──> MERGED
  └──> MOVED

EDITING
  ├──> NORMAL (commit)
  └──> NORMAL (cancel)

COPIED_AS_LIST
  └──> COMPLETED + toast
```

`COPIED_AS_LIST` is represented as a transition/event rather than a durable note state. **[I]**

---

## 8. Proposed Local Data Model

The public material confirms a local file, but not its schema or format. The following is a minimal reconstruction model, not a claim about Copper's actual implementation. **[I]**

```swift
struct Section: Codable, Identifiable {
    let id: UUID
    var title: String
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date
}

struct Note: Codable, Identifiable {
    let id: UUID
    var sectionID: UUID
    var markdown: String
    var isCompleted: Bool
    var sortIndex: Int
    var createdAt: Date
    var updatedAt: Date
}

struct Preferences: Codable {
    var captureShortcut: Shortcut
    var copyShortcut: Shortcut
    var copyAsListShortcut: Shortcut
    var markDoneShortcut: Shortcut
}

struct WindowState: Codable {
    var frame: CGRect
    var searchQuery: String
}
```

### Deliberately omitted fields

The video does not show source URLs, source-app names, capture timestamps, tags, attachments or remote identifiers on note cards. Do not add these to an exact visual clone unless they remain hidden implementation metadata. **[V]**

### Storage choices for a clone

- **JSON or property list:** closest to the public phrase “saved to a local file”; simple and portable. **[I]**
- **SQLite/Core Data:** safer for larger datasets, search and migrations, but less literally a user-inspectable notes file. **[I]**

The actual Copper format and file path remain unknown.

---

## 9. Plausible Native macOS Architecture

Only the final claim “Native Mac App” and macOS Accessibility requirement are confirmed. The following architecture is a recommended reconstruction approach. **[I]**

### UI layer

- SwiftUI for cards, sections, search, composer and settings.
- AppKit interop for precise window behaviour and contextual menus.
- `NSPanel` or a customised `NSWindow` for a compact floating utility surface.
- A material-backed background using SwiftUI material or `NSVisualEffectView`.

### Global capture

- Request Accessibility trust through `AXIsProcessTrustedWithOptions`.
- Detect the configured global shortcut using a permitted global event mechanism.
- Read selected text through the macOS Accessibility APIs (`AXUIElement`).
- Fall back carefully where an app does not expose `AXSelectedText`.
- Preserve the user's current app and selection wherever possible.

### Clipboard output

- Use `NSPasteboard.general`.
- `Copy` emits raw note content according to the selected-note order.
- `Copy as List` emits a deterministic numbered list:

```text
1. First selected note
2. Second selected note
```

- After a successful `Copy as List`, mark the emitted notes complete and show the toast, matching the video. **[V]**

### Search and Markdown

- Keep raw Markdown as the source of truth.
- Render a compact attributed preview in cards.
- Search raw Markdown text and section titles.
- The exact search algorithm—substring, token, prefix or fuzzy—is unknown.

### Persistence and privacy

- Persist locally only. **[P][R]**
- Do not add analytics, telemetry, crash-report uploads or note-content logging. **[R]**
- An updater may make a version request that exposes normal web-request metadata such as IP address and requested version, without note content or a user identifier. **[R]**
- License activation may be handled through Lemon Squeezy. **[R]**

---

## 10. Visual Reconstruction Targets

These values are estimates from the supplied 1920×1080 marketing video and should be tuned against the extracted frames. **[I]**

| Element | Approximate visual target |
|---|---|
| Window aspect | Narrow portrait utility panel, approximately 0.48–0.58 width-to-height ratio in the wide shots |
| Outer corner radius | Large, approximately 24–32 px at the video's rendered scale |
| Card corner radius | Approximately 18–24 px |
| Toolbar height | Approximately 48–56 px |
| Card vertical gap | Approximately 10–14 px |
| Window inset | Approximately 12–18 px |
| Card body text | macOS system sans, roughly 14–17 px depending on display scaling |
| Section label | Small uppercase system sans, increased tracking, grey |
| Selection blue | Close to the macOS system accent blue |
| Panel material | Pale cool grey with desktop colour visible through blur/translucency |
| Card fill | White/near-white with high opacity |
| Shadow | Large soft ambient shadow with low-opacity dark edge |

Do not treat colours sampled from the compressed marketing video as canonical design tokens. macOS colour management, video compression and the desktop wallpaper alter their apparent values.

---

## 11. Clone Acceptance Criteria

An `[x]` below means implemented and backed by formal or observed evidence in
section 17 and `docs/ux-verification.md`. It does **not** mean pixel-perfect,
one-to-one or hidden-behaviour parity. Visual items are observed
approximations; public evidence cannot establish exact internal values.

### Functional acceptance

- [x] Global selected-text capture works from supported macOS apps.
- [x] Default capture gesture is double `Shift`.
- [x] Capture shows a `Captured` toast.
- [x] Captured text appears as a note in the active/current section.
- [x] Markdown emphasis renders in note previews.
- [x] Composer can create successive queued prompts.
- [x] Notes can be searched.
- [x] Notes can be grouped into sections.
- [x] Multiple notes can be selected.
- [x] `⌘C` copies selected content.
- [x] `⇧⌘C` copies a deterministic numbered list.
- [x] Copy as List marks emitted items done and shows `Copied as List`.
- [x] `Space` toggles completion for selected items.
- [x] Edit, Edit in New Window, Merge Notes and Move to exist.
- [x] Shortcuts are customisable.
- [x] Notes survive relaunch through local persistence.
- [x] No account or note synchronisation is required.

### Visual acceptance (observed approximation)

- [x] Narrow floating utility window with large rounded corners.
- [x] Cool translucent panel material and soft shadow.
- [x] Search pill and circular ellipsis button at top.
- [x] Uppercase section labels with divider rules.
- [x] White rounded cards with leading circular state control.
- [x] Blue selection outline.
- [x] Blue completed checkmark and strikethrough.
- [x] Bottom composer visually matches a note card.
- [x] Native-looking macOS contextual menu and keyboard glyphs.
- [x] Capture and copy toasts match the two demonstrated treatments as an
  approximation.

### Privacy acceptance

- [x] Notes remain on-device.
- [x] No application analytics or telemetry.
- [x] No crash reports or usage-data uploads.
- [x] No update client exists, so note content cannot enter update checks.
- [x] Privacy documentation distinguishes the app from website analytics.

---

## 12. Important Unknowns

The public page and video do not establish the following:

1. Exact SwiftUI/AppKit implementation.
2. Exact window level, pinning, resizing and multi-monitor behaviour.
3. Whether the window can auto-hide or snap to an edge.
4. Exact persistence format and file location.
5. Section creation, renaming, deletion and ordering flows.
6. Search matching rules and result presentation.
7. Merge order, separator rules and completion-state handling.
8. Move-to behaviour and whether empty sections persist.
9. How a single `Copy` formats multiple selected notes.
10. How selections are created with mouse and keyboard.
11. Undo/redo, deletion, archival and restoration behaviour.
12. Capture fallback behaviour for inaccessible, secure or custom-rendered text.
13. Whether rich text is converted to Markdown heuristically or read as attributed content.
14. Shortcut-conflict detection and accessibility-event edge cases.
15. Launch-at-login support.
16. Import/export or backup support.
17. Update-signing, release-channel and rollback behaviour.
18. Licensing UX after activation or on additional Macs.

These should be validated through hands-on product testing rather than inferred from the marketing video.

---

## 13. Corrections to the Original Analysis

The original analysis was directionally strong, but several statements needed more precise wording:

| Original wording or assumption | Corrected treatment |
|---|---|
| “Side-docked overlay” | The video proves a floating companion window placed at the right, not permanent docking. |
| “Built strictly as a native macOS application” | The video markets it as a “Native Mac App”; the internal UI framework remains unknown. |
| “Without stealing focus” | The video proves capture without manually focusing Copper; exact focus-preservation semantics remain unverified. |
| “Pending, active and completed states” | Default, selected/editing and completed states are visible; a distinct persistent “active task” state is not. |
| “Free updates” was unconfirmed | It is explicitly listed in the supplied video. |
| Search, sections, Markdown, merge, custom shortcuts | All are explicitly claimed in the supplied video; several are also demonstrated. |
| Copy as List automatically completes cards | Confirmed by the video: blue checks, strikethrough and `Copied as List` toast. |
| Zero tracking | Correct for the Copper application. The website separately uses Vercel Analytics for page-view counting. |

---

## 14. Extracted Frame Index

The following frames are the minimum useful visual evidence set for reconstruction. They are provided as full-resolution PNG files under `frames/`.

| File | Timestamp | Evidence captured |
|---|---:|---|
| `01_initial_companion.png` | 00:01.200 | Full workspace, panel proportions, search, sections, card and composer. |
| `02_prompt_being_typed.png` | 00:03.200 | AI workspace context before capture workflow. |
| `03_text_selected_for_capture.png` | 00:09.400 | Selected source text immediately before global capture. |
| `04_capture_toast.png` | 00:10.500 | `Shift + Shift`, `Captured` toast and newly added card. |
| `05_sections_and_search.png` | 00:15.300 | Close-up of search, ellipsis, section header and card styling. |
| `06_captured_notes_grouped.png` | 00:17.300 | Multiple captured notes grouped under sections and Markdown emphasis. |
| `07_cross_app_capture.png` | 00:23.400 | Capture workflow demonstrated in another content/app context. |
| `08_new_note_after_capture.png` | 00:25.600 | Newly captured card appended to the queue. |
| `09_prompt_entry_first.png` | 00:29.500 | Expanded composer and first manually typed prompt. |
| `10_prompt_entry_second.png` | 00:32.700 | First prompt committed; second prompt being entered. |
| `11_multi_select.png` | 00:37.500 | Two simultaneous selected cards with blue outlines. |
| `12_context_menu.png` | 00:38.700 | Exact contextual actions and keyboard shortcuts. |
| `13_copy_as_list_completed_and_toast.png` | 00:40.467 | Auto-completion, strikethrough and `Copied as List` toast. |
| `14_list_pasted_in_chat.png` | 00:41.300 | Exact numbered-list clipboard output pasted into the chat. |
| `15_feature_summary.png` | 00:43.300 | Product's explicit closing feature inventory. |

A labelled contact sheet is included as `copper_reference_contact_sheet.jpg`.

---

## 15. Final Product Summary

Copper is best understood as a **local-first, keyboard-driven macOS queue for reusable context and next prompts**. Its differentiator is not merely clipboard history or note storage. It connects three actions into a low-friction loop:

```text
CAPTURE FROM ANYWHERE
        ↓
ORGANISE / QUEUE IN A SMALL COMPANION WINDOW
        ↓
COPY BACK INTO THE ACTIVE AI WORKFLOW AND CHECK OFF
```

The public evidence is sufficient to reconstruct the principal product loop, visual hierarchy and contextual actions. It is not sufficient to claim an exact clone of all internal behaviour without hands-on testing of the purchased application, particularly for settings, storage, section management, search, merge semantics and macOS edge cases.


---

## 16. 1 FPS Audit Deltas

A second-pass audit extracted **1 frame per second across the full 47.25-second video**, yielding **47 frames**. This broader sweep did not reveal any major missing capability, but it does justify a few small clarifications.

### 16.1 Additional confirmed positioning

The video explicitly uses the marketing copy:

- `It works everywhere.`
- `ChatGPT. Claude. Cursor. Chrome.`
- `Apps. Chats. Tabs. Everywhere.`
- `Send them to your chat with one shortcut...`

This strengthens the interpretation that Copper is positioned as a **cross-app companion** rather than a tool limited to one AI product. **[V]**

### 16.2 Additional UI fidelity notes

- In the earliest product shot, the Copper panel already shows its persistent structural chrome: search field, ellipsis/options button, section headers and bottom composer. **[V]**
- The two-note `Copy as List` demonstration preserves the same **top-to-bottom order** as the selected cards when pasting back into the chat input. **[V]**
- The visible context menu does **not** include delete, archive or trash actions; those may exist elsewhere, but they are not shown as primary note actions in the video. **[V]**

### 16.3 No change to the main conclusion

The original conclusion still stands: the public page plus the supplied marketing video are sufficient to reconstruct the core workflow, visual hierarchy and major actions of Copper for a close personal clone, but not its full hidden behaviour or exact internal implementation.

## 17. Reconstruction verification status (2026-08-01)

The current reconstruction implements active-section routing and persistence,
search/sections, deterministic multi-note operations, reversible completion,
configurable capture parsing/conflict/reset, Accessibility attributed-text
conversion with Markdown-escaped literal plain fallback, a nonactivating
selection-positioned toast,
separate Expand/inline-edit/new-window paths, a card-like composer,
accessibility render paths and local-only persistence. Production retains its
floating `CopperPanel`, an `NSPanel` subclass that can become key for text and
card controls without becoming main. Its only system event monitor is the
observational global capture monitor; in-app shortcuts use native menu/key
handlers, so no local event monitor consumes or replaces input and no code
reposts events. Custom global shortcuts require Command plus another modifier,
and Control-Option is rejected as the VoiceOver modifier. This reduces, but
cannot eliminate, conflicts with shortcuts owned by third-party source apps.

The formal Swift Testing suite is discovered and executed by SwiftPM (21/21).
Current controlled background evidence covers real rich selections in TextEdit,
Safari and Chrome. Every final report records exactly one new note, exactly one
`Captured` toast, a preserved source selection, unchanged clipboard, inactive
Copper, unchanged frontmost app and zero test-mode monitors. Chrome's first run
exposed an AX font/bounds defect; the repeated fixed run produced bold Markdown
and a valid selection-relative toast frame. The exact signed bundle passed TCC,
codesign, debug/release build, packaging, smoke, script syntax and diff checks.
A source/binary/entitlements/socket audit found no native-app network,
analytics, telemetry, crash-upload, sync or note-content upload path.

The current background window was inspected by Computer Use on the second of
two displays, both normally and with forced Reduce Motion, Differentiate Without
Color, Increased Contrast and accessibility-scale paths. The AX tree exposes
card labels, values and actions. This is runtime evidence for rendering and AX
structure and keyboard semantics.

The authorised foreground block exercised the exact production panel. Physical
default double-Shift and `Command-Control-Shift-C` runs each produced one note
and one toast per gesture with unchanged selection/clipboard, the same active
TextEdit, inactive Copper and a non-key toast. An attempted Control-Option-C
run demonstrated source-app interference and drove the stricter validation.
Computer Use then verified Search, section creation, Composer + Return,
multi-selection, Space, Command-Space, focused `Command-C`, focused
`Shift-Command-C`, a custom persisted Copy shortcut, native text-field copy,
completion, Merge, Move, Expand, Return, Command-Return, full Tab traversal,
separate editor window and relaunch persistence. The production panel remained
visible in a real TextEdit full-screen Space.

The current Electron/plain runtime is covered by a real VS Code Untitled editor
capture. One real cross-Space transition was completed and the production panel
remained visible and AX-addressable afterwards. Real pointer dragging and
multi-monitor movement were subsequently confirmed on the current bundle.
Visual matching remains an evidence-based approximation; neither pixel-perfect
nor hidden one-to-one parity is claimed.

## 18. Companion shell polish (2026-07-31)

The reconstruction now uses a hybrid macOS shell: production is a regular app
with a Dock/Command-Tab identity, while the visible companion remains a
floating, nonactivating `NSPanel` at floating level with all-Spaces and
full-screen auxiliary collection behaviour. The three standard traffic lights
are hidden, but the native titled/resizable/closable/miniaturizable style is
retained. The first-launch frame is `430×760`, the minimum is `320×420`, the
maximum width is `620`, and saved frames are clamped to the visible screen.
`⌘W` hides the panel while keeping capture alive, `⌘M` minimises it, and
`⌘0`/Dock reopen it. These shell improvements are implementation choices for
the personal reconstruction; the public evidence does not determine whether
the original Copper supports the same resize or lifecycle details.

The supplied icon artwork is preserved as
`Resources/AppIcon-source.png` and deterministically converted to a native
`.icns` resource during `Scripts/BuildApp.sh`. `Scripts/InstallApp.sh` validates
the signed bundle, keeps a prior `/Applications/Copper.app` in Trash with a
timestamp, registers the new bundle with Launch Services and opens it.

## 19. Deferred parity work

The remaining work is deliberately deferred rather than blocking the personal
clone:

1. Pixel-level visual parity: exact material/colour tokens, dimensions, corner
   radii, typography and wrapping, shadows, composer treatment, toast and
   context-menu visuals, settings visuals and scroll indicators.
2. Hidden behaviour of the original Copper that cannot be established from the
   supplied public evidence: exact persistence schema/path, section lifecycle,
   search matching, merge/move semantics, multi-note `Copy` formatting,
   selection gestures, undo/delete/archive/restore, inaccessible or secure-text
   capture, rich-text conversion rules, launch-at-login, import/export,
   update handling and licensing UX.

These are future parity and reverse-engineering tasks. The current clone's core
capture, organisation, copy, completion, persistence, shell, drag and
multi-monitor behaviour are treated as complete.
