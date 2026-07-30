import SwiftUI

struct ForgeCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(ForgeTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ForgeStatusPill: View {
    let state: ForgeTaskState

    var body: some View {
        Label(state.forgeTitle, systemImage: state.forgeSymbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(state.forgeTint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(state.forgeTint.opacity(0.12), in: Capsule())
    }
}

struct ForgeMetric: View {
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ForgeEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct ForgeConnectionBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? ForgeTheme.success : Color.secondary)
                .frame(width: 8, height: 8)
            Text(isConnected ? "Mac接続中" : "未接続")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}
