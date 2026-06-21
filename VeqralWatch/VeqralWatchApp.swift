import CryptoKit
import Foundation
import Security
import SwiftUI

@main
struct VeqralWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchCommandView()
        }
    }
}

struct WatchRun: Codable, Identifiable, Equatable {
    var id: String
    var prompt: String
    var workingDirectory: String
    var status: String
    var approvalReason: String?
    var engine: String?
    var approvalSeverity: String?
}

struct WatchRunListResponse: Codable {
    var runs: [WatchRun]
}

struct WatchCreateRunResponse: Codable {
    var runID: String
    var status: String
    var approvalRequired: Bool
    var approvalReason: String?
    var approvalSeverity: String?
}

struct WatchHermesPreset: Codable, Identifiable, Equatable {
    var id: String
    var label: String
    var model: String
    var policy: String?
    var resolvedModel: String?
    var provider: String?
    var baseURL: String?
    var contextLength: String?
    var reasoning: String
    var isPlaceholder: Bool
}

struct WatchHermesStatus: Codable {
    var configured: Bool
    var model: String?
    var baseURL: String?
    var contextLength: String?
    var reasoning: String?
    var presets: [WatchHermesPreset]
    var pendingApprovalCount: Int
}

struct WatchHermesApproval: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var summary: String
    var createdAt: Date?
}

struct WatchHermesApprovalList: Codable {
    var approvals: [WatchHermesApproval]
}

@MainActor
final class WatchCommandStore: ObservableObject {
    @Published var endpoint: String {
        didSet { UserDefaults.standard.set(endpoint, forKey: "watch.endpoint") }
    }
    @Published var deviceID: String {
        didSet { UserDefaults.standard.set(deviceID, forKey: "watch.deviceID") }
    }
    @Published var token: String {
        didSet { try? WatchKeychainStore.set(token, account: "host-token") }
    }
    @Published var runs: [WatchRun] = []
    @Published var commandDraft = ""
    @Published var message = "Host 未接続"
    @Published var isLoading = false
    @Published var hermesPresets: [WatchHermesPreset] = []
    @Published var hermesApprovals: [WatchHermesApproval] = []
    @Published var hermesModel: String?
    @Published var hermesReasoning: String?

    init() {
        endpoint = UserDefaults.standard.string(forKey: "watch.endpoint") ?? ""
        deviceID = UserDefaults.standard.string(forKey: "watch.deviceID") ?? ""
        token = WatchKeychainStore.get(account: "host-token") ?? ""
    }

    var pendingApprovals: [WatchRun] {
        runs.filter { $0.status == "waitingApproval" }
    }

    var activeRuns: [WatchRun] {
        runs.filter { ["queued", "running", "waitingApproval"].contains($0.status) }
    }

    func refresh() {
        guard let client = makeClient() else {
            message = "endpoint / device / token を設定してください。"
            return
        }
        isLoading = true
        Task { @MainActor in
            do {
                runs = try await client.runs().runs
                if let status = try? await client.hermesStatus() {
                    hermesPresets = status.presets
                    hermesModel = status.model
                    hermesReasoning = status.reasoning
                }
                hermesApprovals = (try? await client.hermesApprovals().approvals) ?? hermesApprovals
                let pendingTotal = pendingApprovals.count + hermesApprovals.count
                message = pendingTotal == 0 ? "承認待ちはありません。" : "\(pendingTotal) 件の承認待ち"
            } catch {
                message = "更新失敗: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func approve(_ run: WatchRun) {
        guard !run.requiresPhoneReview else {
            message = "危険操作は iPhone で確認してください。"
            return
        }
        runAction(run, action: "approve")
    }

    func reject(_ run: WatchRun) {
        runAction(run, action: "reject")
    }

    func sendCommand() {
        let command = commandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        guard let client = makeClient() else {
            message = "endpoint / device / token を設定してください。"
            return
        }
        isLoading = true
        Task { @MainActor in
            do {
                let response = try await client.createRun(prompt: command)
                commandDraft = ""
                message = response.approvalRequired ? "承認待ちに入りました。" : "Run を送信しました。"
                refresh()
            } catch {
                message = "送信失敗: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func runAction(_ run: WatchRun, action: String) {
        guard let client = makeClient() else {
            message = "endpoint / device / token を設定してください。"
            return
        }
        isLoading = true
        Task { @MainActor in
            do {
                try await client.runAction(runID: run.id, action: action)
                message = action == "approve" ? "承認しました。" : "拒否しました。"
                refresh()
            } catch {
                message = "操作失敗: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func applyHermesPreset(_ preset: WatchHermesPreset) {
        guard let client = makeClient() else {
            message = "endpoint / device / token を設定してください。"
            return
        }
        isLoading = true
        Task { @MainActor in
            do {
                try await client.applyHermesPreset(presetID: preset.id)
                hermesModel = preset.resolvedModel ?? preset.model
                hermesReasoning = preset.reasoning
                message = "プリセット「\(preset.label)」を適用しました。新セッションから有効。"
            } catch {
                message = "適用失敗: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func decideHermes(_ approval: WatchHermesApproval, decision: String) {
        guard let client = makeClient() else {
            message = "endpoint / device / token を設定してください。"
            return
        }
        isLoading = true
        Task { @MainActor in
            do {
                try await client.decideHermesApproval(id: approval.id, decision: decision)
                hermesApprovals.removeAll { $0.id == approval.id }
                message = decision == "approve" ? "承認しました。" : "却下しました。"
            } catch {
                message = "操作失敗: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    private func makeClient() -> WatchHostClient? {
        guard !endpoint.isEmpty, !deviceID.isEmpty, !token.isEmpty else { return nil }
        return WatchHostClient(endpoint: endpoint, deviceID: deviceID, token: token)
    }
}

struct WatchCommandView: View {
    @StateObject private var store = WatchCommandStore()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ExecutionStatusComplicationView(activeCount: store.activeRuns.count, approvalCount: store.pendingApprovals.count + store.hermesApprovals.count)
                    Text(store.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        store.refresh()
                    } label: {
                        Label(store.isLoading ? "更新中" : "更新", systemImage: "arrow.clockwise")
                    }
                }

                Section("承認") {
                    if store.pendingApprovals.isEmpty {
                        Text("承認待ちはありません。")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.pendingApprovals) { run in
                        WatchApprovalCard(run: run, approve: { store.approve(run) }, reject: { store.reject(run) })
                    }
                }

                Section("Hermes") {
                    if let model = store.hermesModel {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model)
                                .font(.caption2)
                                .lineLimit(1)
                            Text("思考: \(store.hermesReasoning ?? "medium")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    ForEach(store.hermesPresets.prefix(3)) { preset in
                        Button {
                            store.applyHermesPreset(preset)
                        } label: {
                            HStack {
                                Text(preset.label)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(preset.policy ?? preset.model)
                                    Text(preset.reasoning)
                                }
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(preset.isPlaceholder || store.isLoading)
                    }
                    if store.hermesPresets.isEmpty {
                        Text("プリセット未定義（vault の presets.md）")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.hermesApprovals) { approval in
                        WatchHermesApprovalCard(
                            approval: approval,
                            approve: { store.decideHermes(approval, decision: "approve") },
                            reject: { store.decideHermes(approval, decision: "reject") }
                        )
                    }
                }

                Section("一言コマンド") {
                    TextField("指示を話す/入力", text: $store.commandDraft)
                    Button {
                        store.sendCommand()
                    } label: {
                        Label("送信", systemImage: "paperplane")
                    }
                    .disabled(store.commandDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Host") {
                    TextField("endpoint", text: $store.endpoint)
                        .textInputAutocapitalization(.never)
                    TextField("device id", text: $store.deviceID)
                        .textInputAutocapitalization(.never)
                    SecureField("token", text: $store.token)
                }
            }
            .navigationTitle("Veqral")
        }
        .onAppear(perform: store.refresh)
    }
}

struct WatchApprovalCard: View {
    let run: WatchRun
    let approve: () -> Void
    let reject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(run.engine ?? "Run")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(run.approvalSeverity == "high" ? "高" : "通常")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(run.approvalSeverity == "high" ? .red : .secondary)
            }
            Text(run.prompt)
                .font(.footnote)
                .lineLimit(4)
            if let reason = run.approvalReason {
                Text(reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if run.requiresPhoneReview {
                Text("削除・本番・秘密情報・画面操作は iPhone で確認")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            HStack {
                Button("拒否", role: .destructive, action: reject)
                Button("承認", action: approve)
                    .disabled(run.requiresPhoneReview)
            }
        }
    }
}

struct WatchHermesApprovalCard: View {
    let approval: WatchHermesApproval
    let approve: () -> Void
    let reject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Hermes")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(approval.requiresPhoneReview ? "高" : "通常")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(approval.requiresPhoneReview ? .red : .secondary)
            }
            Text(approval.title)
                .font(.footnote)
                .lineLimit(3)
            if !approval.summary.isEmpty {
                Text(approval.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if approval.requiresPhoneReview {
                Text("削除・本番・秘密情報は iPhone で確認")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            HStack {
                Button("拒否", role: .destructive, action: reject)
                Button("承認", action: approve)
                    .disabled(approval.requiresPhoneReview)
            }
        }
    }
}

extension WatchHermesApproval {
    var requiresPhoneReview: Bool {
        let text = "\(title)\n\(summary)".lowercased()
        return ["delete", "削除", "force push", "main merge", "deploy", "本番", "token", ".env", "secret", "computer use", "画面操作", "billing", "課金"].contains { text.contains($0) }
    }
}

struct ExecutionStatusComplicationView: View {
    var activeCount: Int
    var approvalCount: Int

    var body: some View {
        HStack {
            Label("\(activeCount)", systemImage: "play.circle")
            Spacer()
            Label("\(approvalCount)", systemImage: approvalCount == 0 ? "checkmark.circle" : "hand.raised")
                .foregroundStyle(approvalCount == 0 ? .green : .orange)
        }
        .font(.caption.weight(.semibold))
    }
}

extension WatchRun {
    var requiresPhoneReview: Bool {
        let text = "\(prompt)\n\(approvalReason ?? "")".lowercased()
        return ["delete", "削除", "force push", "main merge", "deploy", "本番", "token", ".env", "secret", "computer use", "画面操作", "billing", "課金"].contains { text.contains($0) }
    }
}

struct WatchHostClient {
    var endpoint: String
    var deviceID: String
    var token: String

    func runs() async throws -> WatchRunListResponse {
        let data = try await request(path: "/v1/runs", method: "GET", body: Data())
        return try decoder.decode(WatchRunListResponse.self, from: data)
    }

    func runAction(runID: String, action: String) async throws {
        _ = try await request(path: "/v1/runs/\(runID)/\(action)", method: "POST", body: Data())
    }

    func createRun(prompt: String) async throws -> WatchCreateRunResponse {
        struct Body: Encodable {
            var prompt: String
            var workingDirectory: String
            var engine: String
        }
        let body = try encoder.encode(Body(prompt: prompt, workingDirectory: "", engine: "hermes"))
        let data = try await request(path: "/v1/runs", method: "POST", body: body)
        return try decoder.decode(WatchCreateRunResponse.self, from: data)
    }

    func hermesStatus() async throws -> WatchHermesStatus {
        let data = try await request(path: "/v1/hermes/control", method: "GET", body: Data())
        return try decoder.decode(WatchHermesStatus.self, from: data)
    }

    func hermesApprovals() async throws -> WatchHermesApprovalList {
        let data = try await request(path: "/v1/hermes/approvals", method: "GET", body: Data())
        return try decoder.decode(WatchHermesApprovalList.self, from: data)
    }

    func applyHermesPreset(presetID: String) async throws {
        struct Body: Encodable {
            var presetID: String
        }
        _ = try await request(path: "/v1/hermes/control", method: "POST", body: try encoder.encode(Body(presetID: presetID)))
    }

    func decideHermesApproval(id: String, decision: String) async throws {
        struct Body: Encodable {
            var id: String
            var decision: String
        }
        _ = try await request(path: "/v1/hermes/approvals/decide", method: "POST", body: try encoder.encode(Body(id: id, decision: decision)))
    }

    private func request(path: String, method: String, body: Data) async throws -> Data {
        guard let url = URL(string: path, relativeTo: URL(string: endpoint)) else {
            throw WatchHostError.invalidConfiguration
        }
        var request = URLRequest(url: url.absoluteURL)
        request.httpMethod = method
        request.httpBody = body.isEmpty ? nil : body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let timestamp = ISO8601DateFormatter().string(from: Date())
        request.setValue(deviceID, forHTTPHeaderField: "X-Veqral-Device")
        request.setValue(timestamp, forHTTPHeaderField: "X-Veqral-Timestamp")
        request.setValue(signature(method: method, path: path, timestamp: timestamp, body: body), forHTTPHeaderField: "X-Veqral-Signature")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WatchHostError.server("Invalid response") }
        guard (200..<300).contains(http.statusCode) else {
            throw WatchHostError.server("HTTP \(http.statusCode)")
        }
        return data
    }

    private func signature(method: String, path: String, timestamp: String, body: Data) -> String {
        let bodyHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
        let canonical = "\(method)\n\(path)\n\(timestamp)\n\(bodyHash)"
        let key = SymmetricKey(data: Data(token.utf8))
        let signature = HMAC<SHA256>.authenticationCode(for: Data(canonical.utf8), using: key)
        return Data(signature).base64EncodedString()
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

enum WatchHostError: LocalizedError {
    case invalidConfiguration
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "Host 設定が未入力です。"
        case .server(let message):
            message
        }
    }
}

enum WatchKeychainStore {
    private static let service = "dev.hiroyuki.veqral.watch"

    static func set(_ value: String, account: String) throws {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw WatchHostError.server("Keychain write failed: \(status)")
        }
    }

    static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
