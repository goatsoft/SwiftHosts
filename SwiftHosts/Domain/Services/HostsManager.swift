import Foundation
import Combine
import SwiftUI
import AppKit

@MainActor
final class HostsManager: ObservableObject {
    @Published var entries: [HostEntry] = []
    @Published var originalEntries: [HostEntry] = []
    @Published var draftEntries: [UUID: HostEntry] = [:]

    @Published var selectedCategoryFilter: String? = nil
    @Published var searchText: String = ""

    @Published var isUnlocked: Bool = false
    @Published var showingPasswordSheet: Bool = false
    @Published var passwordError: String? = nil

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var isFlushingDNS: Bool = false

    @Published var errorMessage: String? = nil
    @Published var statusMessage: String? = nil
    @Published var lastSavedDate: Date? = nil

    @Published var categoryColors: [String: String] = [
        "System": "orange",
        "General": "blue",
        "Local Dev": "teal",
        "Ad Block": "red",
        "Testing": "purple",
        "Custom": "indigo"
    ] {
        didSet {
            saveCategoriesToDisk()
        }
    }

    private var sessionPassword: String? = nil
    private var fileSource: DispatchSourceFileSystemObject?
    private let hostsFilePath = "/etc/hosts"
    private var isInternalWriting: Bool = false

    private var appSupportDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SwiftHosts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var categoriesConfigFile: URL {
        appSupportDir.appendingPathComponent("categories.json")
    }

    var isDirty: Bool {
        entries != originalEntries || !draftEntries.isEmpty
    }

    var unsavedChangesCount: Int {
        var count = 0
        for entry in entries {
            if !originalEntries.contains(entry) {
                count += 1
            }
        }
        for orig in originalEntries {
            if !entries.contains(where: { $0.id == orig.id }) {
                count += 1
            }
        }
        return count + draftEntries.count
    }

    var categories: [String] {
        let cats = Set(entries.map { $0.category } + Array(categoryColors.keys))
        return Array(cats).sorted()
    }

    var userSelectableCategories: [String] {
        categories.filter { $0.lowercased() != "system" }
    }

    var filteredEntries: [HostEntry] {
        let matched = entries.filter { entry in
            // Category filter
            if let filter = selectedCategoryFilter {
                if filter == "Enabled" && !entry.isEnabled { return false }
                if filter == "Disabled" && entry.isEnabled { return false }
                if filter == "System" && !entry.isSystem { return false }
                if filter != "All" && filter != "Enabled" && filter != "Disabled" && filter != "System" && entry.category != filter {
                    return false
                }
            }

            // Search filter
            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesHost = entry.hostname.lowercased().contains(query)
                let matchesIP = entry.ipAddress.lowercased().contains(query)
                let matchesComment = entry.comment.lowercased().contains(query)
                let matchesCategory = entry.category.lowercased().contains(query)
                return matchesHost || matchesIP || matchesComment || matchesCategory
            }

            return true
        }

        // Default ordering: Regular user hosts first, System protected hosts at the bottom
        return matched.sorted { a, b in
            if a.isSystem != b.isSystem {
                return !a.isSystem && b.isSystem
            }
            return false
        }
    }

    init() {
        loadCategoriesFromDisk()
        loadHosts()
        startFileWatcher()
    }

    deinit {
        sessionPassword = nil
        fileSource?.cancel()
    }

    func lockSession() {
        sessionPassword = nil
        isUnlocked = false
        statusMessage = "Session locked. Administrator authorization will be requested on next save."
    }

    func categoryColor(for category: String) -> Color {
        if category.lowercased() == "system" { return CategoryColorOption.orange.color }
        if let raw = categoryColors[category] {
            if raw.hasPrefix("#") {
                return Color(hex: raw)
            } else if let option = CategoryColorOption(rawValue: raw) {
                return option.color
            }
        }

        let palette: [CategoryColorOption] = [.blue, .purple, .pink, .red, .teal, .green, .indigo, .mint, .yellow, .orange]
        let index = abs(category.hashValue) % palette.count
        let assigned = palette[index]
        categoryColors[category] = assigned.rawValue
        return assigned.color
    }

    func categoryColorOption(for category: String) -> CategoryColorOption {
        if category == "System" { return .orange }
        if let colorRaw = categoryColors[category], let option = CategoryColorOption(rawValue: colorRaw) {
            return option
        }

        let palette: [CategoryColorOption] = [.blue, .purple, .pink, .red, .teal, .green, .indigo, .mint, .yellow, .orange]
        let index = abs(category.hashValue) % palette.count
        let assigned = palette[index]
        categoryColors[category] = assigned.rawValue
        return assigned
    }

    func setCategoryColor(category: String, colorName: String) {
        guard category.lowercased() != "system" else { return }
        categoryColors[category] = colorName
        saveCategoriesToDisk()
    }

    func renameCategory(oldName: String, newName: String, colorName: String) {
        guard oldName.lowercased() != "system", newName.lowercased() != "system" else { return }
        categoryColors.removeValue(forKey: oldName)
        categoryColors[newName] = colorName
        saveCategoriesToDisk()

        for index in entries.indices {
            if entries[index].category == oldName {
                entries[index].category = newName
            }
        }
        for (id, draft) in draftEntries {
            if draft.category == oldName {
                var updated = draft
                updated.category = newName
                draftEntries[id] = updated
            }
        }
        if selectedCategoryFilter == oldName {
            selectedCategoryFilter = newName
        }
        statusMessage = "Renamed category '\(oldName)' to '\(newName)' (Unsaved)"
    }

    func deleteCategory(name: String) {
        guard name.lowercased() != "system" else { return }
        categoryColors.removeValue(forKey: name)
        saveCategoriesToDisk()

        for index in entries.indices {
            if entries[index].category == name {
                entries[index].category = "Custom"
            }
        }
        if selectedCategoryFilter == name {
            selectedCategoryFilter = "All"
        }
        statusMessage = "Deleted category '\(name)'. Hosts reassigned to Custom. (Unsaved)"
    }

    func saveCategoriesToDisk() {
        if let data = try? JSONEncoder().encode(categoryColors) {
            try? data.write(to: categoriesConfigFile)
        }
    }

    private func loadCategoriesFromDisk() {
        if FileManager.default.fileExists(atPath: categoriesConfigFile.path),
           let data = try? Data(contentsOf: categoriesConfigFile),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            self.categoryColors.merge(decoded) { (_, new) in new }
        }
    }

    /// Reloads hosts file from disk safely
    func loadHosts() {
        guard !isInternalWriting else { return }

        isLoading = true
        errorMessage = nil
        draftEntries.removeAll()

        do {
            let content = try String(contentsOfFile: hostsFilePath, encoding: .utf8)
            let parsed = HostsFileParser.parse(content: content)
            self.entries = parsed
            self.originalEntries = parsed
            self.statusMessage = "Loaded \(parsed.count) entries from \(hostsFilePath)"
        } catch {
            self.errorMessage = "Failed to read /etc/hosts: \(error.localizedDescription)"
            self.entries = HostEntry.systemDefaults
            self.originalEntries = HostEntry.systemDefaults
        }

        isLoading = false
    }

    // MARK: - Category & Host Entry Updating (In-Memory)

    func updateCategory(id: UUID, newCategory: String) {
        guard newCategory.lowercased() != "system" else { return }
        if let index = entries.firstIndex(where: { $0.id == id }) {
            guard !entries[index].isSystem else { return }
            entries[index].category = newCategory
            if var draft = draftEntries[id] {
                draft.category = newCategory
                draftEntries[id] = draft
            }
            statusMessage = "Updated category for '\(entries[index].hostname)' to '\(newCategory)'"
        }
    }

    // MARK: - Draft Management for In-Line Grid Editing

    func updateDraftIP(id: UUID, newIP: String) {
        if var draft = draftEntries[id] ?? entries.first(where: { $0.id == id }) {
            guard !draft.isSystem else { return }
            draft.ipAddress = newIP
            draftEntries[id] = draft
        }
    }

    func updateDraftHostname(id: UUID, newHostname: String) {
        if var draft = draftEntries[id] ?? entries.first(where: { $0.id == id }) {
            guard !draft.isSystem else { return }
            draft.hostname = newHostname
            draftEntries[id] = draft
        }
    }

    func updateDraftCategory(id: UUID, newCategory: String) {
        guard newCategory.lowercased() != "system" else { return }
        if var draft = draftEntries[id] ?? entries.first(where: { $0.id == id }) {
            guard !draft.isSystem else { return }
            draft.category = newCategory
            draftEntries[id] = draft
        }
    }

    func updateDraftComment(id: UUID, newComment: String) {
        if var draft = draftEntries[id] ?? entries.first(where: { $0.id == id }) {
            guard !draft.isSystem else { return }
            draft.comment = newComment
            draftEntries[id] = draft
        }
    }

    func isRowDirty(id: UUID) -> Bool {
        guard let draft = draftEntries[id], let original = entries.first(where: { $0.id == id }) else {
            return false
        }
        return draft.ipAddress != original.ipAddress ||
               draft.hostname != original.hostname ||
               draft.category != original.category ||
               draft.comment != original.comment
    }

    func isRowValid(id: UUID) -> Bool {
        guard let draft = draftEntries[id] else { return true }
        return draft.isValid
    }

    func confirmRowChanges(id: UUID) {
        guard let draft = draftEntries[id] else { return }
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index] = draft
            draftEntries.removeValue(forKey: id)
            statusMessage = "Confirmed changes for '\(draft.hostname)'"
        }
    }

    func resetRowChanges(id: UUID) {
        draftEntries.removeValue(forKey: id)
        statusMessage = "Reset row changes"
    }

    func addNewEmptyEntry() {
        var cat = "Custom"
        if let selected = selectedCategoryFilter, !["All", "Enabled", "Disabled", "System"].contains(selected) {
            cat = selected
        }
        let newEntry = HostEntry(
            ipAddress: "127.0.0.1",
            hostname: "newhost.local",
            comment: "",
            isEnabled: true,
            category: cat
        )
        entries.insert(newEntry, at: 0)
        statusMessage = "Added new host row. Edit in-line and click Save Changes when ready."
    }

    /// Saves all accumulated in-memory changes back to /etc/hosts (0 prompts after 1st authorization)
    func saveHosts() {
        // Confirm all valid draft row changes first
        for (id, _) in draftEntries {
            if isRowValid(id: id) {
                guard let draft = draftEntries[id] else { continue }
                if let index = entries.firstIndex(where: { $0.id == id }) {
                    entries[index] = draft
                }
            }
        }
        draftEntries.removeAll()

        guard entries != originalEntries else {
            statusMessage = "No changes to save"
            return
        }

        if let cachedPassword = sessionPassword {
            // Already authorized this session: 0 PROMPTS!
            performSaveWithPassword(cachedPassword)
        } else {
            // First save in this session: prompt ONCE
            passwordError = nil
            showingPasswordSheet = true
        }
    }

    func authenticateAndSave(password: String) {
        performSaveWithPassword(password)
    }

    private func performSaveWithPassword(_ password: String) {
        isSaving = true
        isInternalWriting = true
        errorMessage = nil

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("swifthosts_\(UUID().uuidString).txt")
        let hostsString = HostsFileParser.generateHostsContent(from: entries)

        do {
            try backupCurrentHostsFile()
            try hostsString.write(to: tempFile, atomically: true, encoding: .utf8)

            let command = "cp '\(tempFile.path)' '\(hostsFilePath)' && chmod 644 '\(hostsFilePath)'"

            executeSudoCommand(command, password: password) { [weak self] result in
                guard let self = self else { return }
                self.isSaving = false
                try? FileManager.default.removeItem(at: tempFile)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.isInternalWriting = false
                }

                switch result {
                case .success:
                    // Store password in memory for active app session -> 0 PROMPTS ON SUBSEQUENT SAVES!
                    self.sessionPassword = password
                    self.isUnlocked = true
                    self.showingPasswordSheet = false
                    self.originalEntries = self.entries
                    self.draftEntries.removeAll()
                    self.lastSavedDate = Date()
                    self.statusMessage = "Successfully saved all changes to /etc/hosts"
                    self.flushDNSCacheInternal(showStatus: false)
                case .failure:
                    self.sessionPassword = nil
                    self.isUnlocked = false
                    self.passwordError = "Authentication failed: Incorrect password."
                    self.showingPasswordSheet = true
                }
            }
        } catch {
            isSaving = false
            isInternalWriting = false
            errorMessage = "Error preparing temp hosts file: \(error.localizedDescription)"
        }
    }

    private func executeSudoCommand(_ shellCmd: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            task.arguments = ["-S", "/bin/sh", "-c", shellCmd]

            let inputPipe = Pipe()
            let errorPipe = Pipe()
            task.standardInput = inputPipe
            task.standardError = errorPipe

            do {
                try task.run()

                if let data = (password + "\n").data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(data)
                    try? inputPipe.fileHandleForWriting.close()
                }

                task.waitUntilExit()

                if task.terminationStatus == 0 {
                    DispatchQueue.main.async { completion(.success(())) }
                } else {
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errStr = String(data: errData, encoding: .utf8) ?? "Authentication failed"
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "SwiftHosts", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errStr])))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// Flushes macOS DNS Cache safely
    func flushDNSCache() {
        isFlushingDNS = true
        errorMessage = nil
        flushDNSCacheInternal(showStatus: true)
    }

    private func flushDNSCacheInternal(showStatus: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/dscacheutil")
            task.arguments = ["-flushcache"]
            try? task.run()
            task.waitUntilExit()

            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            killTask.arguments = ["-HUP", "mDNSResponder"]
            try? task.run()
            killTask.waitUntilExit()

            DispatchQueue.main.async {
                self.isFlushingDNS = false
                if showStatus {
                    self.statusMessage = "DNS Cache successfully flushed"
                }
            }
        }
    }

    /// Reverts unsaved changes back to original state
    func discardChanges() {
        entries = originalEntries
        draftEntries.removeAll()
        statusMessage = "Reverted all unsaved changes"
    }

    /// Adds a new host entry (In-Memory)
    func addEntry(_ entry: HostEntry) {
        entries.append(entry)
        statusMessage = "Added host '\(entry.hostname)' (Unsaved)"
    }

    /// Updates existing host entry (In-Memory)
    func updateEntry(_ entry: HostEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            guard !entries[index].isSystem else { return }
            entries[index] = entry
            draftEntries.removeValue(forKey: entry.id)
            statusMessage = "Updated '\(entry.hostname)' (Unsaved)"
        }
    }

    /// Removes host entries by indices or IDs (In-Memory)
    func removeEntries(at offsets: IndexSet) {
        let filtered = filteredEntries
        let toRemove = offsets.map { filtered[$0] }.filter { !$0.isSystem }
        entries.removeAll { item in toRemove.contains(where: { $0.id == item.id }) }
        for item in toRemove {
            draftEntries.removeValue(forKey: item.id)
        }
        statusMessage = "Removed \(toRemove.count) entry(entries) (Unsaved)"
    }

    func removeEntry(_ entry: HostEntry) {
        guard !entry.isSystem else { return }
        entries.removeAll { $0.id == entry.id }
        draftEntries.removeValue(forKey: entry.id)
        statusMessage = "Removed '\(entry.hostname)' (Unsaved)"
    }

    /// Toggles enabled state of host entry (In-Memory)
    func toggleEntry(_ entry: HostEntry) {
        guard !entry.isSystem else { return }
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].isEnabled.toggle()
            statusMessage = "Toggled '\(entry.hostname)' (Unsaved)"
        }
    }

    /// Import entries from an external file content or string (In-Memory safely - NEVER wipes existing hosts!)
    func importEntries(from rawContent: String) {
        let imported = HostsFileParser.parse(content: rawContent)
        var addedCount = 0
        for item in imported {
            // Safely merge new entries without wiping any existing hosts
            if !entries.contains(where: { $0.ipAddress == item.ipAddress && $0.hostname == item.hostname }) {
                var newItem = item
                if newItem.category.lowercased() == "system" {
                    newItem.category = "Custom"
                }
                entries.append(newItem)
                addedCount += 1
            }
        }
        statusMessage = "Imported \(addedCount) new entries into existing hosts list (Unsaved)"
    }

    /// Generates export string
    func exportHostsContent() -> String {
        return HostsFileParser.generateHostsContent(from: entries)
    }

    // MARK: - Safe Backup & File Watcher

    private func backupCurrentHostsFile() throws {
        let backupDir = appSupportDir.appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())

        let backupFile = backupDir.appendingPathComponent("hosts_\(timestamp).bak")

        if FileManager.default.fileExists(atPath: hostsFilePath) {
            let content = try String(contentsOfFile: hostsFilePath, encoding: .utf8)
            try content.write(to: backupFile, atomically: true, encoding: .utf8)
        }
    }

    private func startFileWatcher() {
        let fileDescriptor = open(hostsFilePath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        fileSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend],
            queue: DispatchQueue.main
        )

        fileSource?.setEventHandler { [weak self] in
            guard let self = self else { return }
            if !self.isInternalWriting && !self.isDirty {
                self.loadHosts()
            }
        }

        fileSource?.setCancelHandler {
            close(fileDescriptor)
        }

        fileSource?.resume()
    }
}
