import Foundation

struct RemoteArtifactRecord: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var type: String
    var path: String
    var bytes: Int
    var updatedAt: Date?
}

struct RemoteArtifactListResponse: Codable, Sendable {
    var artifacts: [RemoteArtifactRecord]
}

struct RemoteArtifactContentResponse: Codable, Sendable {
    var artifactID: String
    var mimeType: String
    var data: Data
}
