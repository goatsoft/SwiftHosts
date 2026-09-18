import SwiftUI

struct SidebarView: View {
    @ObservedObject var hostsManager: HostsManager
    @Binding var selectedFilter: String?

    @State private var categoryToEdit: String? = nil
    @State private var showingNewCategorySheet: Bool = false

    private var allCount: Int { hostsManager.entries.count }
    private var enabledCount: Int { hostsManager.entries.filter { $0.isEnabled }.count }
    private var disabledCount: Int { hostsManager.entries.filter { !$0.isEnabled }.count }
    private var systemCount: Int { hostsManager.entries.filter { $0.isSystem }.count }

    var body: some View {
        List(selection: $selectedFilter) {
            Section("Filters") {
                NavigationLink(value: "All") {
                    HStack {
                        Label("All Hosts", systemImage: "globe")
                            .foregroundColor(.primary)
                        Spacer()
                        BadgeView(count: allCount, color: .secondary)
                    }
                }
                .tag("All")

                NavigationLink(value: "Enabled") {
                    HStack {
                        Label("Enabled", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        BadgeView(count: enabledCount, color: .green)
                    }
                }
                .tag("Enabled")

                NavigationLink(value: "Disabled") {
                    HStack {
                        Label("Disabled", systemImage: "pause.circle.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        BadgeView(count: disabledCount, color: .secondary)
                    }
                }
                .tag("Disabled")

                NavigationLink(value: "System") {
                    HStack {
                        Label("System Protected", systemImage: "lock.shield.fill")
                            .foregroundColor(.primary)
                        Spacer()
                        BadgeView(count: systemCount, color: .orange)
                    }
                }
                .tag("System")
            }

            Section {
                ForEach(hostsManager.categories.filter { $0 != "System" }, id: \.self) { category in
                    let count = hostsManager.entries.filter { $0.category == category }.count
                    let catColor = hostsManager.categoryColor(for: category)
                    
                    SidebarCategoryRow(
                        category: category,
                        count: count,
                        catColor: catColor,
                        onEdit: {
                            categoryToEdit = category
                        }
                    )
                    .tag(category)
                }
            } header: {
                HStack {
                    Text("Categories")
                    Spacer()
                    Button {
                        showingNewCategorySheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Add new category")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Hosts Settings")
        .sheet(item: Binding(
            get: { categoryToEdit.map { CategoryItem(name: $0) } },
            set: { categoryToEdit = $0?.name }
        )) { item in
            EditCategorySheet(hostsManager: hostsManager, categoryName: item.name)
        }
        .sheet(isPresented: $showingNewCategorySheet) {
            NewCategorySheet(hostsManager: hostsManager) { newCatName in
                selectedFilter = newCatName
            }
        }
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

struct BadgeView: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.15)))
    }
}

struct CategoryItem: Identifiable {
    var id: String { name }
    let name: String
}

struct SidebarCategoryRow: View {
    let category: String
    let count: Int
    let catColor: Color
    let onEdit: () -> Void
    
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .foregroundColor(catColor)

            Text(category)
                .fontWeight(.medium)

            Spacer()

            if isHovered {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit Category")
            }

            BadgeView(count: count, color: catColor)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeIn(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

struct EditCategorySheet: View {
    @ObservedObject var hostsManager: HostsManager
    let categoryName: String
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""
    @State private var selectedColorOption: CategoryColorOption = .blue

    init(hostsManager: HostsManager, categoryName: String) {
        self.hostsManager = hostsManager
        self.categoryName = categoryName
        _newName = State(initialValue: categoryName)
        _selectedColorOption = State(initialValue: hostsManager.categoryColorOption(for: categoryName))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Category '\(categoryName)'")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Category Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Category name", text: $newName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Category Color")
                    .font(.caption)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 10) {
                    ForEach(CategoryColorOption.allCases, id: \.self) { option in
                        Button {
                            selectedColorOption = option
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 28, height: 28)
                                if selectedColorOption == option {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button(role: .destructive) {
                    hostsManager.deleteCategory(name: categoryName)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Save") {
                    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        if trimmed != categoryName {
                            hostsManager.renameCategory(oldName: categoryName, newName: trimmed, colorName: selectedColorOption.rawValue)
                        } else {
                            hostsManager.setCategoryColor(category: categoryName, colorName: selectedColorOption.rawValue)
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 300)
    }
}
