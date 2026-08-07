# Pulse

(Formerly "Coinbar", then merged with "zonebar" — renamed to Pulse in commit
`61f3ea9`; bundle id `com.samirettali.pulse`.)

The bundle id was `com.settali.pulse` — an old username, not a domain — until
2026-08-07. Changing it cost nothing: settings are a YAML file, not
`UserDefaults`, and there is no Keychain item or TCC grant keyed to it.

macOS menu bar app showing live prices and clocks: Binance spot/futures,
Hyperliquid perps/spot, Yahoo Finance symbols, and IANA timezone clocks. Items
are configured from the popup and persisted as YAML in
`~/.config/pulse/config.yaml` — there are no `UserDefaults` and no Keychain
items, so the bundle id carries no state.

## Build & run

- Plain SwiftPM (no Xcode project): `make bundle` builds and assembles
  `dist/Pulse.app`, `make run` also launches it, `make dev` does an unoptimised
  build and replaces the running copy. `Packaging/Info.plist` is copied into the
  bundle by the Makefile — `LSUIElement` lives there, so a bare `swift run`
  binary is not quite the shipped app.
  - The Xcode project (`Coinbar.xcodeproj`) and `scripts/build-release.sh` were
    removed when signing was set up: they carried nothing SwiftPM couldn't do
    (no asset catalog, no icon, one dependency) and kept the build settings in a
    hand-written `project.pbxproj`.
  - Quitting before relaunching is not optional, hence the `pkill` in `run` and
    `dev`: two instances mean two menu bar items with their own websocket
    connections, and `open` on a running app of the same bundle id just
    activates it, so you would be testing the old binary.
- **Signing**: `make bundle` signs with `Developer ID Application` — the *same*
  identity used for distribution, deliberately, so dev and release builds share
  one designated requirement. Falls back to `Apple Development`, then ad-hoc,
  each with a warning (`SIGN_IDENTITY=…` overrides).
  The certificate is `Developer ID Application: Samir Ettali (22K9H4B864)`,
  issued by the paid membership and shared with Sottovoce. Certs renew yearly;
  Team ID and leaf CN stay the same.
- **Hardened runtime** is on for every build (`--options runtime`), not just for
  release, so dev builds hit the same restrictions the shipped app does.
  **No entitlements file**: Pulse only opens outgoing connections, which the
  hardened runtime allows unclaimed, and it is not sandboxed (so no
  `com.apple.security.network.client` either). Add
  `--entitlements` back to the `codesign` line the day it needs one.
- **Release**: `make release` → notarised, stapled `dist/Pulse-<version>.dmg`,
  where `<version>` is `CFBundleShortVersionString` from `Packaging/Info.plist`
  (bump it there, then tag and upload the DMG with `gh release create`).
  It notarises *twice*, the app and then the DMG: the ticket stapled to a DMG
  only covers the app while it's on the mounted image, so the app needs its own
  ticket to launch offline after being dragged to /Applications. Needs a
  notarytool keychain profile named `notary`
  (`xcrun notarytool store-credentials notary --apple-id samir@ettali.com
  --team-id 22K9H4B864 --password <app-specific-password>`; override with
  `NOTARY_PROFILE=…`). The name is deliberately not the app's: the credentials
  belong to the Apple account, so every app here shares the one profile and a
  new machine needs a single `store-credentials` run. Sottovoce uses the same.
- **CI** (`.github/workflows/build.yml`) is a compile check only. Releases are
  built and signed locally on purpose: CI would mean the Developer ID private
  key and the notarisation credentials in repository secrets, and the DMG layout
  step scripts Finder, which hosted runners can't do reliably. The old
  `release.yml`, which published an unsigned zip on every tag, was removed.
- **DMG layout** (`Packaging/make-dmg.sh`, shared verbatim with Sottovoce): the
  image is built read/write, Finder is scripted to set the window (600×400, icon
  view, 128 pt icons, app at (150,175) and the `/Applications` symlink at
  (450,175)), then converted to compressed read-only. The layout lives in a
  `.DS_Store` *inside* the image, so everyone sees the same window instead of
  their own Finder defaults.
  - **No background art on purpose**: a background image is static, but Finder's
    icon labels turn white in dark mode, so a light background with a drawn
    arrow becomes unreadable. Position alone conveys the drag and survives both
    appearances.
  - HFS+, not the APFS default: it's the safer filesystem for a Finder-laid-out
    DMG, and it compresses better at `zlib-level=9`.
  - The volume is mounted **browsable** (no `-nobrowse`) because Finder has to
    see it to script it, and the mount point is read back from `hdiutil` rather
    than assumed — a stale `/Volumes/Pulse` would push the new one to `Pulse 1`
    and the AppleScript would address the wrong disk.
  - Scripting Finder needs Automation consent for whatever runs `make dmg`.
- **Gotcha** (hit on Sottovoce, same machine): codesign can fail with "unable to
  build chain to self-signed root" + `errSecInternalComponent` when only the
  WWDR **G1** intermediate (expired 2023) is installed. Fix by adding
  https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer to the login
  keychain.

## Non-obvious decisions

- **No app icon.** Pulse is `LSUIElement`, so the only place an icon would show
  is the Finder/DMG listing; there has never been one and the bundle ships
  without `CFBundleIconFile`.
- **Font**: `AppFont` prefers "JetBrainsMono Nerd Font" if it happens to be
  installed and falls back to the system monospaced face. The font is *not*
  bundled — the menu bar item is expected to match the user's terminal.
