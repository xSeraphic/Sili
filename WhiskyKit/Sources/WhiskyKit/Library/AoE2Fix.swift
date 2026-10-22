//
//  AoE2Fix.swift
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

/// Age of Empires II: Definitive Edition draws its gold menu text (button labels, player names) cut in half
/// under DXMT when it uses its default serif font. The game's own "Smooth Serif" font option draws correctly
/// and looks almost the same, so Sili turns it on in every profile in the bottle before launching.
///
/// Profiles are created on first launch, so the fix takes effect from the second launch onwards.
public enum AoE2Fix {
    public static let appID = 813780

    static let fontOff = Data("UseSmoothSerifFont:0".utf8)
    static let fontOn = Data("UseSmoothSerifFont:1".utf8)

    /// Turns on Smooth Serif in every AoE II profile in the bottle. Returns how many files changed.
    @discardableResult
    public static func apply(to bottle: Bottle) -> Int {
        profileFiles(in: bottle).reduce(0) { count, file in count + (fixProfile(at: file) ? 1 : 0) }
    }

    /// `drive_c/users/<user>/Games/Age of Empires 2 DE/<profile id>/profile/AdditionalOptions.aop`
    static func profileFiles(in bottle: Bottle) -> [URL] {
        let fileManager = FileManager.default
        let users = bottle.url.appending(path: "drive_c").appending(path: "users")
        let userDirs = (try? fileManager.contentsOfDirectory(at: users, includingPropertiesForKeys: nil)) ?? []
        return userDirs.flatMap { user -> [URL] in
            let game = user.appending(path: "Games").appending(path: "Age of Empires 2 DE")
            let ids = (try? fileManager.contentsOfDirectory(at: game, includingPropertiesForKeys: nil)) ?? []
            return ids.map { $0.appending(path: "profile").appending(path: "AdditionalOptions.aop") }
                .filter { fileManager.fileExists(atPath: $0.path(percentEncoded: false)) }
        }
    }

    /// The options file is raw-deflate-compressed text. Returns true if the file was changed.
    static func fixProfile(at url: URL) -> Bool {
        guard let compressed = try? Data(contentsOf: url),
              let text = try? (compressed as NSData).decompressed(using: .zlib) as Data,
              let range = text.range(of: fontOff) else { return false }
        var fixed = text
        fixed.replaceSubrange(range, with: fontOn)
        guard let output = try? (fixed as NSData).compressed(using: .zlib) as Data else { return false }
        return (try? output.write(to: url, options: .atomic)) != nil
    }
}
