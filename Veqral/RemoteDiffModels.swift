import Foundation

struct RemoteGitDiffEntry: Codable, Equatable, Sendable {
    var path: String
    var additions: Int
    var deletions: Int
    var patch: String?
}

struct RemoteGitDiffResponse: Codable, Sendable {
    var files: [RemoteGitDiffEntry]
}
