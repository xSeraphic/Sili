//
//  GameLibraryView.swift
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

enum LibrarySort: String, CaseIterable, Identifiable {
    case name, recent, bottle
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .name: "Name"
        case .recent: "Recently Played"
        case .bottle: "Bottle"
        }
    }
}

/// Grid of every game found across all bottles.
struct GameLibraryView: View {
    @EnvironmentObject var bottleVM: BottleVM
    @Binding var selected: URL?
    @Binding var refresh: Bool

    @AppStorage("librarySort") private var sort: LibrarySort = .name
    @State private var games: [LibraryGame] = []
    @State private var search = ""
    @State private var loading = true
    /// Games launched recently. Wine can take a while to show a window, and a second click
    /// starts a second copy that fights the first.
    @State private var recentlyLaunched: [String: Date] = [:]

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 22)]

    var body: some View {
        Group {
            if loading && games.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if games.isEmpty {
                ContentUnavailableView {
                    Label("No Games Yet", systemImage: "gamecontroller")
                } description: {
                    Text("Install games with Steam inside a bottle, or pin a program, and they'll appear here.")
                }
            } else if visibleGames.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 26) {
                        ForEach(visibleGames) { game in
                            GameCard(game: game,
                                     onPlay: { launch(game) },
                                     onOpenBottle: { selected = game.bottleURL })
                        }
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Library")
        .navigationSubtitle(games.isEmpty ? "" : "\(games.count) games")
        .searchable(text: $search, placement: .toolbar, prompt: "Search games")
        .toolbar {
            ToolbarItem {
                Picker("Sort", selection: $sort) {
                    ForEach(LibrarySort.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .help("Sort games")
            }
        }
        .task { await reload() }
        .onChange(of: refresh) { Task { await reload() } }
        .onChange(of: bottleVM.bottles) { Task { await reload() } }
    }

    private var visibleGames: [LibraryGame] {
        let filtered = search.isEmpty ? games : games.filter {
            $0.name.localizedCaseInsensitiveContains(search)
            || $0.bottleName.localizedCaseInsensitiveContains(search)
        }
        switch sort {
        case .name:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .recent:
            return filtered.sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
        case .bottle:
            return filtered.sorted {
                if $0.bottleName != $1.bottleName {
                    return $0.bottleName.localizedStandardCompare($1.bottleName) == .orderedAscending
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }
    }

    private func reload() async {
        loading = true
        let bottles = bottleVM.bottles
        let found = await Task.detached(priority: .userInitiated) {
            GameLibraryScanner.scan(bottles: bottles)
        }.value
        withAnimation(.default) { games = found }
        loading = false
    }

    private func launch(_ game: LibraryGame) {
        if let last = recentlyLaunched[game.id], Date().timeIntervalSince(last) < 20 { return }
        recentlyLaunched[game.id] = Date()
        guard let bottle = bottleVM.bottles.first(where: { $0.url == game.bottleURL }) else { return }
        switch game.source {
        case .steam(let appID, let steamExe):
            if let direct = GameCompat.forGame(game) {
                // Known game: make sure Steam is up (for DRM), then start the game itself with its workarounds.
                // This also skips Steam's launch-options dialog, which doesn't render under Wine on macOS.
                GameCompat.prepareDirectLaunch(appID: appID, executable: direct.executable)
                Task.detached(priority: .userInitiated) {
                    try? await Wine.runProgram(at: steamExe, args: ["-silent", "-noverifyfiles"], bottle: bottle)
                    try? await Task.sleep(for: .seconds(3))
                    try? await Wine.runProgram(at: direct.executable, bottle: bottle,
                                               environment: direct.compat.environment)
                }
            } else {
                Task.detached(priority: .userInitiated) {
                    try? await Wine.runProgram(at: steamExe, args: ["-silent", "steam://rungameid/\(appID)"],
                                               bottle: bottle)
                }
            }
        case .pinned(let exe):
            Program(url: exe, bottle: bottle).run()
        }
    }
}

/// One game tile: artwork, title, bottle, with hover-to-play.
struct GameCard: View {
    let game: LibraryGame
    let onPlay: () -> Void
    let onOpenBottle: () -> Void

    @EnvironmentObject var bottleVM: BottleVM
    @State private var hovering = false
    @State private var launching = false
    @State private var artwork: NSImage?

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
                    .controlSize(.large)
                    .padding(10)
                    .disabled(launching)
                }
                .transition(.opacity)
            }
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
                        GameCompat.prepareDirectLaunch(appID: appID, executable: direct.executable)
                        command = Wine.generateRunCommand(
                            at: steamExe, bottle: bottle, args: "-silent -noverifyfiles", environment: [:]
                        ) + "; sleep 3; " + Wine.generateRunCommand(
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

/// Cover art: Steam's cached art, then Steam's CDN, then the program icon on a gradient.
struct GameArtwork: View {
    let game: LibraryGame
    @Binding var loaded: NSImage?

    @State private var image: NSImage?
    @State private var failedPortrait = false

    var body: some View {
        ZStack {
            placeholder
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: game.id) { await load() }
    }

    private var placeholder: some View {
        LinearGradient(colors: [Color(red: 0.20, green: 0.17, blue: 0.22), Color(red: 0.09, green: 0.08, blue: 0.11)],
                       startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .center) {
                if image == nil {
                    Text(String(game.name.prefix(1)).uppercased())
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.18))
                }
            }
    }

    private func load() async {
        if let local = game.localArtwork, let img = NSImage(contentsOf: local) {
            set(img); return
        }
        switch game.source {
        case .steam:
            for url in [game.remoteArtwork, game.remoteHeader].compactMap({ $0 }) {
                if let img = await fetch(url) { set(img); return }
            }
        case .pinned(let exe):
            let icon = await Task.detached { (try? PEFile(url: exe))?.bestIcon() }.value
            if let icon { set(icon.paddedPortrait()) }
        }
    }

    private func set(_ img: NSImage) {
        withAnimation(.easeOut(duration: 0.2)) { image = img }
        loaded = img
    }

    private func fetch(_ url: URL) async -> NSImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return NSImage(data: data)
        } catch {
            return nil
        }
    }
}

private extension NSImage {
    /// Centres a small program icon on a dark 2:3 card so it matches cover art.
    func paddedPortrait() -> NSImage {
        let canvas = NSSize(width: 300, height: 450)
        return NSImage(size: canvas, flipped: false) { rect in
            NSColor(calibratedRed: 0.15, green: 0.13, blue: 0.17, alpha: 1).setFill()
            rect.fill()
            let side: CGFloat = 128
            self.draw(in: NSRect(x: (canvas.width - side) / 2, y: (canvas.height - side) / 2,
                                 width: side, height: side))
            return true
        }
    }
}
