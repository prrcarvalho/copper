# ADR-0001: Build the clone as a native macOS application

- **Status:** Accepted
- **Date:** 2026-07-30

## Context

The observable Copper product is presented as a native Mac app and relies on
behaviour that crosses application boundaries:

- a compact companion window with normal macOS activation and focus behaviour;
- global double-`Shift` detection;
- selected-text capture from the current application;
- native contextual menus and keyboard handling;
- system clipboard integration;
- on-device storage.

A local checkout of `github.com/shadcn-ui/ui` is available under `.opensrc/`.
That repository provides open-code React components, Tailwind styling and web
application tooling. Its component implementation does not provide macOS
Accessibility, AppKit windowing or native global keyboard behaviour.

## Decision

Build the application with:

- SwiftUI for declarative application UI and state-driven views;
- AppKit interop for `NSPanel` or customised `NSWindow` behaviour, contextual
  menus and lower-level keyboard handling;
- macOS Accessibility APIs for selected-text capture;
- `NSPasteboard` for copying note content;
- a versioned local persistence layer, beginning with a user-inspectable file
  unless scale or migration evidence justifies SQLite.

Treat shadcn/ui as a visual and composition reference only. Do not add a web
runtime, Electron shell or shadcn CLI dependency to the native application
unless a later, evidence-backed decision supersedes this ADR.

## Consequences

### Benefits

- Direct access to the macOS APIs required by the product loop.
- Native window, menu, keyboard, material and accessibility behaviour.
- Smaller runtime footprint than an embedded browser application.
- A privacy model aligned with local-only storage.

### Costs

- SwiftUI/AppKit interop requires deliberate lifecycle and focus management.
- Global capture must handle Accessibility permission, unsupported controls and
  secure fields safely.
- Visual parity must be recreated from evidence rather than imported from
  shadcn/ui components.

## Validation

The first technical spike should prove these risks before broad UI work:

1. Show and restore a normal-level companion panel without disrupting the
   source application more than necessary, while allowing ordinary click,
   Dock, Command-Tab, close, minimize, and quit behaviour.
2. Detect double `Shift` reliably without interfering with ordinary typing.
3. Read selected text from at least TextEdit, Safari/Chrome and one
   Electron-based AI application through Accessibility APIs.
4. Persist a captured note locally and copy it back through `NSPasteboard`.
