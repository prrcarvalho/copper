# Copper shell / icon packaging evidence

Observed on 2026-07-31 from the exact checkout
`/Users/pedrocarvalho/Documents/copper-reverse-engineered`:

- `Resources/AppIcon-source.png`: 1254×1254 RGB source supplied by the user.
- `Scripts/GenerateAppIcon.swift`: deterministic 1024×1024 RGBA master with
  only the exterior rounded-square corners made transparent.
- `Scripts/BuildApp.sh`: generated the native `.iconset` and
  `.build/AppIcon.icns` with `sips`/`iconutil` before signing.
- `.build/Copper.app/Contents/Resources/AppIcon.icns`: valid macOS icon
  resource; `codesign --verify --deep --strict` passed.
- `Resources/Info.plist`: `CFBundleDisplayName=Copper`,
  `CFBundleIconFile=AppIcon.icns`, `CFBundleIconName=AppIcon`, and no
  `LSUIElement` key in production.
- `Scripts/InstallApp.sh`: built and validated the bundle, moved the previous
  `/Applications/Copper.app` to
  `/Users/pedrocarvalho/.Trash/Copper.app-20260731-233634`, installed the new
  bundle atomically, validated its signature, icon and bundle metadata,
  registered it with Launch Services and opened it.
- A second invocation while the installed Copper PID was alive refused before
  building or replacing the bundle; the running-process guard passed.

No Developer ID certificate or notarisation was attempted; those remain
distribution concerns outside this personal local build.
