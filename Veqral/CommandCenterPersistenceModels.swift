import Foundation

struct CommandCenterSnapshot: Codable {
    var schemaVersion: Int?
    var runs: [CommandRun]
    var approvals: [CommandApproval]
    var logs: [CommandLogEntry]
    var diffs: [CommandDiffEntry]
    var selectedRunID: UUID?
    var selectedRuntime: CommandRuntime?
    var remoteHost: RemoteHostConfiguration?
    var remoteRunIDs: [String: String]?
    var workingDirectory: String
    var agentProjects: [AgentProjectSpace]?
    var selectedAgentProjectID: String?
    var selectedAgentChatID: String?
    var selectedHermesProvider: String?
    var selectedHermesModel: String?
    var appLanguage: AppLanguage?
    var sessionTitles: [String: String]?
    var archivedRunIDs: Set<UUID>?
    var savedCommandDrafts: [SavedCommandDraft]?
}

enum SavedCommandDraftCache {
    private static let fileName = "saved-command-drafts.json"

    static func load(cacheFolder: URL) -> [SavedCommandDraft] {
        let urls = [ubiquityURL(), localURL(cacheFolder: cacheFolder)].compactMap { $0 }
        for url in urls {
            guard let data = try? Data(contentsOf: url),
                  let drafts = try? JSONDecoder.commandCenter.decode([SavedCommandDraft].self, from: data),
                  !drafts.isEmpty else {
                continue
            }
            return drafts
        }
        return []
    }

    static func save(_ drafts: [SavedCommandDraft], cacheFolder: URL) {
        guard let data = try? JSONEncoder.commandCenter.encode(drafts) else { return }
        for url in [localURL(cacheFolder: cacheFolder), ubiquityURL()].compactMap({ $0 }) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: url, options: .atomic)
        }
    }

    static func clearLocal(cacheFolder: URL) {
        try? FileManager.default.removeItem(at: localURL(cacheFolder: cacheFolder))
    }

    private static func localURL(cacheFolder: URL) -> URL {
        cacheFolder.appendingPathComponent(fileName)
    }

    private static func ubiquityURL() -> URL? {
        guard let root = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }
        return root
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Veqral", isDirectory: true)
            .appendingPathComponent(fileName)
    }
}
