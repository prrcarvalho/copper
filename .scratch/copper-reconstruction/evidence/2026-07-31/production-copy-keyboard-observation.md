# Production keyboard Copy observation

- Bundle: `/Users/pedrocarvalho/Documents/copper-reverse-engineered/.build/Copper.app`
- Mode: production `CopperPanel`; no background diagnostic window and no global shortcut synthesis.
- Input: Computer Use targeted the Copper app and sent in-app `super+c` / `super+shift+c` after real card selections.

## `Command-C`

- One selected, incomplete card remained incomplete.
- Clipboard became exactly:

  `Keep the core configuration declarative even if you later add an optional TypeScript escape hatch`

- The AX tree exposed exactly one visible `Copied` toast.

## `Shift-Command-C`

- Two selected cards were serialized in visual order.
- Clipboard became exactly:

  ```text
  1. Negation in inherited configs. The moment a config can extend a base or preset, someone needs to remove an extension the...
  2. Use TOML as the default declarative format, backed by a published schema
  ```

- Both selected notes became completed.
- The AX tree exposed exactly one visible `Copied as List` toast.

## Native text-field copy guard

- A real `Native field copy` selection was made in the Search field through AX.
- `Command-C` copied exactly `Native field copy`, proving that the note-copy command does not replace native copy while an `NSTextView` field editor is first responder.
- The original clipboard snapshot was restored after the scenario.

## Custom in-app Copy shortcut

- Settings changed Copy from `Command-C` to `Command-Shift-K` and persisted
  `⌘⇧K` in the isolated store.
- Targeted `super+shift+k` then copied the selected card exactly once and
  exposed one `Copied` toast.
- With that custom card shortcut active, a real `Custom copy guard` selection
  in Search still copied through standard `Command-C`.
