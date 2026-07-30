import Foundation

public enum VeqralSecretStoreBackend: Equatable, Sendable {
    case systemKeychain
    case isolatedFile(URL)
    case invalid(String)
}

public enum VeqralSecretStoreIsolationPolicy {
    public static let testModeKey = "VEQRAL_TEST_MODE"
    public static let hostHomeKey = "VEQRAL_HOST_HOME"
    public static let secretStorePathKey = "VEQRAL_TEST_SECRET_STORE_PATH"

    public static func resolve(
        environment: [String: String],
        temporaryRoots: [URL]
    ) -> VeqralSecretStoreBackend {
        let testMode = environment[testModeKey]?.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
        let rawStorePath = environment[secretStorePathKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let storePath = rawStorePath?.isEmpty == false ? rawStorePath : nil

        if !testMode, storePath == nil {
            return .systemKeychain
        }
        guard testMode else {
            return .invalid("\(secretStorePathKey) is test-only and requires \(testModeKey)=1")
        }
        guard let storePath else {
            return .invalid("Test mode requires \(secretStorePathKey); refusing to use the login Keychain")
        }
        guard let rawHostHome = environment[hostHomeKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawHostHome.isEmpty else {
            return .invalid("Test mode requires an isolated \(hostHomeKey)")
        }

        let hostHome = canonical(URL(fileURLWithPath: NSString(string: rawHostHome).expandingTildeInPath, isDirectory: true))
        let storeURL = canonical(URL(fileURLWithPath: NSString(string: storePath).expandingTildeInPath, isDirectory: false))
        let roots = temporaryRoots.map(canonical)

        guard roots.contains(where: { isDescendant(hostHome, of: $0) }) else {
            return .invalid("\(hostHomeKey) must be inside a temporary directory")
        }
        guard isDescendant(storeURL, of: hostHome) else {
            return .invalid("\(secretStorePathKey) must be inside \(hostHomeKey)")
        }
        guard storeURL.path != hostHome.path else {
            return .invalid("\(secretStorePathKey) must name a file, not the Host home directory")
        }
        return .isolatedFile(storeURL)
    }

    public static func systemTemporaryRoots(fileManager: FileManager = .default) -> [URL] {
        [
            fileManager.temporaryDirectory,
            URL(fileURLWithPath: "/tmp", isDirectory: true),
            URL(fileURLWithPath: "/private/tmp", isDirectory: true)
        ]
    }

    private static func canonical(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return candidate.path.hasPrefix(rootPath)
    }
}

public final class VeqralIsolatedFileSecretStore: @unchecked Sendable {
    private let url: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    public init(url: URL, fileManager: FileManager = .default) throws {
        self.url = url
        self.fileManager = fileManager
        let folder = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: folder.path)
    }

    public func set(_ value: String, account: String) throws {
        try locked {
            var entries = try load()
            entries[account] = value
            try persist(entries)
        }
    }

    public func get(account: String) throws -> String? {
        try locked {
            try load()[account]
        }
    }

    public func delete(account: String) throws {
        try locked {
            var entries = try load()
            guard entries.removeValue(forKey: account) != nil else { return }
            try persist(entries)
        }
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func load() throws -> [String: String] {
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return [:] }
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    private func persist(_ entries: [String: String]) throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
