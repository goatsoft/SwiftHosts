import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var hostsManager: HostsManager

    @State private var selectedEntryID: UUID?
    @State private var showingImportFilePicker: Bool = false
    @State private var showingExportFilePicker: Bool = false
    @State private var showingAboutSheet: Bool = false
    @State private var exportText: String = ""

    var body: some View {
        NavigationSplitView {
            SidebarView(
                hostsManager: hostsManager,
                selectedFilter: $hostsManager.selectedCategoryFilter
            )
        } detail: {
            HostListView(
                hostsManager: hostsManager,
                selectedEntryID: $selectedEntryID
            )
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        hostsManager.addNewEmptyEntry()
                    } label: {
                        Label("Add Host", systemImage: "plus")
                    }
                    .help("Add a new host entry (⌘N)")
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        hostsManager.saveHosts()
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!hostsManager.isDirty)
                    .help("Save changes to /etc/hosts (⌘S)")
                }

                ToolbarItem(placement: .automatic) {
                    Button {
                        hostsManager.loadHosts()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Reload /etc/hosts from disk")
                }

                // Import/Export Menu (...)
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button {
                            showingImportFilePicker = true
                        } label: {
                            Label("Import Hosts File...", systemImage: "square.and.arrow.down")
                        }
                        .keyboardShortcut("i", modifiers: [.command, .shift])

                        Button {
                            exportText = hostsManager.exportHostsContent()
                            showingExportFilePicker = true
                        } label: {
                            Label("Export Hosts File...", systemImage: "square.and.arrow.up")
                        }
                        .keyboardShortcut("e", modifiers: [.command, .shift])
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .help("Import or Export hosts")
                }
            }
            .searchable(text: $hostsManager.searchText, prompt: "Search host, IP or comment...")
        }
        .sheet(isPresented: $showingAboutSheet) {
            AboutSwiftHostsSheet()
        }
        .fileImporter(
            isPresented: $showingImportFilePicker,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "hosts") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first, url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        hostsManager.importEntries(from: content)
                    }
                }
            case .failure(let error):
                hostsManager.errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .fileExporter(
            isPresented: $showingExportFilePicker,
            document: PlainTextDocument(text: exportText),
            contentType: .plainText,
            defaultFilename: "hosts"
        ) { result in
            switch result {
            case .success:
                hostsManager.statusMessage = "Exported hosts file successfully."
            case .failure(let error):
                hostsManager.errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerImportHosts)) { _ in
            showingImportFilePicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerExportHosts)) { _ in
            exportText = hostsManager.exportHostsContent()
            showingExportFilePicker = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerAboutApp)) { _ in
            showingAboutSheet = true
        }
    }
}

// MARK: - Dedicated About SwiftHosts Sheet (Using Real App Icon)

struct AboutSwiftHostsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (Build \(build))"
    }

    private var currentYear: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    private var appIconImage: NSImage {
        NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header Top-Right X Close Button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            // Actual macOS Application Icon
            Image(nsImage: appIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 76, height: 76)
                .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)

            VStack(spacing: 4) {
                Text("SwiftHosts")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(appVersion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()
                .frame(width: 240)

            Text("A modern native macOS hosts file manager built in Swift & SwiftUI.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            Spacer(minLength: 4)

            HStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/swift-hosts/SwiftHosts")!) {
                    HStack(spacing: 6) {
                        GitHubLogoShape()
                            .fill(Color.primary)
                            .frame(width: 14, height: 14)
                        Text("GitHub Repository")
                    }
                }
                .buttonStyle(.bordered)

                Link(destination: URL(string: "https://github.com/swift-hosts/SwiftHosts/issues")!) {
                    Label("Report Issue", systemImage: "exclamationmark.bubble")
                }
                .buttonStyle(.bordered)
            }

            Text("Copyright © \(currentYear) GOATsoft. All rights reserved.")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.bottom, 4)
        }
        .padding(16)
        .frame(width: 380, height: 350)
    }
}

struct GitHubLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 24.0
        let scaleY = rect.height / 24.0
        var path = Path()

        path.move(to: CGPoint(x: 12 * scaleX, y: 0 * scaleY))
        path.addCurve(to: CGPoint(x: 0, y: 12 * scaleY), control1: CGPoint(x: 5.37 * scaleX, y: 0), control2: CGPoint(x: 0, y: 5.37 * scaleY))
        path.addCurve(to: CGPoint(x: 8.205 * scaleX, y: 23.385 * scaleY), control1: CGPoint(x: 0, y: 17.31 * scaleY), control2: CGPoint(x: 3.435 * scaleX, y: 21.795 * scaleY))
        path.addCurve(to: CGPoint(x: 9.03 * scaleX, y: 22.815 * scaleY), control1: CGPoint(x: 8.805 * scaleX, y: 23.49 * scaleY), control2: CGPoint(x: 9.03 * scaleX, y: 23.13 * scaleY))
        path.addCurve(to: CGPoint(x: 9.015 * scaleX, y: 20.58 * scaleY), control1: CGPoint(x: 9.03 * scaleX, y: 22.53 * scaleY), control2: CGPoint(x: 9.015 * scaleX, y: 21.585 * scaleY))
        path.addCurve(to: CGPoint(x: 4.98 * scaleX, y: 19.17 * scaleY), control1: CGPoint(x: 6 * scaleX, y: 21.135 * scaleY), control2: CGPoint(x: 5.22 * scaleX, y: 19.845 * scaleY))
        path.addCurve(to: CGPoint(x: 3.75 * scaleX, y: 17.475 * scaleY), control1: CGPoint(x: 4.845 * scaleX, y: 18.825 * scaleY), control2: CGPoint(x: 4.26 * scaleX, y: 17.76 * scaleY))
        path.addCurve(to: CGPoint(x: 3.735 * scaleX, y: 16.68 * scaleY), control1: CGPoint(x: 3.33 * scaleX, y: 17.25 * scaleY), control2: CGPoint(x: 2.73 * scaleX, y: 16.695 * scaleY))
        path.addCurve(to: CGPoint(x: 5.58 * scaleX, y: 17.91 * scaleY), control1: CGPoint(x: 4.68 * scaleX, y: 16.665 * scaleY), control2: CGPoint(x: 5.355 * scaleX, y: 17.55 * scaleY))
        path.addCurve(to: CGPoint(x: 9.075 * scaleX, y: 18.9 * scaleY), control1: CGPoint(x: 6.66 * scaleX, y: 19.725 * scaleY), control2: CGPoint(x: 8.385 * scaleX, y: 19.215 * scaleY))
        path.addCurve(to: CGPoint(x: 9.84 * scaleX, y: 17.295 * scaleY), control1: CGPoint(x: 9.18 * scaleX, y: 18.12 * scaleY), control2: CGPoint(x: 9.495 * scaleX, y: 17.595 * scaleY))
        path.addCurve(to: CGPoint(x: 4.38 * scaleX, y: 11.37 * scaleY), control1: CGPoint(x: 7.17 * scaleX, y: 16.995 * scaleY), control2: CGPoint(x: 4.38 * scaleX, y: 15.96 * scaleY))
        path.addCurve(to: CGPoint(x: 5.61 * scaleX, y: 8.145 * scaleY), control1: CGPoint(x: 4.38 * scaleX, y: 10.065 * scaleY), control2: CGPoint(x: 4.845 * scaleX, y: 8.985 * scaleY))
        path.addCurve(to: CGPoint(x: 5.73 * scaleX, y: 4.965 * scaleY), control1: CGPoint(x: 5.49 * scaleX, y: 7.845 * scaleY), control2: CGPoint(x: 5.07 * scaleX, y: 6.615 * scaleY))
        path.addCurve(to: CGPoint(x: 9.03 * scaleX, y: 6.195 * scaleY), control1: CGPoint(x: 5.73 * scaleX, y: 4.965 * scaleY), control2: CGPoint(x: 6.735 * scaleX, y: 4.65 * scaleY))
        path.addCurve(to: CGPoint(x: 12 * scaleX, y: 5.79 * scaleY), control1: CGPoint(x: 9.99 * scaleX, y: 5.925 * scaleY), control2: CGPoint(x: 11.01 * scaleX, y: 5.79 * scaleY))
        path.addCurve(to: CGPoint(x: 14.97 * scaleX, y: 6.195 * scaleY), control1: CGPoint(x: 12.99 * scaleX, y: 5.79 * scaleY), control2: CGPoint(x: 14.01 * scaleX, y: 5.925 * scaleY))
        path.addCurve(to: CGPoint(x: 18.27 * scaleX, y: 4.965 * scaleY), control1: CGPoint(x: 17.265 * scaleX, y: 4.635 * scaleY), control2: CGPoint(x: 18.27 * scaleX, y: 4.965 * scaleY))
        path.addCurve(to: CGPoint(x: 18.39 * scaleX, y: 8.145 * scaleY), control1: CGPoint(x: 18.93 * scaleX, y: 6.615 * scaleY), control2: CGPoint(x: 18.51 * scaleX, y: 7.845 * scaleY))
        path.addCurve(to: CGPoint(x: 19.62 * scaleX, y: 11.37 * scaleY), control1: CGPoint(x: 19.155 * scaleX, y: 8.985 * scaleY), control2: CGPoint(x: 19.62 * scaleX, y: 10.05 * scaleY))
        path.addCurve(to: CGPoint(x: 14.145 * scaleX, y: 17.295 * scaleY), control1: CGPoint(x: 19.62 * scaleX, y: 15.975 * scaleY), control2: CGPoint(x: 16.815 * scaleX, y: 17 * scaleY))
        path.addCurve(to: CGPoint(x: 14.955 * scaleX, y: 19.515 * scaleY), control1: CGPoint(x: 14.58 * scaleX, y: 17.67 * scaleY), control2: CGPoint(x: 14.955 * scaleX, y: 18.39 * scaleY))
        path.addCurve(to: CGPoint(x: 14.94 * scaleX, y: 22.815 * scaleY), control1: CGPoint(x: 14.955 * scaleX, y: 21.12 * scaleY), control2: CGPoint(x: 14.94 * scaleX, y: 22.41 * scaleY))
        path.addCurve(to: CGPoint(x: 15.765 * scaleX, y: 23.385 * scaleY), control1: CGPoint(x: 14.94 * scaleX, y: 23.13 * scaleY), control2: CGPoint(x: 15.165 * scaleX, y: 23.49 * scaleY))
        path.addCurve(to: CGPoint(x: 24 * scaleX, y: 12 * scaleY), control1: CGPoint(x: 20.565 * scaleX, y: 21.795 * scaleY), control2: CGPoint(x: 24 * scaleX, y: 17.31 * scaleY))
        path.addCurve(to: CGPoint(x: 12 * scaleX, y: 0), control1: CGPoint(x: 24 * scaleX, y: 5.37 * scaleY), control2: CGPoint(x: 18.63 * scaleX, y: 0))
        path.closeSubpath()
        return path
    }
}

struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
