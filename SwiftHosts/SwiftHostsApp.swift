import SwiftUI

@main
struct SwiftHostsApp: App {
    @StateObject private var hostsManager = HostsManager()

    var body: some Scene {
        WindowGroup {
            ContentView(hostsManager: hostsManager)
                .frame(minWidth: 780, idealWidth: 880, minHeight: 500, idealHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            // Replace standard "About SwiftHosts" menu item
            CommandGroup(replacing: .appInfo) {
                Button("About SwiftHosts") {
                    NotificationCenter.default.post(name: .triggerAboutApp, object: nil)
                }
            }

            // Replace default macOS "New Window" (⌘N) with domain-specific "New Host Entry" & Import/Export
            CommandGroup(replacing: .newItem) {
                Button("New Host Entry") {
                    hostsManager.addNewEmptyEntry()
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Import Hosts File...") {
                    NotificationCenter.default.post(name: .triggerImportHosts, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Export Hosts File...") {
                    NotificationCenter.default.post(name: .triggerExportHosts, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            // Save and Revert menu items
            CommandGroup(replacing: .saveItem) {
                Button("Save /etc/hosts") {
                    hostsManager.saveHosts()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!hostsManager.isDirty)

                Button("Revert Changes") {
                    hostsManager.discardChanges()
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!hostsManager.isDirty)
            }
        }

        Settings {
            AppSettingsView(hostsManager: hostsManager)
        }
    }
}

extension Notification.Name {
    static let triggerImportHosts = Notification.Name("triggerImportHosts")
    static let triggerExportHosts = Notification.Name("triggerExportHosts")
    static let triggerAboutApp = Notification.Name("triggerAboutApp")
}
