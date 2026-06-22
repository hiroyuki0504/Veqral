import Foundation

struct WorkspaceSnapshot: Codable, Equatable, Sendable {
    var projectName: String
    var rootPath: String
    var workingDirectory: String
    var branch: String
    var remote: String
    var statusSummary: String
    var changedFiles: Int
    var canRunLocalCommands: Bool
    var hermesPath: String
    var hermesVersion: String
    var deviceName: String
    var hostName: String
    var tailscaleIP: String
    var refreshedAt: Date
    var errorMessage: String?

    var isGitRepository: Bool {
        !rootPath.isEmpty
    }

    var branchLabel: String {
        branch.isEmpty ? "No branch" : branch
    }

    var remoteLabel: String {
        remote.isEmpty ? "No remote" : remote
    }

    var cleanlinessLabel: String {
        changedFiles == 0 ? "Clean" : "\(changedFiles) changed files"
    }

    var canRunHermes: Bool {
        !hermesPath.isEmpty
    }

    var hermesLabel: String {
        canRunHermes ? hermesVersion : "Not installed"
    }

    var macHostEndpoint: String {
        let host = tailscaleIP.isEmpty ? hostName : tailscaleIP
        return "http://\(host):7878"
    }

    static func empty(workingDirectory: String) -> WorkspaceSnapshot {
        let expanded = NSString(string: workingDirectory).expandingTildeInPath
        let name = URL(fileURLWithPath: expanded).lastPathComponent
        return WorkspaceSnapshot(
            projectName: name.isEmpty ? "Workspace" : name,
            rootPath: "",
            workingDirectory: expanded,
            branch: "",
            remote: "",
            statusSummary: "Refreshing",
            changedFiles: 0,
            canRunLocalCommands: false,
            hermesPath: "",
            hermesVersion: "Checking",
            deviceName: ProcessInfo.processInfo.hostName,
            hostName: ProcessInfo.processInfo.hostName,
            tailscaleIP: "",
            refreshedAt: Date(),
            errorMessage: nil
        )
    }

    static func unavailable(workingDirectory: String, message: String) -> WorkspaceSnapshot {
        var snapshot = empty(workingDirectory: workingDirectory)
        snapshot.statusSummary = "Unavailable"
        snapshot.errorMessage = message
        return snapshot
    }
}
