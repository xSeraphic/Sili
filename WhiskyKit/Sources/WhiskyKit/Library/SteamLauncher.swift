//
//  SteamLauncher.swift
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

/// Starts Steam in a bottle only when it isn't already running, and waits for it to sign in before a game starts.
/// A game launched while Steam is still starting (or while two Steam clients are running) fails with
/// "Game failed to initialize Steam".
public enum SteamLauncher {
    /// True if the Steam client is running in the bottle.
    public static func isRunning(in bottle: Bottle) async -> Bool {
        let output = await Wine.runWineQuietly(["tasklist"], bottle: bottle).lowercased()
        return output.split(whereSeparator: \.isNewline).contains { $0.hasPrefix("steam.exe ") }
    }

    /// True once Steam has signed a user in (`ActiveProcess\ActiveUser` is non-zero) and its UI process is up.
    static func isReady(in bottle: Bottle) async -> Bool {
        let tasks = await Wine.runWineQuietly(["tasklist"], bottle: bottle).lowercased()
        guard tasks.contains("steam.exe "), tasks.contains("steamwebhelper") else { return false }
        let output = await Wine.runWineQuietly(
            ["reg", "query", #"HKCU\Software\Valve\Steam\ActiveProcess"#, "/v", "ActiveUser"], bottle: bottle
        )
        return activeUser(fromRegOutput: output).map { $0 != 0 } ?? false
    }

    /// Parses the DWORD from `reg query` output such as `    ActiveUser    REG_DWORD    0x4fb16a2`.
    static func activeUser(fromRegOutput output: String) -> UInt64? {
        guard let line = output.split(whereSeparator: \.isNewline).first(where: { $0.contains("REG_DWORD") }),
              let value = line.split(whereSeparator: \.isWhitespace).last,
              value.lowercased().hasPrefix("0x") else { return nil }
        return UInt64(value.dropFirst(2), radix: 16)
    }

    /// Shell commands for Dock shortcuts: wait (up to about 95 seconds) for Steam to sign in.
    public static func shellWaitForSteam(bottle: Bottle) -> String {
        let env = Wine.constructWineEnvironment(for: bottle)
            .map { "\($0.key)=\"\($0.value)\"" }.joined(separator: " ")
        let query = "\(env) WINEDEBUG=-all \(Wine.wineBinary.esc) reg query "
            + #"'HKCU\Software\Valve\Steam\ActiveProcess' /v ActiveUser"#
        return "sleep 5; for i in $(seq 45); do \(query) 2>/dev/null "
            + "| grep -qiE 'REG_DWORD[[:space:]]+0x0*[1-9a-f]' && break; sleep 2; done"
    }

    /// Starts Steam if it isn't running, then waits until it's signed in. Returns false on timeout (the game is
    /// usually still worth starting: Steam may just be showing its sign-in window).
    @discardableResult
    public static func ensureRunning(steamExe: URL, bottle: Bottle,
                                     timeout: Duration = .seconds(90)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        if await !isRunning(in: bottle) {
            try? await Wine.runProgram(at: steamExe, args: ["-silent", "-noverifyfiles"], bottle: bottle)
            // ActiveUser can be left over from the last session, so give the new client time to reset it.
            try? await Task.sleep(for: .seconds(5))
        }
        while clock.now < deadline {
            if await isReady(in: bottle) { return true }
            try? await Task.sleep(for: .seconds(2))
        }
        return false
    }
}
