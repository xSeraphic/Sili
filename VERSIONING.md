# Versioning

Sili uses [Semantic Versioning](https://semver.org): **MAJOR.MINOR.PATCH**, for example `1.4.2`.

| Part | Bump when… | Examples |
|---|---|---|
| **MAJOR** (`1.x.x` → `2.0.0`) | A big overhaul, or anything that breaks existing setups | A new bottle format that old bottles must be migrated to, a redesigned UI, removing a feature, a new engine generation that needs bottles recreated |
| **MINOR** (`1.0.x` → `1.1.0`) | A new feature that doesn't break anything | One-click Steam bottle, D3DMetal support, a new settings panel |
| **PATCH** (`1.0.0` → `1.0.1`) | Bug fixes and small tweaks only | Fixing a crash, text and typo fixes, a small engine bump with no behaviour change |

Rules:

- When MINOR goes up, PATCH resets to 0 (`1.2.7` → `1.3.0`). When MAJOR goes up, both reset (`1.3.0` → `2.0.0`).
- Numbers don't roll over at 10. `1.9.0` is followed by `1.10.0`, not `2.0.0`.
- Pick the bump from the biggest change in the release. A release with one feature and five bug fixes is a MINOR bump.
- Every release gets a section in [CHANGELOG.md](CHANGELOG.md).

## Build number

Alongside the visible version there's a **build number** (`CURRENT_PROJECT_VERSION`, shown as `CFBundleVersion`). It goes up by 1 with every release and never goes back. Sparkle uses it to decide whether an update is newer. `scripts/release.sh` bumps it automatically.

## Engine version

The Wine engine has its own version in `WhiskyWineVersion.plist`, separate from the app version. Engine 4.x (CrossOver-source Wine) is published on the `engine-4` release. Engine 3.x (Wine Staging) stays on `engine` for Sili 1.1.x. A new engine major version gets a new release tag, so older apps aren't moved onto an engine they weren't built for. Bump it with `scripts/build-engine.sh` whenever the engine changes. Installed copies of Sili then offer the new engine.

## How to release

1. Add a `## [x.y.z] - YYYY-MM-DD` section to `CHANGELOG.md` and commit it.
2. Run `scripts/release.sh x.y.z` from a clean `main` branch.

The script sets the version, builds and signs `Sili.app`, writes the Sparkle `appcast.xml`, then tags, pushes and publishes the GitHub release. Installed copies of Sili pick up the update automatically.
