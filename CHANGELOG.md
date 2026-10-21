# Changelog

All notable changes to Sili are listed here. Versions follow [Semantic Versioning](VERSIONING.md).

## [Unreleased]

## [1.0.0] - 2026-10-21

The first release of Sili, a maintained fork of [Whisky](https://github.com/Whisky-App/Whisky).

### Added
- Sili name, chilli icon and bundle ID (`com.mayonstudios.sili`).
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
