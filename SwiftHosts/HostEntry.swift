import Foundation

/// Represents a single host mapping entry in the hosts file.
struct HostEntry: Identifiable, Codable, Hashable, Equatable {
    var id: UUID = UUID()
    var ipAddress: String
    var hostname: String
    var comment: String
    var isEnabled: Bool
    var isSystem: Bool
    var category: String

    init(
        id: UUID = UUID(),
        ipAddress: String,
        hostname: String,
        comment: String = "",
        isEnabled: Bool = true,
        isSystem: Bool = false,
        category: String = "Custom"
    ) {
        self.id = id
        self.ipAddress = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hostname = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        self.comment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isEnabled = isEnabled
        self.isSystem = isSystem
        self.category = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : category
    }

    /// Validates if the IP address is a valid IPv4 or IPv6 string.
    var isValidIP: Bool {
        let trimmed = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        
        // IPv4 check
        var sin = sockaddr_in()
        if inet_pton(AF_INET, trimmed, &sin.sin_addr) == 1 {
            return true
        }
        // IPv6 check
        var sin6 = sockaddr_in6()
        if inet_pton(AF_INET6, trimmed, &sin6.sin6_addr) == 1 {
            return true
        }
        return false
    }

    /// Validates if hostname is non-empty and formatted correctly.
    var isValidHostname: Bool {
        let trimmed = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        // Basic hostname validation (no spaces or illegal characters)
        let invalidChars = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "/:\\?#"))
        return trimmed.rangeOfCharacter(from: invalidChars) == nil
    }

    var isValid: Bool {
        isValidIP && isValidHostname
    }
}

extension HostEntry {
    /// Standard system host entries that should be preserved.
    static let systemDefaults: [HostEntry] = [
        HostEntry(ipAddress: "127.0.0.1", hostname: "localhost", comment: "Local Loopback", isEnabled: true, isSystem: true, category: "System"),
        HostEntry(ipAddress: "255.255.255.255", hostname: "broadcasthost", comment: "Broadcast Host", isEnabled: true, isSystem: true, category: "System"),
        HostEntry(ipAddress: "::1", hostname: "localhost", comment: "IPv6 Loopback", isEnabled: true, isSystem: true, category: "System")
    ]
}
