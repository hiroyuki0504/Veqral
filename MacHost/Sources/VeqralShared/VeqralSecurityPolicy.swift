import Foundation

public enum VeqralRunApprovalState: String, Codable, Sendable {
    case notRequired
    case pending
    case granted
    case legacyGranted
}

public struct VeqralRunApprovalProvenance: Codable, Sendable, Equatable {
    public var state: VeqralRunApprovalState
    public var grantedAt: Date?
    public var grantedByDeviceID: String?

    public init(state: VeqralRunApprovalState, grantedAt: Date? = nil, grantedByDeviceID: String? = nil) {
        self.state = state
        self.grantedAt = grantedAt
        self.grantedByDeviceID = grantedByDeviceID
    }
}

public enum VeqralRunControlPolicy {
    private static let resumableStatuses: Set<String> = [
        "cancelled",
        "failed",
        "complete",
        "needsAttention"
    ]

    public static func isExecutionAuthorized(_ approvalState: VeqralRunApprovalState) -> Bool {
        approvalState == .notRequired || approvalState == .granted || approvalState == .legacyGranted
    }

    public static func canResume(status: String, approvalState: VeqralRunApprovalState) -> Bool {
        isExecutionAuthorized(approvalState) && resumableStatuses.contains(status)
    }

    public static func canStart(status: String, approvalState: VeqralRunApprovalState) -> Bool {
        status == "queued" && isExecutionAuthorized(approvalState)
    }

    // Compatibility helper for older call sites and persisted interim state.
    public static func canResume(status: String, approvalRequired: Bool = false) -> Bool {
        canResume(status: status, approvalState: approvalRequired ? .pending : .notRequired)
    }

    public static func canApprove(status: String) -> Bool {
        status == "waitingApproval"
    }
}

public enum VeqralPairingAccessPolicy {
    public static func canReadStatus(isLoopback: Bool) -> Bool {
        isLoopback
    }

    public static func hasSignedProof(endpoint: String?, signature: String?) -> Bool {
        let cleanEndpoint = endpoint?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanSignature = signature?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !cleanEndpoint.isEmpty && !cleanSignature.isEmpty
    }
}

public enum VeqralPairingEndpointPolicy {
    public static func endpoints(
        hostname: String,
        tailscaleIP: String?,
        interfaceIPv4: [String],
        port: Int
    ) -> [String] {
        var candidates: [String] = []
        let cleanHostname = hostname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanHostname.isEmpty {
            candidates.append("http://\(cleanHostname):\(port)")
        }
        if let tailscaleIP = tailscaleIP?.trimmingCharacters(in: .whitespacesAndNewlines),
           !tailscaleIP.isEmpty {
            candidates.append("http://\(tailscaleIP):\(port)")
        }
        let uniqueAddresses = Set(interfaceIPv4)
        for address in uniqueAddresses.filter(isPrivateLANIPv4).sorted() {
            candidates.append("http://\(address):\(port)")
        }
        for address in uniqueAddresses.filter(isLinkLocalIPv4).sorted() {
            candidates.append("http://\(address):\(port)")
        }

        var seen: Set<String> = []
        return candidates.filter { seen.insert($0).inserted }
    }

    private static func isPrivateLANIPv4(_ value: String) -> Bool {
        guard let parts = ipv4Parts(value) else { return false }
        if parts[0] == 10 { return true }
        if parts[0] == 172, (16...31).contains(parts[1]) { return true }
        return parts[0] == 192 && parts[1] == 168
    }

    private static func isLinkLocalIPv4(_ value: String) -> Bool {
        guard let parts = ipv4Parts(value) else { return false }
        return parts[0] == 169 && parts[1] == 254
    }

    private static func ipv4Parts(_ value: String) -> [Int]? {
        let parts = value.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else { return nil }
        return parts
    }
}

public enum VeqralRequestAuthPolicy {
    private static let mutatingMethods: Set<String> = ["POST", "PUT", "PATCH", "DELETE"]

    public static func requiresNonce(method: String) -> Bool {
        mutatingMethods.contains(method.uppercased())
    }
}

public enum VeqralReplayDecision: Equatable, Sendable {
    case accepted
    case replayed
    case invalidNonce
    case capacityUnavailable
}

public struct VeqralReplayWindow: Codable, Sendable {
    private struct Entry: Codable, Sendable {
        var deviceID: String
        var nonce: String
        var expiresAt: Date
    }

    private static let snapshotVersion = 1
    private var entries: [String: Entry]
    private var maximumEntries: Int

    public init(validityInterval: TimeInterval = 300, maximumEntries: Int = 10_000) {
        // validityInterval remains in the signature for source compatibility. Expiry is
        // supplied from the signed timestamp when consuming a request.
        _ = validityInterval
        self.entries = [:]
        self.maximumEntries = max(1, maximumEntries)
    }

    public mutating func consume(
        deviceID: String,
        nonce: String,
        signedAt: Date,
        signatureValidityInterval: TimeInterval = 300,
        now: Date = Date()
    ) -> VeqralReplayDecision {
        let cleanDeviceID = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNonce = nonce.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDeviceID.isEmpty, Self.isValidNonce(cleanNonce) else { return .invalidNonce }
        prune(now: now)
        let key = Self.key(deviceID: cleanDeviceID, nonce: cleanNonce)
        if entries[key] != nil { return .replayed }
        guard entries.count < maximumEntries else { return .capacityUnavailable }
        let expiresAt = signedAt.addingTimeInterval(signatureValidityInterval)
        guard expiresAt > now else { return .invalidNonce }
        entries[key] = Entry(deviceID: cleanDeviceID, nonce: cleanNonce, expiresAt: expiresAt)
        return .accepted
    }

    // Compatibility helper used by existing tests and callers that do not carry signedAt.
    public mutating func accept(deviceID: String, nonce: String, now: Date = Date()) -> Bool {
        let cleanDeviceID = deviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNonce = nonce.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanDeviceID.isEmpty, !cleanNonce.isEmpty else { return false }
        prune(now: now)
        let key = Self.key(deviceID: cleanDeviceID, nonce: cleanNonce)
        guard entries[key] == nil, entries.count < maximumEntries else { return false }
        entries[key] = Entry(deviceID: cleanDeviceID, nonce: cleanNonce, expiresAt: now.addingTimeInterval(300))
        return true
    }

    public mutating func prune(now: Date = Date()) {
        entries = entries.filter { $0.value.expiresAt > now }
    }

    public var acceptedCount: Int { entries.count }

    private static func isValidNonce(_ value: String) -> Bool {
        let bytes = Array(value.utf8)
        return (16...128).contains(bytes.count) && bytes.allSatisfy { (0x21...0x7e).contains($0) }
    }

    private static func key(deviceID: String, nonce: String) -> String {
        "\(deviceID)\n\(nonce)"
    }

    private enum CodingKeys: String, CodingKey {
        case version, entries, maximumEntries, acceptedAt, validityInterval
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.version) {
            let version = try container.decode(Int.self, forKey: .version)
            guard version == Self.snapshotVersion else {
                throw DecodingError.dataCorruptedError(forKey: .version, in: container, debugDescription: "Unsupported replay snapshot version")
            }
            let decoded = try container.decode([Entry].self, forKey: .entries)
            maximumEntries = max(1, try container.decodeIfPresent(Int.self, forKey: .maximumEntries) ?? 10_000)
            entries = Dictionary(uniqueKeysWithValues: decoded.map { (Self.key(deviceID: $0.deviceID, nonce: $0.nonce), $0) })
            return
        }

        // One-time conservative migration from the interim {validityInterval, acceptedAt} shape.
        let acceptedAt = try container.decode([String: Date].self, forKey: .acceptedAt)
        maximumEntries = 10_000
        entries = [:]
        for (legacyKey, accepted) in acceptedAt {
            let parts = legacyKey.split(separator: "\n", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            entries[legacyKey] = Entry(deviceID: parts[0], nonce: parts[1], expiresAt: accepted.addingTimeInterval(600))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.snapshotVersion, forKey: .version)
        try container.encode(entries.values.sorted { lhs, rhs in
            if lhs.deviceID != rhs.deviceID { return lhs.deviceID < rhs.deviceID }
            return lhs.nonce < rhs.nonce
        }, forKey: .entries)
        try container.encode(maximumEntries, forKey: .maximumEntries)
    }
}
