import SwiftUI

struct HostDetailInspector: View {
    let entry: HostEntry
    @ObservedObject var hostsManager: HostsManager

    var catColor: Color {
        hostsManager.categoryColor(for: entry.category)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.hostname)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(entry.ipAddress)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            Divider()

            // Info Grid
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Status:")
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(entry.isEnabled ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(entry.isEnabled ? "Active" : "Disabled")
                            .fontWeight(.medium)
                    }
                }

                HStack {
                    Text("Category:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entry.category)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(catColor.opacity(0.18)))
                        .overlay(Capsule().stroke(catColor.opacity(0.5), lineWidth: 1))
                        .foregroundColor(catColor)
                }

                HStack {
                    Text("Protection:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entry.isSystem ? "System Protected" : "User Defined")
                        .font(.callout)
                        .foregroundColor(entry.isSystem ? .orange : .primary)
                }

                if !entry.comment.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Comment / Notes:")
                            .foregroundColor(.secondary)
                        Text(entry.comment)
                            .font(.callout)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
                    }
                }
            }

            Divider()

            // Quick Actions
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Actions")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                HStack {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.ipAddress, forType: .string)
                    } label: {
                        Label("Copy IP", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.hostname, forType: .string)
                    } label: {
                        Label("Copy Host", systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    hostsManager.toggleEntry(entry)
                } label: {
                    Label(
                        entry.isEnabled ? "Disable Entry" : "Enable Entry",
                        systemImage: entry.isEnabled ? "pause.fill" : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(entry.isEnabled ? .orange : .green)
                .disabled(entry.isSystem)
            }

            Spacer()
        }
        .padding()
        .frame(width: 260)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
