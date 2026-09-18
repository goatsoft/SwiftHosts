import SwiftUI

struct HostListView: View {
    @ObservedObject var hostsManager: HostsManager
    @Binding var selectedEntryID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Category Title Header
            HStack {
                Text(hostsManager.selectedCategoryFilter ?? "All Hosts")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            // Slide-Down Alert Banner for Unsaved Changes
            if hostsManager.isDirty {
                HStack(spacing: 12) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Unsaved Changes Pending")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        Text("\(hostsManager.unsavedChangesCount) host entry edit(s) ready to save to /etc/hosts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Discard") {
                        withAnimation {
                            hostsManager.discardChanges()
                        }
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])

                    Button("Save Changes") {
                        hostsManager.saveHosts()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .keyboardShortcut("s", modifiers: .command)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.12))
                .overlay(Divider(), alignment: .bottom)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Main Table View
            if hostsManager.isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading /etc/hosts...")
                    Spacer()
                }
            } else if hostsManager.filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No host entries found")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button("Add Host Entry") {
                        hostsManager.addNewEmptyEntry()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
            } else {
                Table(hostsManager.filteredEntries, selection: $selectedEntryID) {
                    // Enabled Checkbox Column
                    TableColumn("") { entry in
                        Toggle("", isOn: Binding(
                            get: { entry.isEnabled },
                            set: { _ in hostsManager.toggleEntry(entry) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .disabled(entry.isSystem)
                    }
                    .width(min: 24, max: 28)

                    // IP Address Column
                    TableColumn("IP Address") { entry in
                        EditableIPCell(entry: entry, hostsManager: hostsManager)
                            .contextMenu {
                                HostRowContextMenu(entry: entry, hostsManager: hostsManager)
                            }
                    }
                    .width(min: 130, ideal: 160)

                    // Hostname Column
                    TableColumn("Hostname") { entry in
                        EditableHostnameCell(entry: entry, hostsManager: hostsManager)
                            .contextMenu {
                                HostRowContextMenu(entry: entry, hostsManager: hostsManager)
                            }
                    }
                    .width(min: 200, ideal: 280)

                    // Category Column
                    TableColumn("Category") { entry in
                        EditableCategoryCell(entry: entry, hostsManager: hostsManager)
                            .contextMenu {
                                HostRowContextMenu(entry: entry, hostsManager: hostsManager)
                            }
                    }
                    .width(min: 110, ideal: 135)

                    // Notes Column
                    TableColumn("Notes") { entry in
                        EditableCommentCell(entry: entry, hostsManager: hostsManager)
                            .contextMenu {
                                HostRowContextMenu(entry: entry, hostsManager: hostsManager)
                            }
                    }
                    .width(min: 180, ideal: 260)

                    // Actions Column
                    TableColumn("Actions") { entry in
                        RowActionsCell(entry: entry, hostsManager: hostsManager)
                            .contextMenu {
                                HostRowContextMenu(entry: entry, hostsManager: hostsManager)
                            }
                    }
                    .width(min: 60, max: 85)
                }
            }
        }
        .sheet(isPresented: $hostsManager.showingPasswordSheet) {
            AdminPasswordSheet(hostsManager: hostsManager)
        }
        .animation(.default, value: hostsManager.isDirty)
    }
}

// MARK: - Right-Click Context Menu View

struct HostRowContextMenu: View {
    let entry: HostEntry
    @ObservedObject var hostsManager: HostsManager
    @State private var isShowingNewCatSheet: Bool = false

    var body: some View {
        Group {
            if !entry.isSystem {
                Menu("Change Category") {
                    ForEach(hostsManager.userSelectableCategories, id: \.self) { cat in
                        Button {
                            hostsManager.updateCategory(id: entry.id, newCategory: cat)
                        } label: {
                            HStack {
                                Text(cat)
                                if cat == entry.category {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }

                    Divider()

                    Button("New Category...") {
                        isShowingNewCatSheet = true
                    }
                }
            }

            Button("Copy Hostname") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.hostname, forType: .string)
            }

            Button("Copy IP Address") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.ipAddress, forType: .string)
            }

            if !entry.isSystem {
                Button(entry.isEnabled ? "Disable Host" : "Enable Host") {
                    hostsManager.toggleEntry(entry)
                }

                Divider()

                Button("Delete Host", role: .destructive) {
                    hostsManager.removeEntry(entry)
                }
            }
        }
        .sheet(isPresented: $isShowingNewCatSheet) {
            NewCategorySheet(hostsManager: hostsManager) { newCatName in
                hostsManager.updateCategory(id: entry.id, newCategory: newCatName)
            }
        }
    }
}

// MARK: - Administrator Password Sheet (Session Authorization)

struct AdminPasswordSheet: View {
    @ObservedObject var hostsManager: HostsManager
    @State private var password: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Administrator Authorization")
                        .font(.headline)

                    Text("SwiftHosts requires administrator privileges to write to:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("/etc/hosts")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }

            if let error = hostsManager.passwordError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("Enter macOS Password", text: $password, onCommit: submit)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Password is cached in secure memory while SwiftHosts remains open.")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button("Cancel") {
                    hostsManager.showingPasswordSheet = false
                    dismiss()
                }
                Button("Authorize & Save") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(password.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func submit() {
        guard !password.isEmpty else { return }
        hostsManager.authenticateAndSave(password: password)
    }
}

// MARK: - Editable Grid Cells

struct EditableIPCell: View {
    let entry: HostEntry
    @ObservedObject var hostsManager: HostsManager
    @State private var draftIP: String = ""
    @State private var isHovered: Bool = false

    init(entry: HostEntry, hostsManager: HostsManager) {
        self.entry = entry
        self.hostsManager = hostsManager
        _draftIP = State(initialValue: entry.ipAddress)
    }

    var isDirty: Bool {
        draftIP != entry.ipAddress
    }

    var isValidIP: Bool {
        HostEntry(ipAddress: draftIP, hostname: entry.hostname).isValidIP
    }

    var body: some View {
        if entry.isSystem {
            Text(entry.ipAddress)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
        } else {
            HStack(spacing: 4) {
                TextField("IP Address", text: $draftIP, onCommit: commit)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isDirty ? Color.orange.opacity(0.12) : (isHovered ? Color.secondary.opacity(0.06) : Color.clear))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                isDirty ? Color.orange : (isHovered ? Color.secondary.opacity(0.35) : Color.clear),
                                lineWidth: isDirty ? 1.0 : (isHovered ? 0.8 : 0.0)
                            )
                    )
                    .onChange(of: draftIP) { _, newValue in
                        hostsManager.updateDraftIP(id: entry.id, newIP: newValue)
                    }

                if !draftIP.isEmpty && !isValidIP {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .help("Invalid IP address format")
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeIn(duration: 0.12)) {
                    isHovered = hovering
                }
            }
            .onChange(of: entry.ipAddress) { _, newIP in
                if draftIP != newIP {
                    draftIP = newIP
                }
            }
        }
    }

    private func commit() {
        if isValidIP {
            hostsManager.confirmRowChanges(id: entry.id)
        }
    }
}

struct EditableHostnameCell: View {
    let entry: HostEntry
    @ObservedObject var hostsManager: HostsManager
    @State private var draftHostname: String = ""
    @State private var isHovered: Bool = false

    init(entry: HostEntry, hostsManager: HostsManager) {
        self.entry = entry
        self.hostsManager = hostsManager
        _draftHostname = State(initialValue: entry.hostname)
    }

    var isDirty: Bool {
        draftHostname != entry.hostname
    }

    var isValidHostname: Bool {
        HostEntry(ipAddress: entry.ipAddress, hostname: draftHostname).isValidHostname
    }

    var body: some View {
        if entry.isSystem {
            HStack(spacing: 6) {
                Text(entry.hostname)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .help("System Protected Entry")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
        } else {
            HStack(spacing: 4) {
                TextField("hostname.local", text: $draftHostname, onCommit: commit)
                    .textFieldStyle(.plain)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isDirty ? Color.orange.opacity(0.12) : (isHovered ? Color.secondary.opacity(0.06) : Color.clear))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(
                                isDirty ? Color.orange : (isHovered ? Color.secondary.opacity(0.35) : Color.clear),
                                lineWidth: isDirty ? 1.0 : (isHovered ? 0.8 : 0.0)
                            )
                    )
                    .onChange(of: draftHostname) { _, newValue in
                        hostsManager.updateDraftHostname(id: entry.id, newHostname: newValue)
                    }

                if !draftHostname.isEmpty && !isValidHostname {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .help("Invalid hostname format")
                }
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeIn(duration: 0.12)) {
                    isHovered = hovering
                }
            }
            .onChange(of: entry.hostname) { _, newHost in
                if draftHostname != newHost {
                    draftHostname = newHost
                }
            }
        }
    }

    private func commit() {
        if isValidHostname {
            hostsManager.confirmRowChanges(id: entry.id)
        }
    }
}

struct EditableCategoryCell: View {
    let entry: HostEntry
    @ObservedObject var hostsManager: HostsManager

    @State private var isShowingColorPickerSheet: Bool = false
    @State private var isShowingNewCatSheet: Bool = false

    var pillColor: Color {
        hostsManager.categoryColor(for: entry.category)
    }

    var body: some View {
        HStack(spacing: 4) {
            if entry.isSystem || entry.category == "System" {
                // Non-interactive System category badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(pillColor)
                        .frame(width: 7, height: 7)
                    Text("System")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(pillColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(pillColor.opacity(0.15))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(pillColor.opacity(0.4), lineWidth: 1.0)
                )
            } else {
                Menu {
                    Section(header: Text("Assign Category")) {
                        ForEach(hostsManager.userSelectableCategories, id: \.self) { cat in
                            Button {
                                hostsManager.updateCategory(id: entry.id, newCategory: cat)
                            } label: {
                                HStack {
                                    Text(cat)
                                    if cat == entry.category {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        isShowingNewCatSheet = true
                    } label: {
                        Label("New Category...", systemImage: "plus")
                    }

                    Button {
                        isShowingColorPickerSheet = true
                    } label: {
                        Label("Customize Color...", systemImage: "paintpalette")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(pillColor)
                            .frame(width: 7, height: 7)

                        Text(entry.category)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(pillColor)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(pillColor.opacity(0.8))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(pillColor.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(pillColor.opacity(0.4), lineWidth: 1.0)
                    )
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
        .sheet(isPresented: $isShowingColorPickerSheet) {
            CategoryColorPickerSheet(category: entry.category, hostsManager: hostsManager)
        }
        .sheet(isPresented: $isShowingNewCatSheet) {
            NewCategorySheet(hostsManager: hostsManager) { newCatName in
                hostsManager.updateCategory(id: entry.id, newCategory: newCatName)
            }
        }
    }
}

struct CategoryColorPickerSheet: View {
    let category: String
    @ObservedObject var hostsManager: HostsManager
    @Environment(\.dismiss) private var dismiss

    @State private var oklabColor: OKLabColorValue
    @State private var mode: OKLabPickerMode = .polarOKLCH

    init(category: String, hostsManager: HostsManager) {
        self.category = category
        self.hostsManager = hostsManager

        if let raw = hostsManager.categoryColors[category] {
            if raw.hasPrefix("#") {
                let hexClean = raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
                var int: UInt64 = 0
                Scanner(string: hexClean).scanHexInt64(&int)
                let r = Double((int >> 16) & 0xFF) / 255.0
                let g = Double((int >> 8) & 0xFF) / 255.0
                let b = Double(int & 0xFF) / 255.0
                _oklabColor = State(initialValue: OKLabColorValue.from(srgbRed: r, green: g, blue: b))
                return
            } else if let option = CategoryColorOption(rawValue: raw) {
                let preset: OKLabColorValue
                switch option {
                case .red: preset = OKLabColorValue(lightness: 0.65, chroma: 0.20, hueDegrees: 25.0)
                case .orange: preset = OKLabColorValue(lightness: 0.70, chroma: 0.18, hueDegrees: 55.0)
                case .yellow: preset = OKLabColorValue(lightness: 0.82, chroma: 0.16, hueDegrees: 95.0)
                case .green: preset = OKLabColorValue(lightness: 0.75, chroma: 0.18, hueDegrees: 145.0)
                case .mint: preset = OKLabColorValue(lightness: 0.76, chroma: 0.16, hueDegrees: 165.0)
                case .teal: preset = OKLabColorValue(lightness: 0.72, chroma: 0.17, hueDegrees: 185.0)
                case .blue: preset = OKLabColorValue(lightness: 0.68, chroma: 0.19, hueDegrees: 240.0)
                case .indigo: preset = OKLabColorValue(lightness: 0.62, chroma: 0.22, hueDegrees: 275.0)
                case .purple: preset = OKLabColorValue(lightness: 0.62, chroma: 0.22, hueDegrees: 285.0)
                case .pink: preset = OKLabColorValue(lightness: 0.67, chroma: 0.21, hueDegrees: 330.0)
                }
                _oklabColor = State(initialValue: preset)
                return
            }
        }

        _oklabColor = State(initialValue: OKLabColorValue(lightness: 0.68, chroma: 0.19, hueDegrees: 240.0))
    }

    var body: some View {
        VStack(spacing: 12) {
            // Sheet Header: Title Top-Left + Close X Button Top-Right
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "paintpalette.fill")
                        .foregroundColor(oklabColor.color)
                        .font(.headline)

                    Text("'\(category)' Color")
                        .font(.headline)
                        .lineLimit(1)
                }

                Spacer()

                // Top-Right Close Button (X)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel (Escape)")
                .keyboardShortcut(.escape, modifiers: [])
            }

            // Main Color Picker Component (Hero Canvas)
            OKLabColorPicker(
                color: $oklabColor,
                mode: $mode,
                configuration: OKLabPickerConfiguration(
                    style: .inline,
                    title: nil,
                    showHeader: true,
                    showHexInput: true,
                    showColorMetrics: true,
                    allowedModes: OKLabPickerMode.allCases
                )
            )

            // Sheet Footer: Mode Tabs (Bottom-Left - Bigger!) + Confirm Checkmark (Bottom-Right - Bigger!)
            HStack(alignment: .center) {
                // Bottom-Left Mode Icon Tabs (Prominent & Easy to Tap)
                HStack(spacing: 4) {
                    ForEach(OKLabPickerMode.allCases) { item in
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                                mode = item
                            }
                        } label: {
                            Image(systemName: item.iconName)
                                .font(.system(size: 14, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(mode == item ? Color.primary.opacity(0.14) : Color.clear)
                                )
                                .foregroundColor(mode == item ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(item.rawValue)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.05))
                )

                Spacer()

                // Bottom-Right Prominent Accept Tick Button (✓)
                Button {
                    hostsManager.setCategoryColor(category: category, colorName: oklabColor.hexString)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(oklabColor.color)
                        .shadow(color: oklabColor.color.opacity(0.35), radius: 5, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .help("Apply Color (Return)")
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(14)
        .frame(width: 325)
    }
}

// MARK: - New Category Creation Sheet (Integrated OKLab Picker)

struct NewCategorySheet: View {
    @ObservedObject var hostsManager: HostsManager
    var onCreated: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var newCategoryName: String = ""
    @State private var oklabColor: OKLabColorValue = OKLabColorValue(lightness: 0.68, chroma: 0.19, hueDegrees: 240.0)
    @State private var mode: OKLabPickerMode = .perceptualSwatches

    var isReservedName: Bool {
        newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "system"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(oklabColor.color)
                        .font(.headline)

                    Text("Create New Category")
                        .font(.headline)
                }

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

            // Category Name Input
            VStack(alignment: .leading, spacing: 5) {
                Text("Category Name")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                TextField("e.g. Staging, Production, ClientA", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)

                if isReservedName {
                    Text("Category name 'System' is reserved.")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }

            // Configurable OKLab Color Picker (Dual-Mode: Swatches + 2D OKLCH Wheel)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Badge Color")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Mode Switcher Pills (Swatches <-> OKLCH Wheel)
                    HStack(spacing: 3) {
                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                                mode = .perceptualSwatches
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "square.grid.3x3.fill")
                                Text("Presets")
                            }
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(mode == .perceptualSwatches ? Color.primary.opacity(0.12) : Color.clear)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.75)) {
                                mode = .polarOKLCH
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "paintpalette.fill")
                                Text("Wheel")
                            }
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(mode == .polarOKLCH ? Color.primary.opacity(0.12) : Color.clear)
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(2)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(7)
                }

                OKLabColorPicker(
                    color: $oklabColor,
                    mode: $mode,
                    configuration: OKLabPickerConfiguration(
                        style: .card,
                        title: nil,
                        showHeader: true,
                        showHexInput: true,
                        showColorMetrics: true,
                        allowedModes: [.perceptualSwatches, .polarOKLCH]
                    )
                )
            }

            // Action Footer (Cancel / Create Category)
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !isReservedName {
                        hostsManager.setCategoryColor(category: trimmed, colorName: oklabColor.hexString)
                        onCreated?(trimmed)
                        dismiss()
                    }
                } label: {
                    Label("Create Category", systemImage: "plus.circle.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(oklabColor.color)
                .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isReservedName)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 340)
    }
}

struct EditableCommentCell: View {
    let entry: HostEntry
    @ObservedObject var hostsManager: HostsManager
    @State private var draftComment: String = ""
    @State private var isHovered: Bool = false

    init(entry: HostEntry, hostsManager: HostsManager) {
        self.entry = entry
        self.hostsManager = hostsManager
        _draftComment = State(initialValue: entry.comment)
    }

    var isDirty: Bool {
        draftComment != entry.comment
    }

    var body: some View {
        if entry.isSystem {
            Text(entry.comment)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
        } else {
            TextField("", text: $draftComment, onCommit: commit)
                .textFieldStyle(.plain)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDirty ? Color.orange.opacity(0.12) : (isHovered ? Color.secondary.opacity(0.06) : Color.clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isDirty ? Color.orange : (isHovered ? Color.secondary.opacity(0.35) : Color.clear),
                            lineWidth: isDirty ? 1.0 : (isHovered ? 0.8 : 0.0)
                        )
                )
                .onChange(of: draftComment) { _, newValue in
                    hostsManager.updateDraftComment(id: entry.id, newComment: newValue)
                }
                .onHover { hovering in
                    withAnimation(.easeIn(duration: 0.12)) {
                        isHovered = hovering
                    }
                }
                .onChange(of: entry.comment) { _, newCom in
                    if draftComment != newCom {
                        draftComment = newCom
                    }
                }
        }
    }

    private func commit() {
        hostsManager.confirmRowChanges(id: entry.id)
    }
}

// MARK: - Row Actions Cell (Confirm / Reset / Delete)

struct RowActionsCell: View {
    let entry: HostEntry
    @ObservedObject var hostsManager: HostsManager

    var isDirty: Bool {
        hostsManager.isRowDirty(id: entry.id)
    }

    var isValid: Bool {
        hostsManager.isRowValid(id: entry.id)
    }

    var body: some View {
        HStack(spacing: 4) {
            if isDirty {
                Button {
                    hostsManager.confirmRowChanges(id: entry.id)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(isValid ? .green : .gray)
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
                .help("Confirm Row Changes")

                Button {
                    hostsManager.resetRowChanges(id: entry.id)
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Discard Pending Row Changes")
            }

            if !entry.isSystem {
                Button {
                    hostsManager.removeEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Delete Host Entry")
            }
        }
    }
}
