import Foundation

enum RemotePairingLinkError: Error, LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        }
    }
}

struct RemotePairingLink: Sendable {
    static let supportedCapabilities = [
        "pairing.ordered-endpoints.v2",
        "protocol.negotiate.v1",
        "request-auth.hmac-sha256.v2",
        "request-auth.nonce-replay.v1"
    ].sorted()

    var endpoints: [String]
    var pairingCode: String
    var legacySignature: String?
    var signedEndpoint: String
    var pairingProtocolVersion: Int?
    var apiProtocolVersion: Int?
    var requestAuthVersions: [Int]?
    var capabilities: [String]?
    var pairingProof: String?

    init(url: URL) throws {
        guard url.scheme == "veqral", url.host == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw RemotePairingLinkError.invalid("Pairing URL was not recognized.")
        }
        let items = components.queryItems ?? []
        func values(_ name: String) -> [String] {
            items.filter { $0.name == name }.compactMap { $0.value?.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        func singleton(_ name: String, required: Bool = false) throws -> String? {
            let matches = values(name).filter { !$0.isEmpty }
            guard matches.count <= 1 else { throw RemotePairingLinkError.invalid("Duplicate pairing field: \(name)") }
            if required, matches.isEmpty { throw RemotePairingLinkError.invalid("Missing pairing field: \(name)") }
            return matches.first
        }

        guard let code = try singleton("code", required: true),
              let primary = try singleton("endpoint", required: true) else {
            throw RemotePairingLinkError.invalid("Pairing URL is missing endpoint or code.")
        }
        try Self.validateEndpoint(primary)
        pairingCode = code
        signedEndpoint = primary
        legacySignature = try singleton("signature") ?? singleton("sig")

        if let rawVersion = try singleton("pv") {
            guard rawVersion == "2",
                  let rawAPI = try singleton("api", required: true),
                  let api = Int(rawAPI), api == 2,
                  let proof = try singleton("proof", required: true) else {
                throw RemotePairingLinkError.invalid("Unsupported pairing protocol.")
            }
            let candidates = values("candidate").filter { !$0.isEmpty }
            guard (1...8).contains(candidates.count), candidates.first == primary,
                  Set(candidates).count == candidates.count else {
                throw RemotePairingLinkError.invalid("Invalid ordered pairing candidate set.")
            }
            try candidates.forEach(Self.validateEndpoint)
            let auth = try values("auth").map {
                guard let version = Int($0) else { throw RemotePairingLinkError.invalid("Invalid auth version.") }
                return version
            }
            let caps = values("cap")
            guard auth == [1, 2], caps == Self.supportedCapabilities else {
                throw RemotePairingLinkError.invalid("Required pairing capabilities are missing.")
            }
            endpoints = candidates
            pairingProtocolVersion = 2
            apiProtocolVersion = api
            requestAuthVersions = auth
            capabilities = caps
            pairingProof = proof
        } else {
            guard legacySignature?.isEmpty == false else {
                throw RemotePairingLinkError.invalid("Signed pairing URL is required.")
            }
            // Unsigned legacy fallback parameters are intentionally ignored.
            endpoints = [primary]
            pairingProtocolVersion = nil
            apiProtocolVersion = nil
            requestAuthVersions = nil
            capabilities = nil
            pairingProof = nil
        }
    }

    private static func validateEndpoint(_ value: String) throws {
        guard !value.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7f }),
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "http",
              components.host?.isEmpty == false,
              let port = components.port, (1...65_535).contains(port),
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            throw RemotePairingLinkError.invalid("Invalid pairing endpoint.")
        }
    }
}

struct RemoteHostConfiguration: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var endpoint: String
    var deviceID: String
    var token: String
    var name: String
    var minimumAuthVersion: Int? = nil

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
    var apiProtocolVersion: Int?
    var minimumAuthVersion: Int?
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
