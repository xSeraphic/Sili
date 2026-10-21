//
//  GameLibraryTests.swift
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

@Suite("Game library scanning")
struct GameLibraryTests {
    let root: URL
    let bottle: Bottle

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "sili-tests-\(UUID().uuidString)")
        let bottleURL = root.appending(path: "Bottle")
        try FileManager.default.createDirectory(at: bottleURL, withIntermediateDirectories: true)
        bottle = Bottle(bottleUrl: bottleURL, isAvailable: true)
        bottle.settings.name = "Steam"
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func manifest(id: Int, name: String, dir: String, flags: Int = 4, lastPlayed: Int = 0) -> String {
        """
        "AppState"
        {
        \t"appid"\t\t"\(id)"
        \t"name"\t\t"\(name)"
        \t"StateFlags"\t\t"\(flags)"
        \t"installdir"\t\t"\(dir)"
        \t"LastPlayed"\t\t"\(lastPlayed)"
        \t"SizeOnDisk"\t\t"1234"
        }
        """
    }

    @Test func parsesVDF() {
        let values = VDF.flatValues(manifest(id: 220, name: "Half-Life 2", dir: "Half-Life 2"))
        #expect(values["appid"] == "220")
        #expect(values["name"] == "Half-Life 2")
        #expect(values["stateflags"] == "4")
    }

    @Test func findsInstalledSteamGamesAndSkipsToolsAndPartialInstalls() throws {
        let steam = bottle.url.appending(path: "drive_c/Program Files (x86)/Steam")
        try write("", to: steam.appending(path: "steam.exe"))
        let apps = steam.appending(path: "steamapps")
        try write(manifest(id: 220, name: "Half-Life 2", dir: "Half-Life 2", lastPlayed: 1_700_000_000),
                  to: apps.appending(path: "appmanifest_220.acf"))
        try write(manifest(id: 228980, name: "Steamworks Common Redistributables", dir: "Steamworks Shared"),
                  to: apps.appending(path: "appmanifest_228980.acf"))
        try write(manifest(id: 570, name: "Dota 2", dir: "dota 2 beta", flags: 1026),
                  to: apps.appending(path: "appmanifest_570.acf"))

        // A second library on D:, mapped through dosdevices like Wine does
        let external = root.appending(path: "External")
        try write(manifest(id: 400, name: "Portal", dir: "Portal"),
                  to: external.appending(path: "Games/steamapps/appmanifest_400.acf"))
        let dosdevices = bottle.url.appending(path: "dosdevices")
        try FileManager.default.createDirectory(at: dosdevices, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: dosdevices.appending(path: "d:"), withDestinationURL: external)
        try write("""
        "libraryfolders"
        {
        \t"0" { "path" "C:\\\\Program Files (x86)\\\\Steam" }
        \t"1" { "path" "D:\\\\Games" }
        }
        """, to: apps.appending(path: "libraryfolders.vdf"))

        let games = GameLibraryScanner.scan(bottle: bottle).sorted { $0.name < $1.name }
        #expect(games.map(\.name) == ["Half-Life 2", "Portal"])
        #expect(games[0].steamAppID == 220)
        #expect(games[0].installFolder?.lastPathComponent == "Half-Life 2")
        #expect(games[0].lastPlayed == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(games[0].bottleName == "Steam")
        #expect(games[1].installFolder?.path(percentEncoded: false).contains("External/Games/steamapps/common") == true)
        #expect(games[0].remoteArtwork?.absoluteString.hasSuffix("/220/library_600x900.jpg") == true)
    }

    @Test func listsPinnedProgramsButNotSteamItself() throws {
        let game = bottle.url.appending(path: "drive_c/Games/Cool Game/cool.exe")
        let steamExe = bottle.url.appending(path: "drive_c/Program Files (x86)/Steam/steam.exe")
        try write("", to: game)
        try write("", to: steamExe)
        bottle.settings.pins = [PinnedProgram(name: "Cool Game", url: game),
                                PinnedProgram(name: "Steam", url: steamExe)]

        let names = GameLibraryScanner.scan(bottle: bottle).map(\.name)
        #expect(names == ["Cool Game"])
    }

    @Test func appliesKnownGameWorkarounds() throws {
        let steam = bottle.url.appending(path: "drive_c/Program Files (x86)/Steam")
        try write("", to: steam.appending(path: "steam.exe"))
        try write(manifest(id: 12120, name: "Grand Theft Auto: San Andreas", dir: "GTA San Andreas"),
                  to: steam.appending(path: "steamapps/appmanifest_12120.acf"))
        let exe = steam.appending(path: "steamapps/common/GTA San Andreas/gta-sa.exe")
        try write("", to: exe)

        let game = try #require(GameLibraryScanner.scan(bottle: bottle).first)
        let direct = try #require(GameCompat.forGame(game))
        #expect(direct.executable.lastPathComponent == "gta-sa.exe")
        #expect(direct.compat.environment["WINE_CPU_TOPOLOGY"] == "2:0,1")
        #expect(GameCompat.byExecutable["gta-sa.exe"] != nil)

        GameCompat.prepareDirectLaunch(appID: 12120, executable: direct.executable)
        let appid = try String(contentsOf: exe.deletingLastPathComponent().appending(path: "steam_appid.txt"),
                               encoding: .utf8)
        #expect(appid == "12120")
    }

    @Test func skipsWorkaroundWhenExecutableIsMissing() throws {
        let steam = bottle.url.appending(path: "drive_c/Program Files (x86)/Steam")
        try write("", to: steam.appending(path: "steam.exe"))
        try write(manifest(id: 12120, name: "Grand Theft Auto: San Andreas", dir: "GTA San Andreas"),
                  to: steam.appending(path: "steamapps/appmanifest_12120.acf"))
        let game = try #require(GameLibraryScanner.scan(bottle: bottle).first)
        #expect(GameCompat.forGame(game) == nil)
    }

    @Test func mapsWindowsPathsToBottleFolders() {
        let url = GameLibraryScanner.macURL(forWindowsPath: "C:\\Program Files\\Steam", bottle: bottle)
        #expect(url?.path(percentEncoded: false).hasSuffix("Bottle/drive_c/Program Files/Steam") == true)
        #expect(GameLibraryScanner.macURL(forWindowsPath: "not a path", bottle: bottle) == nil)
    }
}
