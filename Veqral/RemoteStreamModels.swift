import Foundation

struct RemoteHostLogEvent: Codable, Sendable {
    var runID: String
    var kind: String
    var stream: String
    var message: String
    var createdAt: Date
    var sessionID: String?
    var exitCode: Int32?
}

enum RemoteStreamPhase: String, Equatable {
    case idle
    case connecting
    case connected
    case reconnecting
    case disconnected
}

struct RemoteStreamStatus: Equatable {
    var phase: RemoteStreamPhase
    var runID: UUID?
    var runTitle: String
    var detail: String
    var attempt: Int
    var nextRetrySeconds: Int?

    static let idle = RemoteStreamStatus(
        phase: .idle,
        runID: nil,
        runTitle: "",
        detail: "",
        attempt: 0,
        nextRetrySeconds: nil
    )
}
