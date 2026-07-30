import Foundation

struct RemoteHostLogEvent: Codable, Sendable {
    var runID: String
    var kind: String
    var stream: String
    var message: String
    var createdAt: Date
    var sessionID: String?
    var exitCode: Int32?
    var interaction: CommandInteractionPrompt? = nil
    var eventID: String? = nil
    var runStatus: String? = nil
}

enum RemoteRunStreamReducer {
    @discardableResult
    static func apply(_ event: RemoteHostLogEvent, to run: inout RemoteRunRecord) -> Bool {
        guard event.runID == run.id else { return false }
        let snapshotRevision = run.statusUpdatedAt ?? run.completedAt ?? run.startedAt
        guard event.createdAt > snapshotRevision else { return false }

        var changed = false
        if let status = normalized(event.runStatus), status != run.status {
            run.status = status
            changed = true
        }
        if let sessionID = normalized(event.sessionID), sessionID != run.sessionID {
            run.sessionID = sessionID
            changed = true
        }
        if let exitCode = event.exitCode, exitCode != run.exitCode {
            run.exitCode = exitCode
            changed = true
        }
        if let interaction = event.interaction, interaction != run.interaction {
            run.interaction = interaction
            changed = true
        }

        if let status = normalized(event.runStatus), ["complete", "failed", "cancelled"].contains(status) {
            if run.completedAt != event.createdAt {
                run.completedAt = event.createdAt
                changed = true
            }
            if run.interaction != nil {
                run.interaction = nil
                changed = true
            }
        }
        run.statusUpdatedAt = event.createdAt
        return changed
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct RemoteStreamReplayCursor: Sendable {
    // VeqralHost replays the complete append-only Run log after every WebSocket
    // subscription. Keep every identity for this stream's lifetime so a reconnect
    // cannot re-emit older entries. The set is released when the Task-detail stream
    // terminates.
    private var seen: Set<String> = []

    mutating func accepts(_ event: RemoteHostLogEvent) -> Bool {
        seen.insert(Self.identity(for: event)).inserted
    }

    static func identity(for event: RemoteHostLogEvent) -> String {
        if let eventID = event.eventID, !eventID.isEmpty {
            return "event-id\u{1F}\(event.runID)\u{1F}\(eventID)"
        }
        let interaction = event.interaction.map { prompt in
            let choices = prompt.choices
                .map { "\($0.value)\u{1E}\($0.label)" }
                .joined(separator: "\u{1D}")
            return "\(prompt.kind.rawValue)\u{1E}\(prompt.prompt)\u{1E}\(choices)"
        } ?? ""
        return [
            event.runID,
            event.kind,
            event.stream,
            event.message,
            String(event.createdAt.timeIntervalSinceReferenceDate.bitPattern),
            event.sessionID ?? "",
            event.exitCode.map(String.init) ?? "",
            interaction
        ].joined(separator: "\u{1F}")
    }
}
