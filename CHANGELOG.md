# Changelog

All notable changes to Sili are listed here. Versions follow [Semantic Versioning](VERSIONING.md).

## [Unreleased]

Planned as **1.1.0** (minor: new feature, nothing breaking).

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
