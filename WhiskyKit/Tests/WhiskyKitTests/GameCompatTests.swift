//
//  GameCompatTests.swift
//  WhiskyKitTests
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation
import Testing
@testable import WhiskyKit

@Suite("Per-game fixes")
struct GameCompatTests {
    @Test func aoe2ProfileGetsSmoothSerifFont() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "sili-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let bottle = Bottle(bottleUrl: root, isAvailable: true)
        let profile = root.appending(path: "drive_c/users/crossover/Games/Age of Empires 2 DE/123/profile")
        try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
        let file = profile.appending(path: "AdditionalOptions.aop")
        let text = Data("UseSansSerifFont:0\u{0}UseSmoothSerifFont:0\u{0}ZoomToCursor:1".utf8)
        try (text as NSData).compressed(using: .zlib).write(to: file)

        #expect(AoE2Fix.apply(to: bottle) == 1)
        let result = try (Data(contentsOf: file) as NSData).decompressed(using: .zlib) as Data
        #expect(result == Data("UseSansSerifFont:0\u{0}UseSmoothSerifFont:1\u{0}ZoomToCursor:1".utf8))
        // Already fixed: nothing more to do.
        #expect(AoE2Fix.apply(to: bottle) == 0)
    }

    @Test func gameDllOverridesAreAddedToEngineDefaults() {
        let env = EngineEnvironment.merged(["WINEPREFIX": "/x"],
                                           with: ["WINEDLLOVERRIDES": "gameoverlayrenderer=", "A": "1"])
        #expect(env["WINEDLLOVERRIDES"] == "gameoverlayrenderer=;mscoree,mshtml=;winemenubuilder.exe=d")
        #expect(env["A"] == "1")
        #expect(env["WINEPREFIX"] == "/x")
    }

    @Test func launchGuardIgnoresQuickRepeats() {
        let guardian = LaunchGuard()
        let start = Date()
        #expect(guardian.shouldLaunch("steam.exe", now: start))
        #expect(!guardian.shouldLaunch("steam.exe", now: start.addingTimeInterval(1)))
        #expect(guardian.shouldLaunch("game.exe", now: start.addingTimeInterval(1)))
        #expect(guardian.shouldLaunch("steam.exe", now: start.addingTimeInterval(LaunchGuard.interval + 1)))
    }

    @Test func parsesSteamActiveUser() {
        let signedIn = "HKEY_CURRENT_USER\\Software\\Valve\\Steam\\ActiveProcess\n"
            + "    ActiveUser    REG_DWORD    0x4fb16a2\n"
        #expect(SteamLauncher.activeUser(fromRegOutput: signedIn) == 0x4fb16a2)
        #expect(SteamLauncher.activeUser(fromRegOutput: "    ActiveUser    REG_DWORD    0x0") == 0)
        #expect(SteamLauncher.activeUser(fromRegOutput: "ERROR: Unable to find the specified registry value") == nil)
    }

    @Test func knownGamesHaveFixes() {
        #expect(GameCompat.steam[AoE2Fix.appID]?.executable == "AoE2DE_s.exe")
        #expect(GameCompat.steam[266840]?.environment["WINE_D3D_CONFIG"] == "renderer=vulkan")
    }
}
