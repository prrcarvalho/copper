# Copper Reconstruction

A private, local-first reconstruction of Copper's observable macOS experience
for personal use.

Copper's core product loop is:

```text
Capture selected text from any app
                 ↓
Organise notes and queue future prompts
                 ↓
Copy them back into the active AI workflow and mark them done
```

## Current status

The repository is in its foundation phase. It contains the evidence-based
product specification and the initial architecture decision; application code
has not been scaffolded yet.

## Product scope

The first usable version should provide:

- a compact floating macOS companion window;
- global selected-text capture, initially through double `Shift`;
- sections, search, Markdown previews and a bottom composer;
- single and multi-selection;
- copy, numbered-list copy, completion, editing, merging and moving notes;
- customisable keyboard shortcuts;
- local-only persistence with no account, sync, analytics or note telemetry.

The detailed behaviours, evidence labels, visual targets, unknowns and
acceptance criteria are in [the product specification](docs/product-spec.md).

## Architecture direction

This is a native macOS product. The implementation direction is:

- **SwiftUI** for the cards, sections, search, composer and settings;
- **AppKit interop** for `NSPanel`/`NSWindow`, contextual menus and precise
  window behaviour;
- macOS **Accessibility APIs** for reading selected text;
- `NSPasteboard` for clipboard output;
- a local file for persistence.

The shadcn/ui checkout under `.opensrc/` is a useful open-code design reference,
but it is a React/web component system and is not the runtime foundation for a
native macOS app. See
[ADR-0001](docs/decisions/0001-native-macos-architecture.md).

## Repository map

```text
.
├── docs/
│   ├── decisions/
│   │   └── 0001-native-macos-architecture.md
│   └── product-spec.md
├── .opensrc/
│   └── sources.json
└── README.md
```

`.opensrc/repos/` and `.agents/` are deliberately kept as local research and
agent caches and are not committed.

## Constraints

- Reconstruct only observable product behaviour and original implementation
  work.
- Do not claim access to Copper's private source code or internal APIs.
- Do not vendor proprietary branding, marketing assets or purchased binaries.
- Keep user notes on-device and avoid telemetry or note-content logging.
- This repository has no open-source licence; it is intended for private,
  personal use.

## Prerequisites for implementation

- macOS 14 or later;
- Swift 6;
- full Xcode installation selected with `xcode-select`.
