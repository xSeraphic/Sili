//
//  GameLibrary.swift
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

/// A game shown in Sili's Library, found in one of the bottles.
public struct LibraryGame: Identifiable, Hashable, Sendable {
    public enum Source: Hashable, Sendable {
        /// Installed by Windows Steam inside the bottle.
        case steam(appID: Int, steamExecutable: URL)
        /// A program the user pinned in the bottle.
        case pinned(executable: URL)
    }

    public let id: String
    public let name: String
    public let source: Source
    public let bottleURL: URL
    public let bottleName: String
    /// Folder the game is installed in (Steam) or the executable's folder (pinned).
    public let installFolder: URL?
    /// Portrait artwork already cached on disk by Steam, if any.
    public let localArtwork: URL?
    public let sizeOnDisk: Int64?
    public let lastPlayed: Date?

    public var isSteam: Bool {
        if case .steam = source { return true }
        return false
    }

    public var steamAppID: Int? {
        if case .steam(let appID, _) = source { return appID }
        return nil
    }

    /// Steam's public portrait (600x900) artwork for the game.
    public var remoteArtwork: URL? {
        guard let appID = steamAppID else { return nil }
        return URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/library_600x900.jpg")
    }

    /// Steam's public landscape header, used when there is no portrait art.
    public var remoteHeader: URL? {
        guard let appID = steamAppID else { return nil }
        return URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/header.jpg")
    }
}

/// Finds games inside bottles: Steam installs (from `appmanifest_*.acf`) plus pinned programs.
public enum GameLibraryScanner {
    /// Steam app IDs that are tools or runtimes, not games.
    static let ignoredAppIDs: Set<Int> = [228980, 1070560, 1391110, 1628350, 1493710, 1826330, 2180100]
    static let ignoredNameFragments = ["Redistributable", "Steamworks Common", "Proton", "Steam Linux Runtime"]

    public static func scan(bottles: [Bottle]) -> [LibraryGame] {
        bottles
            .filter { $0.isAvailable }
            .flatMap { scan(bottle: $0) }
    }

    public static func scan(bottle: Bottle) -> [LibraryGame] {
        let steamGames = scanSteam(in: bottle)
        let steamFolders = steamGames.compactMap { $0.installFolder?.standardizedFileURL.path }
        let pinned = scanPins(in: bottle).filter { game in
            // Skip Steam itself and pins that point inside a Steam game we already list.
            guard let path = game.installFolder?.standardizedFileURL.path else { return true }
            if case .pinned(let exe) = game.source, exe.lastPathComponent.lowercased() == "steam.exe" {
                return false
            }
            return !steamFolders.contains { path.hasPrefix($0) }
        }
        return steamGames + pinned
    }

    // MARK: - Steam

    static func steamRoots(in bottle: Bottle) -> [URL] {
        let driveC = bottle.url.appending(path: "drive_c")
        return ["Program Files (x86)", "Program Files"]
            .map { driveC.appending(path: $0).appending(path: "Steam") }
            .filter {
                FileManager.default.fileExists(atPath: $0.appending(path: "steam.exe").path(percentEncoded: false))
            }
    }

    static func scanSteam(in bottle: Bottle) -> [LibraryGame] {
        var games: [LibraryGame] = []
        var seen: Set<Int> = []

        for root in steamRoots(in: bottle) {
            let steamExe = root.appending(path: "steam.exe")
            for steamapps in libraryFolders(steamRoot: root, bottle: bottle) {
                let files = (try? FileManager.default.contentsOfDirectory(
                    at: steamapps, includingPropertiesForKeys: nil
                )) ?? []
                for file in files where file.lastPathComponent.hasPrefix("appmanifest_")
                    && file.pathExtension == "acf" {
                    guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
                    let values = VDF.flatValues(text)
                    guard let appIDString = values["appid"], let appID = Int(appIDString),
                          let name = values["name"], !seen.contains(appID),
                          !ignoredAppIDs.contains(appID),
                          !ignoredNameFragments.contains(where: { name.contains($0) }) else { continue }
                    // StateFlags bit 4 = fully installed
                    if let flags = values["stateflags"].flatMap(Int.init), flags & 4 == 0 { continue }
                    seen.insert(appID)

                    let installDir = values["installdir"].map {
                        steamapps.appending(path: "common").appending(path: $0)
                    }
                    games.append(LibraryGame(
                        id: "steam-\(appID)-\(bottle.url.path)",
                        name: name,
                        source: .steam(appID: appID, steamExecutable: steamExe),
                        bottleURL: bottle.url,
                        bottleName: bottle.settings.name,
                        installFolder: installDir,
                        localArtwork: localArtwork(appID: appID, steamRoot: root),
                        sizeOnDisk: values["sizeondisk"].flatMap(Int64.init),
                        lastPlayed: values["lastplayed"].flatMap(TimeInterval.init)
                            .flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
                    ))
                }
            }
        }
        return games
    }

    /// The main `steamapps` folder plus any extra libraries listed in `libraryfolders.vdf`.
    static func libraryFolders(steamRoot: URL, bottle: Bottle) -> [URL] {
        let main = steamRoot.appending(path: "steamapps")
        var folders = [main]
        let vdfURL = main.appending(path: "libraryfolders.vdf")
        if let text = try? String(contentsOf: vdfURL, encoding: .utf8) {
            for windowsPath in VDF.allValues(forKey: "path", in: text) {
                guard let folder = macURL(forWindowsPath: windowsPath, bottle: bottle)?
                        .appending(path: "steamapps") else { continue }
                if !folders.contains(where: { $0.standardizedFileURL == folder.standardizedFileURL }) {
                    folders.append(folder)
                }
            }
        }
        return folders.filter { FileManager.default.fileExists(atPath: $0.path(percentEncoded: false)) }
    }

    /// Converts `C:\Program Files (x86)\Steam` style paths to the matching folder on the Mac.
    static func macURL(forWindowsPath path: String, bottle: Bottle) -> URL? {
        let cleaned = path.replacingOccurrences(of: "\\\\", with: "\\")
        guard cleaned.count >= 2, cleaned.dropFirst().first == ":" else { return nil }
        let letter = cleaned.prefix(1).lowercased()
        let rest = cleaned.dropFirst(2).split(separator: "\\").map(String.init)
        let device = bottle.url.appending(path: "dosdevices").appending(path: "\(letter):")
        let base = (try? FileManager.default.destinationOfSymbolicLink(atPath: device.path(percentEncoded: false)))
            .map { URL(fileURLWithPath: $0, relativeTo: device.deletingLastPathComponent()).standardizedFileURL }
            ?? (letter == "c" ? bottle.url.appending(path: "drive_c") : nil)
        return rest.reduce(base) { $0?.appending(path: $1) }
    }

    /// Steam caches library artwork under `appcache/librarycache`. Layout varies between client versions.
    static func localArtwork(appID: Int, steamRoot: URL) -> URL? {
        let cache = steamRoot.appending(path: "appcache").appending(path: "librarycache")
        let flat = cache.appending(path: "\(appID)_library_600x900.jpg")
        if FileManager.default.fileExists(atPath: flat.path(percentEncoded: false)) { return flat }

        let folder = cache.appending(path: "\(appID)")
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else {
            return nil
        }
        while let file = enumerator.nextObject() as? URL {
            if file.lastPathComponent.hasPrefix("library_600x900") { return file }
        }
        return nil
    }

    // MARK: - Pinned programs

    static func scanPins(in bottle: Bottle) -> [LibraryGame] {
        bottle.settings.pins.compactMap { pin in
            guard let exe = pin.url,
                  FileManager.default.fileExists(atPath: exe.path(percentEncoded: false)) else { return nil }
            return LibraryGame(
                id: "pin-\(exe.path)",
                name: pin.name,
                source: .pinned(executable: exe),
                bottleURL: bottle.url,
                bottleName: bottle.settings.name,
                installFolder: exe.deletingLastPathComponent(),
                localArtwork: nil,
                sizeOnDisk: nil,
                lastPlayed: nil
            )
        }
    }
}

/// Minimal reader for Valve's KeyValues (VDF/ACF) text format.
enum VDF {
    private static let pair = try? NSRegularExpression(pattern: #""([^"]+)"\s+"((?:[^"\\]|\\.)*)""#)

    /// Every quoted key/value pair, keys lowercased. Later duplicates are ignored.
    static func flatValues(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in pairs(text) where result[key] == nil {
            result[key] = value
        }
        return result
    }

    static func allValues(forKey key: String, in text: String) -> [String] {
        pairs(text).filter { $0.0 == key.lowercased() }.map(\.1)
    }

    private static func pairs(_ text: String) -> [(String, String)] {
        guard let pair else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return pair.matches(in: text, range: range).compactMap { match in
            guard let keyRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text) else { return nil }
            return (String(text[keyRange]).lowercased(), String(text[valueRange]))
        }
    }
}
