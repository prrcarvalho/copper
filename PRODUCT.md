# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Stack

Delegated: SwiftUI for the product surface with AppKit interop for the
floating panel, system menus, Accessibility APIs and clipboard integration.

## Users

The primary user is a solo AI-assisted software builder who moves between
ChatGPT, Claude, Cursor, browsers and other macOS applications while collecting
context and staging follow-up prompts.

## Product Purpose

Copper is a local-first companion queue for capturing selected text, organising
notes and prompts, then copying them back into the active AI workflow. Success
means preserving useful context with minimal interruption and making queued
prompts easy to execute and mark complete.

## Positioning

The product joins cross-app capture, prompt staging and completion tracking in
one small keyboard-first Mac utility. It is not a general notes app, a remote
clipboard service or an AI chat client.

## Operating Context

The user keeps Copper beside an active app in a compact floating window. They
capture selected text with double `Shift`, write prompts in the bottom composer,
organise cards under sections, search the queue, select multiple cards and copy
them as a numbered list into an AI chat.

## Capabilities and Constraints

- macOS 14 or later is the target baseline.
- The app uses Accessibility permission to read selected text and listen for
  the global capture gesture.
- Notes are stored on-device in a local file; there is no account, sync,
  analytics, telemetry or note-content logging.
- This boundary applies to the native reconstruction. The official website's
  separate Vercel Analytics page-view measurement is not bundled or contacted.
- The observable feature set includes sections, search, Markdown previews,
  completion, multi-selection, copy, Copy as List, editing, editing in a new
  window, merging, moving, context menus and customisable shortcuts.
- The exact original Copper storage schema, internal framework, section flows,
  search algorithm and selection gesture remain open decisions.

## Brand Commitments

- Preserve the observable Copper visual language from the supplied analysis and
  official frame assets.
- Apply shadcn/ui composition principles as native design rules: semantic
  states, composed primitives, consistent variants, accessible labels and
  explicit empty/error/feedback states.
- Keep the result native to macOS rather than introducing a web runtime.

## Evidence on Hand

- `docs/product-spec.md` contains the evidence-based product and UX analysis.
- `docs/copper-official/` contains the 47-frame audit, contact sheet, OCR and
  addendum.
- `docs/adr/0001-native-macos-architecture.md` records the native architecture
  decision.
- The original product's private source code and exact storage are not
  available and must not be fabricated.

## Product Principles

1. Capture should preserve the user's flow, focus and selected context.
2. Keyboard-first actions should feel immediate and predictable.
3. Every note state should be legible through both visual and accessibility
   semantics.
4. Local persistence and privacy are product behaviour, not implementation
   details.
5. The interface should stay compact, calm and scan-friendly beside another
   active application.

## Accessibility & Inclusion

All interactive controls must have meaningful accessibility labels, roles and
state descriptions. The app must support keyboard navigation, visible focus,
Dynamic Type where practical, Reduce Motion, high-contrast system settings and
safe failure when Accessibility permission or selected text is unavailable.
