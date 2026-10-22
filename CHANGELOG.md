# Changelog

All notable changes to Sili are listed here. Versions follow [Semantic Versioning](VERSIONING.md).

## [Unreleased]

## [1.2.1] - 2026-10-22

Patch release: per-game fixes for Age of Empires II: DE and Age of Mythology: EE.

### Fixed
- **Age of Empires II: DE:** gold menu text (button labels, player names) was cut in half. Sili now
  switches the game to its "Smooth Serif" font, which draws correctly and looks almost the same.
  Applies from the second launch, since the game creates its settings on the first one.
- **Age of Mythology: EE:** much less stutter. The game now draws through Vulkan (MoltenVK) instead of
  macOS's OpenGL, and the Steam overlay, which caused heavy stutter under Wine, is turned off for it.
- Per-game DLL overrides no longer replace Sili's default overrides.

## [1.2.0] - 2026-10-22

Minor release: a new engine and several fixes. Nothing breaking. Existing bottles move to the new engine
automatically, and Steam may ask you to sign in again once.

### Added
- **Sili Engine 4.0**: Wine built from CodeWeavers' open-source CrossOver 26.3 code (Wine 11.0),
  with DXMT, DXVK and MoltenVK. It handles games that make direct Windows system calls, plus many
  Mac-specific fixes. Age of Empires II: DE and Age of Mythology: EE (Windows versions) now reach
  their main menus. Both crashed or froze on engine 3.x.
- **Steam black-window fix, applied automatically.** Steam's built-in browser is wrapped so it
  draws in one process, and the fix is reapplied after every Steam self-update.
- **Settings > Graphics:** switch DirectX 10/11 between DXMT (default) and Wine's own WineD3D.
- **Per-game fixes:**
  - GTA San Andreas is limited to 2 CPU cores (it hangs at startup on many-core Macs).
  - Known games launch directly, skipping Steam's launch-options dialog, which doesn't render under Wine.
- **Double-launch guard:** Play in the Library ignores repeat clicks for 20 seconds.

### Changed
- Engine downloads now come from the `engine-4` release. Sili 1.1.x stays on engine 3.x.
- Wine Mono/Gecko install prompts are skipped (they hung bottle setup), and Wine no longer adds Mac
  menu entries for installed programs.

### Fixed
- Bottle creation hanging on the Wine Mono prompt.
- Steam's window staying black.

## [1.1.0] - 2026-10-21

### Added
- **Game Library**: a new sidebar section showing every game across all bottles in one grid.
  - Finds Windows Steam games automatically (including extra Steam library folders on other drives) plus pinned programs.
  - Cover art from Steam's local cache, then Steam's CDN, then the program's own icon.
  - Hover to Play, or double-click. Steam games launch through the bottle's Steam (`steam://rungameid/`).
  - Search, sort by name, recently played or bottle, and right-click to Show in Finder, Open Bottle or Create Dock Shortcut.
- Dock shortcuts for Steam games, with the game's cover art as the icon.
- Unit tests for the library scanner (`swift test` in `WhiskyKit`).

### Changed
- WhiskyKit now fetches SemanticVersion over HTTPS instead of SSH, so it builds without GitHub SSH keys.

## [1.0.0] - 2026-10-21

The first release of Sili, a maintained fork of [Whisky](https://github.com/Whisky-App/Whisky).

### Added
- Sili name, glossy chilli app icon and bundle ID (`com.mayonstudios.sili`).
- Automatic app updates through Sparkle, signed with Sili's own key.
- `scripts/build-engine.sh` to build the Wine engine from upstream releases.
- `scripts/release.sh` to version, build, sign and publish releases.

### Changed
- Wine engine updated to Wine Staging 11.18 (from a 2022 CrossOver 22-based build).
- DirectX 10/11 games now go through DXMT (Direct3D to Metal).
- The engine now downloads from this repo's `engine` release instead of the offline `data.getwhisky.app`.
- The command-line tool is now `sili`.

### Fixed
- First-run setup failing because the original engine server is offline.
- Wine 9+ compatibility: use the unified `wine` loader instead of `wine64`.
- Crash at launch for self-built copies: ad-hoc builds now turn off hardened runtime so the embedded Sparkle framework loads.
