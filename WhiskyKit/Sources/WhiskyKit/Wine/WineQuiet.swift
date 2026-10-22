//
//  WineQuiet.swift
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

extension Wine {
    /// Runs a short `wine` command (such as `tasklist` or `reg query`) and returns its standard output.
    /// Unlike `runWine`, it doesn't create a log file, so it's safe to poll.
    static func runWineQuietly(_ args: [String], bottle: Bottle) async -> String {
        let process = Process()
        process.executableURL = wineBinary
        process.arguments = args
        var environment = constructWineEnvironment(for: bottle)
        environment["WINEDEBUG"] = "-all"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ""
        }
        let reader = pipe.fileHandleForReading
        let data = await Task.detached { reader.readDataToEndOfFile() }.value
        process.waitUntilExit()
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}
