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

struct RemoteGitHubStatus: Codable, Equatable, Sendable {
    var workingDirectory: String
    var gitRoot: String
    var branch: String
    var remote: String
    var changedFiles: Int
    var aheadBehind: String
    var ghAuthenticated: Bool
    var pullRequestURL: String
    var pullRequestState: String
    var checksSummary: String
    var error: String?

    static let empty = RemoteGitHubStatus(
        workingDirectory: "",
        gitRoot: "",
        branch: "",
        remote: "",
        changedFiles: 0,
        aheadBehind: "",
        ghAuthenticated: false,
        pullRequestURL: "",
        pullRequestState: "Not loaded",
        checksSummary: "Not loaded",
        error: nil
    )
}

struct RemoteDraftPRResponse: Codable, Sendable {
    var ok: Bool
    var url: String
}
