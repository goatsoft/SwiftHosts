import SwiftUI

struct AppSettingsView: View {
    private enum Tabs: Hashable {
        case general, security, backups
    }

    @ObservedObject var hostsManager: HostsManager

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tabs.general)

            SecuritySettingsView(hostsManager: hostsManager)
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }
                .tag(Tabs.security)

            BackupSettingsView()
                .tabItem {
                    Label("Backups", systemImage: "arrow.triangle.2.circlepath")
                }
                .tag(Tabs.backups)
        }
        .padding(20)
        .frame(width: 540, height: 340)
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

struct SecuritySettingsView: View {
    @ObservedObject var hostsManager: HostsManager

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundColor(hostsManager.isUnlocked ? .green : .orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Session Authorization")
                                .fontWeight(.semibold)
                            Text(hostsManager.isUnlocked ? "Session Unlocked (0 Prompts for Remaining Edits)" : "Session Locked")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()

                        if hostsManager.isUnlocked {
                            Button("Lock Session") {
                                hostsManager.lockSession()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text("Locked")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("App Session Security")
            } footer: {
                Text("Apple Session Authorization: Prompts for password ONCE on initial save. While SwiftHosts stays open, all subsequent edits save with 0 prompts. Password is wiped from memory upon quitting or locking session.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

#Preview {
    AppSettingsView(hostsManager: HostsManager())
}
