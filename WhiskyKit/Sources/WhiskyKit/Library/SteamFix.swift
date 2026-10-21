//
//  SteamFix.swift
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

/// Keeps Windows Steam usable under Wine on macOS.
///
/// Steam's UI (`steamwebhelper.exe`, Chromium) draws from a separate GPU process into a window owned by
/// another process, which Wine's macOS driver can't display, so the Steam window stays black. The engine
/// ships a small wrapper (`Libraries/Tools/steamwebhelper-wrapper.exe`, source in `tools/`) that starts
/// the real helper in single-process mode. Steam restores the original helper when it updates itself,
/// so this is re-applied before every launch.
public enum SteamFix {
    static var wrapper: URL {
        WhiskyWineInstaller.libraryFolder.appending(path: "Tools").appending(path: "steamwebhelper-wrapper.exe")
    }

    static func cefFolder(_ steamRoot: URL) -> URL {
        steamRoot.appending(path: "bin").appending(path: "cef").appending(path: "cef.win64")
    }

    /// Whether Steam in this root has finished its first-run self-update (the browser exists).
    static func isBootstrapped(_ steamRoot: URL) -> Bool {
        exists(cefFolder(steamRoot).appending(path: "steamwebhelper.exe"))
            || exists(cefFolder(steamRoot).appending(path: "steamwebhelper_real.exe"))
    }

    /// Installs the wrapper in every Steam install in the bottle, if it isn't already in place.
    public static func apply(to bottle: Bottle) {
        guard let wrapperData = try? Data(contentsOf: wrapper) else { return }
        for root in GameLibraryScanner.steamRoots(in: bottle) {
            let folder = cefFolder(root)
            let helper = folder.appending(path: "steamwebhelper.exe")
            let real = folder.appending(path: "steamwebhelper_real.exe")
            guard let helperData = try? Data(contentsOf: helper), helperData != wrapperData else { continue }
            do {
                // `helper` is Steam's real browser (fresh install, or an update restored it).
                if exists(real) { try FileManager.default.removeItem(at: real) }
                try FileManager.default.moveItem(at: helper, to: real)
                try wrapperData.write(to: helper)
            } catch {
                print("SteamFix: couldn't install the webhelper wrapper: \(error)")
            }
        }
    }

    /// Extra arguments for launching `steam.exe`: once Steam is set up, stop it verifying its files on
    /// launch, which would put the original browser back.
    static func extraArguments(for program: URL, args: [String]) -> [String] {
        guard program.lastPathComponent.lowercased() == "steam.exe", !args.contains("-noverifyfiles"),
              isBootstrapped(program.deletingLastPathComponent()) else { return [] }
        return ["-noverifyfiles"]
    }

    private static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}
