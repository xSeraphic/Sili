//
//  EngineEnvironment.swift
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

/// Environment and pre-launch setup that Sili Engine 4.x needs on top of Whisky's defaults.
enum EngineEnvironment {
    static func apply(to env: inout [String: String]) {
        // The engine bundles its own dylibs (GnuTLS, FreeType, MoltenVK) next to Wine; Wine loads some of
        // them by leaf name, so make sure dyld can find them.
        env["DYLD_FALLBACK_LIBRARY_PATH"] = WhiskyWineInstaller.libraryFolder
            .appending(path: "Wine").appending(path: "lib").path(percentEncoded: false) + ":/usr/lib"
        // Wine Mono/Gecko aren't bundled: skip their install prompts (which would hang bottle setup) and
        // stop Wine creating Mac menu entries for every installed program.
        let defaultOverrides = "mscoree,mshtml=;winemenubuilder.exe=d"
        env["WINEDLLOVERRIDES"] = [env["WINEDLLOVERRIDES"], defaultOverrides]
            .compactMap { $0 }.joined(separator: ";")
    }

    /// The bottle environment with the engine defaults applied, then `extra` on top. `WINEDLLOVERRIDES` from
    /// `extra` (for example a per-game fix) is added to the existing overrides instead of replacing them.
    static func merged(_ base: [String: String], with extra: [String: String]) -> [String: String] {
        var env = base
        apply(to: &env)
        for (key, value) in extra {
            if key == "WINEDLLOVERRIDES", let existing = env[key], !existing.isEmpty {
                env[key] = value + ";" + existing
            } else {
                env[key] = value
            }
        }
        return env
    }

    /// Per-launch fixes: DXMT's helper DLL in the bottle, Steam's black-window wrapper and launch flags.
    /// Returns the arguments to launch with.
    static func prepareLaunch(of program: URL, args: [String], bottle: Bottle) -> [String] {
        DXMT.prepare(bottle: bottle)
        SteamFix.apply(to: bottle)
        return args + SteamFix.extraArguments(for: program, args: args)
    }
}
