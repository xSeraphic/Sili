//
//  SettingsView.swift
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
import WhiskyKit

struct SettingsView: View {
    @AppStorage("SUEnableAutomaticChecks") var whiskyUpdate = true
    @AppStorage("killOnTerminate") var killOnTerminate = true
    @AppStorage("checkWhiskyWineUpdates") var checkWhiskyWineUpdates = true
    @AppStorage("defaultBottleLocation") var defaultBottleLocation = BottleData.defaultBottleDir
    @State private var dxmtEnabled = DXMT.isEnabled
    @State private var dxmtError: String?

    var body: some View {
        Form {
            Section("settings.general") {
                Toggle("settings.toggle.kill.on.terminate", isOn: $killOnTerminate)
                ActionView(
                    text: "settings.path",
                    subtitle: defaultBottleLocation.prettyPath(),
                    actionName: "create.browse"
                ) {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.canCreateDirectories = true
                    panel.directoryURL = BottleData.containerDir
                    panel.begin { result in
                        if result == .OK, let url = panel.urls.first {
                            defaultBottleLocation = url
                        }
                    }
                }
            }
            if DXMT.isAvailable {
                Section("Graphics") {
                    Toggle(isOn: $dxmtEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use DXMT for DirectX 10/11")
                            Text("Translates DirectX 11 straight to Metal: faster, and more games start. Turn off to "
                                 + "use Wine's own DirectX if a game misbehaves. Applies to all bottles; close running "
                                 + "games before switching.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: dxmtEnabled) { _, enabled in
                        do {
                            try DXMT.setEnabled(enabled)
                            dxmtError = nil
                        } catch {
                            dxmtError = error.localizedDescription
                            dxmtEnabled = DXMT.isEnabled
                        }
                    }
                    if let dxmtError {
                        Text(dxmtError).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            Section("settings.updates") {
                Toggle("settings.toggle.whisky.updates", isOn: $whiskyUpdate)
                Toggle("settings.toggle.whiskywine.updates", isOn: $checkWhiskyWineUpdates)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: ViewWidth.medium)
    }
}

#Preview {
    SettingsView()
}
