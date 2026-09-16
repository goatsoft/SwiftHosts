import SwiftUI

struct AppSettingsView: View {
    private enum Tabs: Hashable {
        case general, backups, about
    }

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tabs.general)

            BackupSettingsView()
                .tabItem {
                    Label("Backups", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(Tabs.backups)

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(Tabs.about)
        }
        .padding(20)
        .frame(width: 500, height: 320)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("autoFlushDNS") private var autoFlushDNS: Bool = true
    @AppStorage("autoReloadExternal") private var autoReloadExternal: Bool = true
    @AppStorage("defaultIPAddress") private var defaultIPAddress: String = "127.0.0.1"
    @AppStorage("defaultCategory") private var defaultCategory: String = "Custom"

    var body: some View {
        Form {
            Section {
                Toggle("Automatically flush DNS cache after saving changes", isOn: $autoFlushDNS)
                    .help("Runs dscacheutil -flushcache whenever /etc/hosts is updated")

                Toggle("Automatically reload when /etc/hosts changes externally", isOn: $autoReloadExternal)
                    .help("Refreshes entry list automatically if modified via Terminal or other tools")
            } header: {
                Text("Automation Options")
            }

            Section {
                HStack {
                    Text("Default IP for New Hosts:")
                    Spacer()
                    TextField("127.0.0.1", text: $defaultIPAddress)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                }

                HStack {
                    Text("Default Category:")
                    Spacer()
                    TextField("Custom", text: $defaultCategory)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                }
            } header: {
                Text("Defaults")
            }
        }
        .formStyle(.grouped)
    }
}

struct BackupSettingsView: View {
    @State private var backupCount: Int = 0
    @State private var statusText: String = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SwiftHosts creates timestamped backups of your hosts file in Application Support before performing save operations.")
                        .font(.callout)
                        .foregroundColor(.secondary)

                    HStack {
                        Button("Open Backups Folder in Finder") {
                            openBackupsFolder()
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Hosts File Backups")
            }
        }
        .formStyle(.grouped)
    }

    private func openBackupsFolder() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let backupDir = appSupport.appendingPathComponent("SwiftHosts/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: backupDir.path)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 56))
                .foregroundColor(.accentColor)

            Text("SwiftHosts")
                .font(.title)
                .fontWeight(.bold)

            Text("Version 1.0.0 (Native SwiftUI)")
                .font(.callout)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 300)

            Text("Re-created as a modern macOS application inspired by the classic Hosts.prefpane preference pane.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)

            Spacer()
        }
        .padding(.top, 20)
    }
}

#Preview {
    AppSettingsView()
}
