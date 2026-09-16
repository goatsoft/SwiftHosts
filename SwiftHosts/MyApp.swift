import SwiftUI

@main
struct SwiftHostsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 760, idealWidth: 840, minHeight: 480, idealHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        
        Settings {
            AppSettingsView()
        }
    }
}
