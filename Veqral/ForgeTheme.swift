import SwiftUI

enum ForgeTheme {
    static let accent = Color.indigo
    static let approval = Color.orange
    static let success = Color.green
    static let failure = Color.red
    static let running = Color.blue
    static let queued = Color.secondary
    static let card = Color.primary.opacity(0.055)
}

extension ForgeTaskState {
    var forgeTitle: String {
        switch self {
        case .queued: "待機"
        case .running: "実行中"
        case .needsAttention: "要対応"
        case .succeeded: "完了"
        case .failed: "失敗"
        case .cancelled: "中止"
        }
    }

    var forgeSymbol: String {
        switch self {
        case .queued: "clock"
        case .running: "bolt.fill"
        case .needsAttention: "exclamationmark.circle.fill"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .cancelled: "stop.circle.fill"
        }
    }

    var forgeTint: Color {
        switch self {
        case .queued: ForgeTheme.queued
        case .running: ForgeTheme.running
        case .needsAttention: ForgeTheme.approval
        case .succeeded: ForgeTheme.success
        case .failed, .cancelled: ForgeTheme.failure
        }
    }
}

extension ForgeAttentionSeverity {
    var forgeTitle: String {
        switch self {
        case .low: "低"
        case .high: "高"
        }
    }

    var forgeTint: Color {
        switch self {
        case .low: .secondary
        case .high: ForgeTheme.failure
        }
    }
}

extension ForgeAttentionKind {
    var forgeTitle: String {
        switch self {
        case .approval: "承認"
        case .input: "入力"
        case .review: "レビュー"
        case .blocker: "Blocker"
        case .unsupported: "要確認"
        }
    }

    var forgeSymbol: String {
        switch self {
        case .approval: "hand.raised.fill"
        case .input: "questionmark.bubble.fill"
        case .review: "doc.text.magnifyingglass"
        case .blocker: "exclamationmark.triangle.fill"
        case .unsupported: "questionmark.diamond.fill"
        }
    }

    var forgeTint: Color {
        switch self {
        case .approval, .input, .review: ForgeTheme.approval
        case .blocker, .unsupported: ForgeTheme.failure
        }
    }
}

extension Date {
    var forgeRelativeLabel: String {
        RelativeDateTimeFormatter().localizedString(for: self, relativeTo: Date())
    }
}
