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
        version.split(whereSeparator: \.isNewline).first.map(String.init) ?? version
    }
}

struct RemoteAuthOnboardingStatus: Codable, Equatable, Sendable {
    var checkedAt: Date
    var providers: [RemoteAuthProviderStatus]
    var readyCount: Int
    var allRequiredReady: Bool
    var message: String
}

struct RemoteAuthProviderStatus: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var cliCommand: String
    var loginCommand: String
    var alternateLoginCommand: String?
    var isInstalled: Bool
    var isLoggedIn: Bool
    var hermesProviderReady: Bool
    var keychainMarkerPresent: Bool
    var isReady: Bool
    var summary: String
    var credentialHints: [String]
    var warnings: [String]
}
