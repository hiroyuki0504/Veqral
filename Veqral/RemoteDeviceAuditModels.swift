import Foundation

struct RemoteDeviceRecord: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var pairedAt: Date
    var lastSeenAt: Date?
    var stableClientID: String?
    var pushToken: String?
    var pushEnvironment: String?
    var pushBundleID: String?
    var pushLocale: String?
    var pushUpdatedAt: Date?
}

struct RemoteDeviceListResponse: Codable, Sendable {
    var devices: [RemoteDeviceRecord]
}

struct RemoteDeviceDisplayGroup: Identifiable, Equatable, Sendable {
    var id: String
    var primary: RemoteDeviceRecord
    var duplicates: [RemoteDeviceRecord]

    var duplicateCount: Int { duplicates.count }
}

struct RemoteAuditLogResponse: Codable, Sendable {
    var lines: [String]
}
