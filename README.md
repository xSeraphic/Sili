<div align="center">

  <img src="Resources/sili-icon.png" width="128" alt="Sili icon">

  # Sili 🌶️
  *Run Windows games and apps on your Apple Silicon Mac, for free*

</div>

Sili is a free, open-source macOS app for running Windows software (including Steam and Steam games) on Apple Silicon Macs. It gives you a native SwiftUI interface for creating and managing "bottles" (separate Windows environments) on top of [Wine](https://www.winehq.org), with no Terminal work needed.

The name comes from *sili*, the chilli at the heart of Bicolano cooking. It's small, quick and a bit fiery.

> **Status: personal project, in development.** Sili is a work in progress used in-house at Mayon Studios. It isn't offered for general use yet, and builds may change or break without notice.

> **Sili is a fork of [Whisky](https://github.com/Whisky-App/Whisky)** by Isaac Marovitz and contributors. Whisky stopped being maintained in 2025, and its engine download server has since gone offline, so new installs no longer work. Sili continues the project with a current Wine engine and new features. See [Credits](#credits--acknowledgments).

---

## What's different from Whisky

- **Working engine download.** The engine is now hosted on this repo's [`engine` release](https://github.com/xSeraphic/Sili/releases/tag/engine) instead of the offline `data.getwhisky.app` server.
- **CrossOver-source engine.** Sili Engine 4 is Wine built from CodeWeavers' open-source [CrossOver 26.3](https://media.codeweavers.com/pub/crossover/source/) code (Wine 11.0), so games that need CrossOver's Mac fixes work. Examples are Age of Empires II: DE and Age of Mythology: EE.
- **DirectX 10/11 to Metal** through [DXMT](https://github.com/3Shain/dxmt), with [DXVK](https://github.com/Gcenx/DXVK-macOS) and [MoltenVK](https://github.com/KhronosGroup/MoltenVK) available.
- **Steam that works.** Sili fixes Steam's black window automatically (`tools/webhelper-wrapper.c`).
- **Game Library** of everything installed across bottles, with Steam cover art.
- **Reproducible engine builds.** See `scripts/build-engine.sh`.
- **New name, icon and bundle ID** (`com.mayonstudios.sili`), so Sili doesn't clash with an existing Whisky install.

## How Sili is made

Sili is maintained by Rhyss ([xSeraphic](https://github.com/xSeraphic)) at Mayon Studios and developed with AI assistance from [Claude](https://claude.ai) by Anthropic. Rhyss sets the direction, tests games and decides what ships, and Claude writes much of the code.

Most of what makes Sili work comes from other people's open-source projects: Whisky, Wine, CodeWeavers' open-source CrossOver code, DXMT, DXVK and MoltenVK. See [Credits](#credits--acknowledgments). If Sili is useful to you, please consider supporting those projects too.

## System requirements

- Apple Silicon Mac (M1 or later)
- macOS Sonoma 14.0 or later
- Rosetta 2 (`softwareupdate --install-rosetta`)

## Building from source

1. Install Xcode and SwiftLint: `brew install swiftlint`
2. Clone the repo, then build:

   ```sh
   git clone https://github.com/xSeraphic/Sili.git
   cd Sili
   xcodebuild -project Whisky.xcodeproj -scheme Whisky -configuration Release \
     -derivedDataPath ../Sili-build \
     CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= ENABLE_HARDENED_RUNTIME=NO build
   ```

3. The app is at `../Sili-build/Build/Products/Release/Sili.app`.

Keep `-derivedDataPath` outside the repo, otherwise SwiftLint will try to lint the build output. Internal module and target names (`WhiskyKit`, `WhiskyCmd`, the `Whisky` scheme) are kept from upstream for now.

### Rebuilding the Wine engine

Build the CrossOver-source Wine with [steam-wine](https://github.com/willburnsucla/steam-wine)'s `scripts/build-all.sh`, then:

```sh
scripts/build-engine.sh 4.0.0
gh release upload engine-4 dist/Libraries.tar.gz dist/WhiskyWineVersion.plist --clobber
```

Raising the engine version makes existing installs offer the update.

## Game compatibility

Not every game works. Games with kernel-level anti-cheat (Vanguard, some Easy Anti-Cheat and BattlEye setups) won't run under Wine on any Mac. Before trying a game, check [AppleGamingWiki](https://www.applegamingwiki.com) or the [CodeWeavers compatibility database](https://www.codeweavers.com/compatibility). Ratings for CrossOver are a good guide, because Sili is built on the same underlying technology.

---

### Tested with Sili

Tested on an M4 Max MacBook Pro (macOS 27) with Sili Engine 4.

| Game | Result | Notes |
| --- | --- | --- |
| Age of Empires II: DE | Works | Uses DXMT. Sili fixes its menu text automatically. |
| Age of Mythology: EE | Works | Sili switches it to Vulkan and turns off the Steam overlay for smoother play. |
| Grand Theft Auto: San Andreas | Works | Sili limits it to 2 CPU cores so it doesn't hang at startup. |
| Castle Crashers | Works | |
| Doki Doki Literature Club! | Works | |
| Emily Wants To Play | Works | Unreal Engine 4, DirectX 11. Steam asks which launch option to use the first time. |
| Rustbucket Rumble | Works | Steam asks you to accept the game's EULA the first time. |
| Scribblenauts Unlimited | Works | Takes about a minute to start. On ultrawide screens the bottom of the main menu is cut off. |

## Credits & Acknowledgments

Sili is built on the work of these projects and people:

- **[Whisky](https://github.com/Whisky-App/Whisky)** by [Isaac Marovitz](https://github.com/IsaacMarovitz) and [all Whisky contributors](https://github.com/Whisky-App/Whisky/graphs/contributors). The app, its UI, WhiskyKit and WhiskyCmd all come from Whisky. Copyright notices in the source files are kept as required by the GPL.
- **[Wine](https://www.winehq.org)**, the compatibility layer that makes any of this possible.
- **[CodeWeavers](https://www.codeweavers.com)**, for publishing CrossOver's Wine source under the LGPL. Sili Engine 4 is built from it. Sili is not CrossOver and isn't endorsed by CodeWeavers. If Sili is useful to you, consider supporting them by buying CrossOver.
- **[steam-wine](https://github.com/willburnsucla/steam-wine)** by willburnsucla (LGPL-2.1+), whose scripts build the CrossOver-source Wine, DXMT, DXVK and MoltenVK for Sili Engine 4.
- **[macOS Wine builds](https://github.com/Gcenx/macOS_Wine_builds)** by Gcenx, which provide the Wine Staging engine.
- **[DXMT](https://github.com/3Shain/dxmt)** by 3Shain, which translates DirectX 10/11 to Metal.
- **[DXVK-macOS](https://github.com/Gcenx/DXVK-macOS)** by Gcenx and doitsujin, and **[MoltenVK](https://github.com/KhronosGroup/MoltenVK)** by the Khronos Group, both used by Whisky.
- **[msync](https://github.com/marzent/wine-msync)** by marzent.
- **[Sparkle](https://github.com/sparkle-project/Sparkle)**, **[SemanticVersion](https://github.com/SwiftPackageIndex/SemanticVersion)**, **[swift-argument-parser](https://github.com/apple/swift-argument-parser)**, **[Progress.swift](https://github.com/jkandzi/Progress.swift)** and **[SwiftyTextTable](https://github.com/scottrhoyt/SwiftyTextTable)**.
- Whisky's translations were contributed through [Crowdin](https://crowdin.com/project/whisky).

Sili is not affiliated with or endorsed by the Whisky project, WineHQ or CodeWeavers.

## License

Sili is free software, released under the **[GNU General Public License v3.0](LICENSE)**, the same licence as Whisky. You can use, change and share it under the same terms. Any modified versions must also be open source under the GPLv3.

Bundled engine components are distributed under their own licences. Wine and CrossOver's Wine are LGPL-2.1+; DXMT, DXVK and MoltenVK are under their own licences. The exact sources for each engine build are linked from its GitHub release:
- [crossover-sources-26.3.0.tar.gz](https://media.codeweavers.com/pub/crossover/source/crossover-sources-26.3.0.tar.gz)
- the [steam-wine](https://github.com/willburnsucla/steam-wine) patches and build scripts

Maintained by [xSeraphic](https://github.com/xSeraphic) · Mayon Studios
