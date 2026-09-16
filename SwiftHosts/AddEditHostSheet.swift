import SwiftUI

struct AddEditHostSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let initialEntry: HostEntry?
    let existingCategories: [String]
    let onSave: (HostEntry) -> Void

    @State private var ipAddress: String = ""
    @State private var hostname: String = ""
    @State private var category: String = "Custom"
    @State private var comment: String = ""
    @State private var isEnabled: Bool = true
    @State private var customCategoryText: String = ""
    @State private var isCustomCategory: Bool = false

    var isEditing: Bool {
        initialEntry != nil
    }

    var isValidIP: Bool {
        let entry = HostEntry(ipAddress: ipAddress, hostname: hostname)
        return entry.isValidIP
    }

    var isValidHostname: Bool {
        let entry = HostEntry(ipAddress: ipAddress, hostname: hostname)
        return entry.isValidHostname
    }

    var isValid: Bool {
        isValidIP && isValidHostname
    }

    init(
        entry: HostEntry? = nil,
        categories: [String] = [],
        onSave: @escaping (HostEntry) -> Void
    ) {
        self.initialEntry = entry
        self.existingCategories = categories
        self.onSave = onSave

        if let entry = entry {
            _ipAddress = State(initialValue: entry.ipAddress)
            _hostname = State(initialValue: entry.hostname)
            _category = State(initialValue: entry.category)
            _comment = State(initialValue: entry.comment)
            _isEnabled = State(initialValue: entry.isEnabled)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Host Mapping" : "Add Host Mapping")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()

            // Form Content
            Form {
                Section {
                    // IP Address Field
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("IP Address")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            if !ipAddress.isEmpty && !isValidIP {
                                Text("Invalid IP format")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        HStack {
                            TextField("e.g. 127.0.0.1 or ::1", text: $ipAddress)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            Menu("Presets") {
                                Button("127.0.0.1 (Loopback)") { ipAddress = "127.0.0.1" }
                                Button("0.0.0.0 (Block/Null)") { ipAddress = "0.0.0.0" }
                                Button("::1 (IPv6 Loopback)") { ipAddress = "::1" }
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 80)
                        }
                    }

                    // Hostname Field
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Hostname / Domain")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            if !hostname.isEmpty && !isValidHostname {
                                Text("Invalid hostname")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }

                        TextField("e.g. dev.local or myapp.test", text: $hostname)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Category Selector
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack {
                            if !isCustomCategory {
                                Picker("", selection: $category) {
                                    Text("Custom").tag("Custom")
                                    Text("Local Dev").tag("Local Dev")
                                    Text("Ad Block").tag("Ad Block")
                                    Text("Testing").tag("Testing")
                                    ForEach(existingCategories.filter { !["Custom", "Local Dev", "Ad Block", "Testing", "System"].contains($0) }, id: \.self) { cat in
                                        Text(cat).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)

                                Button("New Category...") {
                                    isCustomCategory = true
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                            } else {
                                TextField("Enter new category name", text: $customCategoryText)
                                    .textFieldStyle(.roundedBorder)

                                Button("Select Existing") {
                                    isCustomCategory = false
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                            }
                        }
                    }

                    // Comment Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes / Comment")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("Optional description or ticket link", text: $comment)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Enabled Toggle
                    Toggle("Enable this host mapping", isOn: $isEnabled)
                        .padding(.top, 4)
                }
            }
            .padding()

            Divider()

            // Action Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(isEditing ? "Save Changes" : "Add Host") {
                    saveEntry()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 440, height: 380)
    }

    private func saveEntry() {
        let finalCategory = isCustomCategory && !customCategoryText.isEmpty ? customCategoryText : category
        
        var updatedEntry = initialEntry ?? HostEntry(ipAddress: ipAddress, hostname: hostname)
        updatedEntry.ipAddress = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEntry.hostname = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEntry.category = finalCategory
        updatedEntry.comment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedEntry.isEnabled = isEnabled

        onSave(updatedEntry)
        dismiss()
    }
}
