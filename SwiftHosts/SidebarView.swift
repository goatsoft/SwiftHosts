import SwiftUI

struct SidebarView: View {
    @ObservedObject var hostsManager: HostsManager
    @Binding var selectedFilter: String?

    var body: some View {
        List(selection: $selectedFilter) {
            Section("Filters") {
                NavigationLink(value: "All") {
                    Label {
                        HStack {
                            Text("All Hosts")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(hostsManager.entries.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.secondary.opacity(0.15)))
                        }
                    } icon: {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                    }
                }
                .tag("All")

                NavigationLink(value: "Enabled") {
                    Label {
                        HStack {
                            Text("Enabled")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(hostsManager.entries.filter { $0.isEnabled }.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.15)))
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
                .tag("Enabled")

                NavigationLink(value: "Disabled") {
                    Label {
                        HStack {
                            Text("Disabled")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(hostsManager.entries.filter { !$0.isEnabled }.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.secondary.opacity(0.2)))
                        }
                    } icon: {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .tag("Disabled")

                NavigationLink(value: "System") {
                    Label {
                        HStack {
                            Text("System Protected")
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(hostsManager.entries.filter { $0.isSystem }.count)")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange.opacity(0.15)))
                        }
                    } icon: {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.orange)
                    }
                }
                .tag("System")
            }

            if !hostsManager.categories.filter({ $0 != "System" }).isEmpty {
                Section("Categories") {
                    ForEach(hostsManager.categories.filter { $0 != "System" }, id: \.self) { category in
                        let count = hostsManager.entries.filter { $0.category == category }.count
                        NavigationLink(value: category) {
                            Label {
                                HStack {
                                    Text(category)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.accentColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                }
                            } icon: {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .tag(category)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Hosts Settings")
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Divider()
                Button {
                    hostsManager.flushDNSCache()
                } label: {
                    HStack(spacing: 6) {
                        if hostsManager.isFlushingDNS {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                                .foregroundColor(.orange)
                        }
                        Text(hostsManager.isFlushingDNS ? "Flushing DNS..." : "Flush DNS Cache")
                            .font(.callout)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(hostsManager.isFlushingDNS)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}
