//
//  WineActivation.swift
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

import AppKit

/// Brings a newly launched Windows program to the front.
///
/// macOS doesn't let a background process steal focus, so a game launched from Sili used to open behind other
/// windows. GTA San Andreas' screen picker looked like a hang, and fullscreen games didn't hide the menu bar and
/// Dock (Wine only hides them while the game is the active app). Sili, which is active when you press Play,
/// hands activation to the game's process once it shows a window.
public enum WineActivation {
    /// Wine processes that exist right now. Take this snapshot before launching.
    public static func currentWinePIDs() -> Set<pid_t> {
        Set(NSWorkspace.shared.runningApplications.filter(isWine).map(\.processIdentifier))
    }

    /// Waits for a Wine process that isn't in `existing` to show a window, then activates it.
    @MainActor
    public static func activateNewWindow(excluding existing: Set<pid_t>, timeout: Duration = .seconds(90)) async {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while clock.now < deadline {
            let candidates = Set(NSWorkspace.shared.runningApplications.filter(isWine).map(\.processIdentifier))
                .subtracting(existing)
            if let pid = firstPIDWithWindow(among: candidates),
               let app = NSRunningApplication(processIdentifier: pid) {
                NSApp.yieldActivation(to: app)
                app.activate()
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private static func isWine(_ app: NSRunningApplication) -> Bool {
        app.executableURL?.path(percentEncoded: false).contains("/Libraries/Wine/") ?? false
    }

    /// A normal on-screen window (layer 0, not tiny) owned by one of `pids`.
    private static func firstPIDWithWindow(among pids: Set<pid_t>) -> pid_t? {
        guard !pids.isEmpty,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                                       kCGNullWindowID) as? [[String: Any]] else { return nil }
        for window in windows {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  (bounds["Width"] ?? 0) > 100, (bounds["Height"] ?? 0) > 100 else { continue }
            return pid
        }
        return nil
    }
}
