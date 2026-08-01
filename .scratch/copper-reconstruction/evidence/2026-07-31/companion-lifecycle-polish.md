# Companion lifecycle Computer Use evidence

The installed bundle `/Applications/Copper.app` was the only Copper process
during this foreground pass.

- `⌘W` hid the panel while the app process remained alive.
- `⌘0` restored the panel.
- `⌘M` minimised the panel; a second `⌘0` restored it.
- Launch Services reopening the hidden bundle (`open -a /Applications/Copper.app`)
  restored the same panel rather than creating a second one.
- The AX tree retained Search, Options, sections, cards, composer and their
  labels/actions after each restore.

The Computer Use server hit-tested the dedicated `CopperDragStripView`, but its
interior drag action delivered no final pointer delta in that session. A later
real user pointer drag confirmed the native AppKit mouse path, panel movement
and frame autosave.
