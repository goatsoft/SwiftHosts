import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var hostsManager = HostsManager()
    
    @State private var selectedEntryID: UUID? = nil
    @State private var showingAddEditSheet: Bool = false
    @State private var editingEntry: HostEntry? = nil
    @State private var showInspector: Bool = false
    
    @State private var showingImportFilePicker: Bool = false
    @State private var showingExportFilePicker: Bool = false
    @State private var exportText: String = ""

    var selectedEntry: HostEntry? {
        guard let id = selectedEntryID else { return nil }
        return hostsManager.entries.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(
                hostsManager: hostsManager,
                selectedFilter: $hostsManager.selectedCategoryFilter
            )
        } detail: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    HostListView(
                        hostsManager: hostsManager,
                        selectedEntryID: $selectedEntryID,
                        onEdit: { entry in
                            editingEntry = entry
                            showingAddEditSheet = true
                        }
                    )
                    
                    // Bottom Status Bar
                    StatusBarView(hostsManager: hostsManager)
                }
                
                if showInspector, let selected = selectedEntry {
                    Divider()
                    HostDetailInspector(
                        entry: selected,
                        hostsManager: hostsManager,
                        onEdit: { entry in
                            editingEntry = entry
                            showingAddEditSheet = true
                        }
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Add Button
                    Button {
                        editingEntry = nil
                        showingAddEditSheet = true
                    } label: {
                        Label("Add Host", systemImage: "plus")
                    }
                    .help("Add new host mapping")

                    // Toggle Inspector
                    Button {
                        showInspector.toggle()
                    } label: {
                        Label("Toggle Inspector", systemImage: "sidebar.right")
                    }
                    .help("Show/Hide detail inspector")

                    Divider()

                    // Reload Button
                    Button {
                        hostsManager.loadHosts()
                    } label: {
                        Label("Reload", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Reload /etc/hosts from disk")

                    // Discard Button
                    Button {
                        hostsManager.discardChanges()
                    } label: {
                        Label("Discard Changes", systemImage: "arrow.uturn.backward")
                    }
                    .disabled(!hostsManager.isDirty)
                    .help("Discard unsaved changes")

                    // Save Button
                    Button {
                        hostsManager.saveHosts()
                    } label: {
                        HStack(spacing: 4) {
                            if hostsManager.isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text("Save")
                        }
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .tint(hostsManager.isDirty ? .blue : .gray)
                    .disabled(!hostsManager.isDirty || hostsManager.isSaving)
                    .help(hostsManager.isDirty ? "Save changes to /etc/hosts (⌘S)" : "No unsaved changes")

                    // Import/Export Menu
                    Menu {
                        Button {
                            showingImportFilePicker = true
                        } label: {
                            Label("Import Hosts File...", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            exportText = hostsManager.exportHostsContent()
                            showingExportFilePicker = true
                        } label: {
                            Label("Export Hosts File...", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .help("Import or Export hosts")
                }
            }
            .searchable(text: $hostsManager.searchText, prompt: "Search host, IP or comment...")
        }
        .sheet(isPresented: $showingAddEditSheet) {
            AddEditHostSheet(
                entry: editingEntry,
                categories: hostsManager.categories,
                onSave: { updatedEntry in
                    if editingEntry != nil {
                        hostsManager.updateEntry(updatedEntry)
                    } else {
                        hostsManager.addEntry(updatedEntry)
                    }
                }
            )
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
    }
}

struct StatusBarView: View {
    @ObservedObject var hostsManager: HostsManager

    var body: some View {
        HStack(spacing: 12) {
            if let error = hostsManager.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            } else if let status = hostsManager.statusMessage {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            } else {
                Text("/etc/hosts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if hostsManager.isDirty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("Unsaved Changes")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                }
            } else if let lastSaved = hostsManager.lastSavedDate {
                Text("Saved at \(lastSaved.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Total: \(hostsManager.entries.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .top)
    }
}

#Preview {
    ContentView()
}
