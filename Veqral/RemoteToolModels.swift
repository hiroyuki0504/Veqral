import Foundation

struct RemoteCLIToolStatus: Codable, Identifiable, Equatable, Sendable {
    var engine: String
    var title: String
    var executablePath: String?
    var version: String
    var adapter: String
    var commandShape: String?
    var isInstalled: Bool
    var isKnownCompatible: Bool
    var compatibilityNote: String

    var id: String { engine }

    var versionSummary: String {
        version.nilIfBlank ?? "導入済み"
    }
}
