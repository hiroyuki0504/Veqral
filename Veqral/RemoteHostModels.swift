import Foundation

struct RemoteHostConfiguration: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var endpoint: String
    var deviceID: String
    var token: String
    var name: String

    var isPaired: Bool {
        !endpoint.isEmpty && !deviceID.isEmpty && !token.isEmpty
    }

    var displayEndpoint: String {
        endpoint.isEmpty ? L10n.tr("Not Paired") : endpoint
    }

    static let empty = RemoteHostConfiguration(
        isEnabled: false,
        endpoint: "",
        deviceID: "",
        token: "",
        name: ""
    )
}

struct RemoteSimpleResponse: Codable, Sendable {
    var ok: Bool
}

struct RemotePairResponse: Codable, Sendable {
    var deviceID: String
    var token: String
}

struct RemotePushTokenResponse: Codable, Sendable {
    var ok: Bool
}

struct RemoteHealthResponse: Codable, Sendable {
    var status: String
    var host: String
    var tailscaleIP: String?
    var port: UInt16
    var hermesVersion: String
    var toolStatuses: [RemoteCLIToolStatus]?
    var telemetry: RemoteHostTelemetry?
}
