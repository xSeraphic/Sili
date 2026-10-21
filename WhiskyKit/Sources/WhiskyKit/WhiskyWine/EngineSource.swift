//
//  EngineSource.swift
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

/// Where the Wine engine ("Libraries.tar.gz") and its version manifest are downloaded from.
/// The original data.getwhisky.app server is offline, so the engine is published as a
/// GitHub Release asset on this fork. Rebuild it with `scripts/build-engine.sh`.
public enum EngineSource {
    /// GitHub "owner/repo" that hosts the engine release.
    public static let repository = "xSeraphic/Sili"
    /// Release tag that always points at the current engine build.
    public static let releaseTag = "engine"

    private static var releaseBase: String {
        "https://github.com/\(repository)/releases/download/\(releaseTag)"
    }

    public static var librariesURL: URL? {
        URL(string: "\(releaseBase)/Libraries.tar.gz")
    }

    public static var versionPlistURL: URL? {
        URL(string: "\(releaseBase)/WhiskyWineVersion.plist")
    }
}
