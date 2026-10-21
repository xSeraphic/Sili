//
//  GameCompat.swift
//  WhiskyKit
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

/// Per-game workarounds that Sili applies automatically.
public struct GameCompat: Sendable, Equatable {
    /// The game's main executable, relative to its install folder.
    public let executable: String
    /// Extra environment variables for the game process.
    public let environment: [String: String]
    /// Short explanation shown in logs and docs.
    public let reason: String

    /// Known games, keyed by Steam app ID.
    public static let steam: [Int: GameCompat] = [
        // The classic PC port spins forever at startup on CPUs with many cores.
        12120: GameCompat(executable: "gta-sa.exe",
                          environment: ["WINE_CPU_TOPOLOGY": "2:0,1"],
                          reason: "Hangs at startup with many CPU cores; limit to 2."),
        // Steam shows a launch-options dialog for this game, which doesn't render under Wine on macOS.
        // Launching the game executable directly skips it.
        266840: GameCompat(executable: "AoMX.exe",
                           environment: [:],
                           reason: "Skip Steam's launch-options dialog.")
    ]

    /// Workarounds keyed by executable file name (lowercased), for pinned programs.
    public static var byExecutable: [String: GameCompat] {
        Dictionary(steam.values.map { ($0.executable.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// The workaround for a library game, if any, with the full path to its executable.
    public static func forGame(_ game: LibraryGame) -> (compat: GameCompat, executable: URL)? {
        guard let appID = game.steamAppID, let compat = steam[appID], let folder = game.installFolder else {
            return nil
        }
        let exe = folder.appending(path: compat.executable)
        guard FileManager.default.fileExists(atPath: exe.path(percentEncoded: false)) else { return nil }
        return (compat, exe)
    }

    /// Writes `steam_appid.txt` next to the executable so a Steamworks game can start without being
    /// relaunched through the Steam client (which would show dialogs Wine can't render).
    public static func prepareDirectLaunch(appID: Int, executable: URL) {
        let file = executable.deletingLastPathComponent().appending(path: "steam_appid.txt")
        guard !FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else { return }
        try? "\(appID)".write(to: file, atomically: true, encoding: .utf8)
    }
}
