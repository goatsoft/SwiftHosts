import Foundation
import Combine
import SwiftUI

@MainActor
final class HostsManager: ObservableObject {
    @Published var entries: [HostEntry] = []
    @Published var originalEntries: [HostEntry] = []
    
    @Published var selectedCategoryFilter: String? = nil
    @Published var searchText: String = ""
    
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var isFlushingDNS: Bool = false
    
    @Published var errorMessage: String? = nil
    @Published var statusMessage: String? = nil
    @Published var lastSavedDate: Date? = nil
    
    private var fileSource: DispatchSourceFileSystemObject?
    private let hostsFilePath = "/etc/hosts"
    
    var isDirty: Bool {
        entries != originalEntries
    }
    
    var categories: [String] {
        let cats = Set(entries.map { $0.category })
        return Array(cats).sorted()
    }
    
    var filteredEntries: [HostEntry] {
        entries.filter { entry in
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
    }
    
    init() {
        loadHosts()
        startFileWatcher()
    }
    
    deinit {
        fileSource?.cancel()
    }

    /// Reloads hosts file from disk
    func loadHosts() {
        isLoading = true
        errorMessage = nil
        
        do {
            let content = try String(contentsOfFile: hostsFilePath, encoding: .utf8)
            let parsed = HostsFileParser.parse(content: content)
            self.entries = parsed
            self.originalEntries = parsed
            self.statusMessage = "Loaded \(parsed.count) entries from \(hostsFilePath)"
        } catch {
            self.errorMessage = "Failed to read /etc/hosts: \(error.localizedDescription)"
            // Fallback to system default entries if unreadable
            self.entries = HostEntry.systemDefaults
            self.originalEntries = HostEntry.systemDefaults
        }
        
        isLoading = false
    }

    /// Saves pending modifications back to /etc/hosts via administrator authentication
    func saveHosts() {
        guard isDirty else {
            statusMessage = "No changes to save"
            return
        }
        
        isSaving = true
        errorMessage = nil
        
        // 1. Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("swifthosts_\(UUID().uuidString).txt")
        let hostsString = HostsFileParser.generateHostsContent(from: entries)
        
        do {
            try backupCurrentHostsFile()
            try hostsString.write(to: tempFile, atomically: true, encoding: .utf8)
            
            // 2. Privileged copy via osascript
            let script = "do shell script \"cp '\(tempFile.path)' '\(hostsFilePath)' && chmod 644 '\(hostsFilePath)'\" with administrator privileges"
            
            DispatchQueue.global(qos: .userInitiated).async {
                var errorInfo: NSDictionary?
                if let appleScript = NSAppleScript(source: script) {
                    _ = appleScript.executeAndReturnError(&errorInfo)
                    
                    DispatchQueue.main.async {
                        self.isSaving = false
                        // Clean temp file
                        try? FileManager.default.removeItem(at: tempFile)
                        
                        if let error = errorInfo {
                            let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "Authorization failed"
                            self.errorMessage = "Failed to save /etc/hosts: \(errorMsg)"
                        } else {
                            self.originalEntries = self.entries
                            self.lastSavedDate = Date()
                            self.statusMessage = "Successfully updated /etc/hosts"
                            self.flushDNSCacheInternal(showStatus: false)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isSaving = false
                        self.errorMessage = "Failed to initialize security authorization script"
                    }
                }
            }
        } catch {
            isSaving = false
            errorMessage = "Error writing temp hosts file: \(error.localizedDescription)"
        }
    }

    /// Flushes macOS DNS Cache
    func flushDNSCache() {
        isFlushingDNS = true
        errorMessage = nil
        flushDNSCacheInternal(showStatus: true)
    }
    
    private func flushDNSCacheInternal(showStatus: Bool) {
        let script = "do shell script \"dscacheutil -flushcache; killall -HUP mDNSResponder\" with administrator privileges"
        
        DispatchQueue.global(qos: .userInitiated).async {
            var errorInfo: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                _ = appleScript.executeAndReturnError(&errorInfo)
                
                DispatchQueue.main.async {
                    self.isFlushingDNS = false
                    if let error = errorInfo {
                        let msg = error[NSAppleScript.errorMessage] as? String ?? "DNS Flush failed"
                        self.errorMessage = "DNS Flush warning: \(msg)"
                    } else if showStatus {
                        self.statusMessage = "DNS Cache successfully flushed"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isFlushingDNS = false
                }
            }
        }
    }

    /// Reverts unsaved changes back to original state
    func discardChanges() {
        entries = originalEntries
        statusMessage = "Reverted changes"
    }

    /// Adds a new host entry
    func addEntry(_ entry: HostEntry) {
        entries.append(entry)
        statusMessage = "Added host '\(entry.hostname)'"
    }

    /// Updates existing host entry
    func updateEntry(_ entry: HostEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            statusMessage = "Updated '\(entry.hostname)'"
        }
    }

    /// Removes host entries by indices or IDs
    func removeEntries(at offsets: IndexSet) {
        let filtered = filteredEntries
        let toRemove = offsets.map { filtered[$0] }
        entries.removeAll { item in toRemove.contains(where: { $0.id == item.id }) }
        statusMessage = "Removed \(toRemove.count) entry(entries)"
    }

    func removeEntry(_ entry: HostEntry) {
        entries.removeAll { $0.id == entry.id }
        statusMessage = "Removed '\(entry.hostname)'"
    }

    /// Toggles enabled state of host entry
    func toggleEntry(_ entry: HostEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index].isEnabled.toggle()
        }
    }

    /// Import entries from an external file content or string
    func importEntries(from rawContent: String) {
        let imported = HostsFileParser.parse(content: rawContent)
        var addedCount = 0
        for item in imported {
            if !entries.contains(where: { $0.ipAddress == item.ipAddress && $0.hostname == item.hostname }) {
                entries.append(item)
                addedCount += 1
            }
        }
        statusMessage = "Imported \(addedCount) new entries"
    }

    /// Generates export string
    func exportHostsContent() -> String {
        return HostsFileParser.generateHostsContent(from: entries)
    }

    // MARK: - Helper Methods

    private func backupCurrentHostsFile() throws {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let backupDir = appSupport.appendingPathComponent("SwiftHosts/Backups", isDirectory: true)
        
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
            // Only auto-reload if user hasn't made unsaved pending edits
            if !self.isDirty {
                self.loadHosts()
            }
        }
        
        fileSource?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileSource?.resume()
    }
}
