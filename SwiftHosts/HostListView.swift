import SwiftUI

struct HostListView: View {
    @ObservedObject var hostsManager: HostsManager
    @Binding var selectedEntryID: UUID?
    let onEdit: (HostEntry) -> Void

    @State private var sortOrder: [KeyPathComparator<HostEntry>] = [
        KeyPathComparator(\.category, order: .forward),
        KeyPathComparator(\.hostname, order: .forward)
    ]

    var entries: [HostEntry] {
        hostsManager.filteredEntries.sorted(using: sortOrder)
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text(hostsManager.searchText.isEmpty ? "No Host Entries Found" : "No Matching Hosts")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(hostsManager.searchText.isEmpty ? "Click '+' to add your first host mapping." : "Try clearing your search query.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(entries, selection: $selectedEntryID, sortOrder: $sortOrder) {
                    // Enabled column
                    TableColumn("Active", value: \.isEnabledSortKey) { entry in
                        Toggle("", isOn: Binding(
                            get: { entry.isEnabled },
                            set: { _ in hostsManager.toggleEntry(entry) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .disabled(entry.isSystem)
                    }
                    .width(min: 44, max: 54)

                    // IP Address column
                    TableColumn("IP Address", value: \.ipAddress) { entry in
                        HStack {
                            Text(entry.ipAddress)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(entry.isEnabled ? .primary : .secondary)
                            Spacer()
                        }
                    }
                    .width(min: 130, max: 200)

                    // Hostname column
                    TableColumn("Hostname", value: \.hostname) { entry in
                        HStack {
                            Text(entry.hostname)
                                .fontWeight(.medium)
                                .foregroundColor(entry.isEnabled ? .primary : .secondary)
                            if entry.isSystem {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .help("System Protected Entry")
                            }
                            Spacer()
                        }
                    }
                    .width(min: 160, ideal: 240)

                    // Category column
                    TableColumn("Category", value: \.category) { entry in
                        Text(entry.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(categoryColor(for: entry.category).opacity(0.15))
                            )
                            .foregroundColor(categoryColor(for: entry.category))
                    }
                    .width(min: 90, max: 150)

                    // Comment column
                    TableColumn("Comment", value: \.comment) { entry in
                        Text(entry.comment.isEmpty ? "—" : entry.comment)
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    // Actions column
                    TableColumn("Actions") { entry in
                        HStack(spacing: 8) {
                            Button {
                                onEdit(entry)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            .help("Edit Host")

                            Button {
                                hostsManager.removeEntry(entry)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .disabled(entry.isSystem)
                            .help(entry.isSystem ? "System entries cannot be deleted" : "Delete Host")
                        }
                    }
                    .width(min: 60, max: 70)
                }
                .contextMenu(forSelectionType: UUID.self) { selectedIDs in
                    if let firstID = selectedIDs.first, let entry = hostsManager.entries.first(where: { $0.id == firstID }) {
                        Button(entry.isEnabled ? "Disable Host" : "Enable Host") {
                            hostsManager.toggleEntry(entry)
                        }
                        .disabled(entry.isSystem)

                        Button("Edit Host...") {
                            onEdit(entry)
                        }

                        Divider()

                        Button("Copy IP Address") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.ipAddress, forType: .string)
                        }

                        Button("Copy Hostname") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.hostname, forType: .string)
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            hostsManager.removeEntry(entry)
                        }
                        .disabled(entry.isSystem)
                    }
                }
            }
        }
    }

    private func categoryColor(for category: String) -> Color {
        switch category {
        case "System": return .orange
        case "Local Dev": return .blue
        case "Ad Block": return .red
        case "Testing": return .purple
        default: return .accentColor
        }
    }
}

extension HostEntry {
    var isEnabledSortKey: Int {
        isEnabled ? 1 : 0
    }
}
