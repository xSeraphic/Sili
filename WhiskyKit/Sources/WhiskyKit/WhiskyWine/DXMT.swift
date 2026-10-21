//
//  DXMT.swift
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

/// Switches the engine's Direct3D 10/11 between Wine's own implementation (WineD3D) and DXMT (Direct3D to Metal).
///
/// DXMT is a "builtin" Wine DLL set, so it has to live in Wine's own `lib/wine` folder; it can't be enabled
/// per bottle. The engine ships both sets under `Libraries/WineD3D` and `Libraries/DXMT`, and this copies the
/// chosen set into place. DXMT is the default (it's faster and more games start with it, e.g. Age of Empires II DE
/// crashes under WineD3D); users can switch to WineD3D in Settings for games that misbehave.
public enum DXMT {
    static let dlls = ["d3d11.dll", "dxgi.dll", "d3d10core.dll"]
    static let arches = ["x86_64-windows", "i386-windows"]

    static var dxmtFolder: URL { WhiskyWineInstaller.libraryFolder.appending(path: "DXMT") }
    static var wineD3DFolder: URL { WhiskyWineInstaller.libraryFolder.appending(path: "WineD3D") }
    static var wineLibFolder: URL {
        WhiskyWineInstaller.libraryFolder.appending(path: "Wine").appending(path: "lib").appending(path: "wine")
    }

    /// True when the installed engine includes both DLL sets (engine 3.1.0 and later).
    public static var isAvailable: Bool {
        arches.allSatisfy { arch in
            dlls.allSatisfy { dll in
                exists(dxmtFolder.appending(path: arch).appending(path: dll))
                    && exists(wineD3DFolder.appending(path: arch).appending(path: dll))
            }
        }
    }

    /// Whether the DLLs currently in Wine's lib folder are DXMT's.
    public static var isEnabled: Bool {
        let active = wineLibFolder.appending(path: "x86_64-windows").appending(path: "d3d11.dll")
        let dxmt = dxmtFolder.appending(path: "x86_64-windows").appending(path: "d3d11.dll")
        guard let activeData = try? Data(contentsOf: active), let dxmtData = try? Data(contentsOf: dxmt) else {
            return false
        }
        return activeData == dxmtData
    }

    /// Copies the chosen DLL set into Wine's lib folder. Running games should be closed first.
    public static func setEnabled(_ enabled: Bool) throws {
        let source = enabled ? dxmtFolder : wineD3DFolder
        for arch in arches {
            for dll in dlls {
                let from = source.appending(path: arch).appending(path: dll)
                let destination = wineLibFolder.appending(path: arch).appending(path: dll)
                if exists(destination) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: from, to: destination)
            }
        }
    }

    /// DXMT's Direct3D DLLs load `winemetal.dll`, which has to be in the bottle's Windows folders too.
    public static func prepare(bottle: Bottle) {
        guard isEnabled else { return }
        let windows = bottle.url.appending(path: "drive_c").appending(path: "windows")
        for (arch, folder) in [("x86_64-windows", "system32"), ("i386-windows", "syswow64")] {
            let source = wineLibFolder.appending(path: arch).appending(path: "winemetal.dll")
            let destination = windows.appending(path: folder).appending(path: "winemetal.dll")
            guard exists(source), exists(destination.deletingLastPathComponent()) else { continue }
            if let have = try? Data(contentsOf: destination), let want = try? Data(contentsOf: source), have == want {
                continue
            }
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.copyItem(at: source, to: destination)
        }
    }

    private static func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
}
