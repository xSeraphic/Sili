//
//  GameCard.swift
//  Whisky
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

import SwiftUI
import UniformTypeIdentifiers
import WhiskyKit

/// One game tile: artwork, title, bottle, with hover-to-play.
struct GameCard: View {
    let game: LibraryGame
    let onPlay: () -> Void
    let onOpenBottle: () -> Void
    /// Called once the game has been uninstalled (Steam) or unpinned, so the Library can refresh.
    let onRemoved: () -> Void

    @EnvironmentObject var bottleVM: BottleVM
    @State private var hovering = false
    @State private var launching = false
    @State private var artwork: NSImage?
    @State private var confirmingRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GameArtwork(game: game, loaded: $artwork)
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(hovering ? 0.35 : 0.08), lineWidth: 1)
                }
                .overlay { playOverlay }
                .shadow(color: .black.opacity(hovering ? 0.45 : 0.25), radius: hovering ? 14 : 6, y: hovering ? 8 : 3)
                .scaleEffect(hovering ? 1.03 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: game.isSteam ? "cloud.fill" : "pin.fill")
                        .imageScale(.small)
                    Text(game.bottleName)
                        .lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onHover { over in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { hovering = over }
        }
        .onTapGesture(count: 2) { play() }
        .help(game.name)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(game.name), \(game.bottleName)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Double-click to play"))
        .accessibilityAction { play() }
        .accessibilityAction(named: Text("Open Bottle")) { onOpenBottle() }
        .accessibilityAction(named: Text(removeTitle)) { confirmingRemoval = true }
        .contextMenu {
            Button("Play", systemImage: "play.fill") { play() }
            Divider()
            Button("Create Dock Shortcut…", systemImage: "app.badge") { createShortcut() }
            if let folder = game.installFolder {
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                }
            }
            Button("Open Bottle", systemImage: "wineglass") { onOpenBottle() }
            Divider()
            Button(removeTitle, systemImage: "trash", role: .destructive) { confirmingRemoval = true }
        }
        .alert(removeAlertTitle, isPresented: $confirmingRemoval) {
            Button(game.isSteam ? "Continue in Steam" : "Remove", role: .destructive) { remove() }
            Button("Cancel", role: .cancel) {}
        } message: {
            removeAlertMessage
        }
    }

    @ViewBuilder
    private var playOverlay: some View {
        ZStack {
            if hovering || launching {
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Button(action: play) {
                            Group {
                                if launching {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label("Play", systemImage: "play.fill")
                                }
                            }
                            .font(.callout.weight(.semibold))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.86, green: 0.13, blue: 0.16))
                        .disabled(launching)
                        moreMenu
                    }
                    .controlSize(.large)
                    .padding(10)
                }
                .transition(.opacity)
            }
        }
    }

    /// The "…" button next to Play: the same actions as the right-click menu.
    private var moreMenu: some View {
        Menu {
            Button("Create Dock Shortcut…", systemImage: "app.badge") { createShortcut() }
            if let folder = game.installFolder {
                Button("Show in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                }
            }
            Button("Open Bottle", systemImage: "wineglass") { onOpenBottle() }
            Divider()
            Button(removeTitle, systemImage: "trash", role: .destructive) { confirmingRemoval = true }
        } label: {
            Image(systemName: "ellipsis")
                .font(.callout.weight(.semibold))
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.bordered)
        .fixedSize()
        .help("More")
        .accessibilityLabel(Text("More"))
    }

    private var removeTitle: LocalizedStringKey {
        game.isSteam ? "Uninstall…" : "Remove from Library"
    }

    private var removeAlertTitle: Text {
        game.isSteam ? Text("Uninstall \(game.name)?") : Text("Remove \(game.name) from the Library?")
    }

    private var removeAlertMessage: Text {
        guard game.isSteam else { return Text("This unpins the program. Its files stay where they are.") }
        return Text("Steam will ask you to confirm, then delete the game's files from the \(game.bottleName) bottle. ")
            + Text("Your Steam Cloud saves aren't affected, and you can reinstall it from Steam at any time.")
    }

    /// Steam games: hand off to Steam's own uninstaller (it confirms and deletes the files), bring its dialog to the
    /// front, and refresh once the game is gone. Pinned programs: just unpin.
    private func remove() {
        guard let bottle = bottleVM.bottles.first(where: { $0.url == game.bottleURL }) else { return }
        switch game.source {
        case .steam(let appID, let steamExe):
            let windows = WineActivation.currentWineWindowIDs()
            Task.detached(priority: .userInitiated) {
                await SteamLauncher.uninstall(appID: appID, steamExe: steamExe, bottle: bottle)
                await WineActivation.activateNewWindow(excludingWindows: windows, timeout: .seconds(30))
                if await SteamLauncher.waitForRemoval(of: game) {
                    await MainActor.run { onRemoved() }
                }
            }
        case .pinned(let exe):
            if let program = bottle.programs.first(where: { $0.url == exe }) {
                program.pinned = false
            } else {
                bottle.settings.pins.removeAll { $0.url == exe }
            }
            onRemoved()
        }
    }

    private func play() {
        guard !launching else { return }
        launching = true
        onPlay()
        // Wine can take a while to bring the game up; keep the spinner (and block re-clicks) meanwhile.
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { launching = false }
    }

    private func createShortcut() {
        guard let bottle = bottleVM.bottles.first(where: { $0.url == game.bottleURL }) else { return }
        let panel = NSSavePanel()
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [UTType.applicationBundle]
        panel.allowsOtherFileTypes = false
        panel.isExtensionHidden = true
        panel.nameFieldStringValue = game.name + ".app"
        panel.begin { result in
            guard result == .OK, let url = panel.url else { return }
            Task(priority: .userInitiated) {
                switch game.source {
                case .steam(let appID, let steamExe):
                    var command = Wine.generateRunCommand(
                        at: steamExe, bottle: bottle, args: "-silent steam://rungameid/\(appID)", environment: [:]
                    )
                    if let direct = GameCompat.forGame(game) {
                        GameCompat.prepareDirectLaunch(appID: appID, executable: direct.executable, bottle: bottle)
                        command = Wine.generateRunCommand(
                            at: steamExe, bottle: bottle, args: "-silent -noverifyfiles", environment: [:]
                        ) + "; " + SteamLauncher.shellWaitForSteam(bottle: bottle) + "; " + Wine.generateRunCommand(
                            at: direct.executable, bottle: bottle, args: "", environment: direct.compat.environment
                        )
                    }
                    await ProgramShortcut.createShortcut(command: command, icon: artwork, app: url)
                case .pinned(let exe):
                    await ProgramShortcut.createShortcut(Program(url: exe, bottle: bottle), app: url,
                                                         name: url.deletingPathExtension().lastPathComponent)
                }
            }
        }
    }
}
