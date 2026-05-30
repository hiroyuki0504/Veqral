import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct ScreenScaffold<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(VQTheme.accent)
                        .background(VQTheme.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.title2, design: .default, weight: .semibold))
                            .foregroundStyle(VQTheme.ink)
                        Text("Veqral")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(VQTheme.secondaryText)
                    }

                    Spacer()
                }
                .padding(.top, 6)

                content
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background {
            ZStack {
                VQTheme.canvas.ignoresSafeArea()
                LinearGradient(
                    colors: [Color.white.opacity(0.024), Color.clear, Color.black.opacity(0.16)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VQPanel<Content: View>: View {
    let title: String
    let systemImage: String?
    let actionImage: String?
    let content: Content

    init(_ title: String, systemImage: String? = nil, actionImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.actionImage = actionImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.accent)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                if let actionImage {
                    Button(action: {}) {
                        Image(systemName: actionImage)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(VQTheme.secondaryText)
                    .help(title)
                }
            }

            content
        }
        .padding(12)
        .panelBackground()
    }
}

struct StatusPill: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct MetricTile: View {
    let metric: CommandMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metric.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(metric.tint)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.value)
                    .font(.system(size: 34, weight: .semibold, design: .default))
                    .foregroundStyle(VQTheme.ink)
                    .minimumScaleFactor(0.75)
                Text(metric.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Text(metric.detail)
                    .font(.footnote)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .panelBackground()
    }
}

struct CommandComposer: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RuntimeSegmentedControl()

            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .foregroundStyle(VQTheme.accent)
                TextField("What should the agents do next?", text: $store.commandDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .font(.body)
                    .onSubmit {
                        store.submitDraft()
                    }
                Button(action: store.submitDraft) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(VQTheme.accent)
                .help("Send")
            }
            .padding(12)
            .background(VQTheme.control.opacity(0.74))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VQTheme.hairline, lineWidth: 1)
            }

            HStack(spacing: 8) {
                QuickCommandButton(title: "Status", symbol: "checklist", command: "git status --short")
                QuickCommandButton(title: "Diff", symbol: "plus.forwardslash.minus", command: "git diff --stat")
                QuickCommandButton(title: "Build", symbol: "hammer", command: "xcodebuild -project Veqral.xcodeproj -scheme Veqral -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO build")
                QuickCommandButton(title: "Remote", symbol: "arrow.triangle.pull", command: "git remote -v")
            }
        }
        .padding(14)
        .commandComposerBackground()
    }
}

struct RuntimeSegmentedControl: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        HStack(spacing: 6) {
            ForEach(CommandRuntime.allCases) { runtime in
                Button {
                    store.selectedRuntime = runtime
                } label: {
                    Label(runtime.shortTitle, systemImage: runtime.symbol)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(store.selectedRuntime == runtime ? VQTheme.accent : VQTheme.secondaryText)
                        .background(store.selectedRuntime == runtime ? VQTheme.control : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(VQTheme.control.opacity(0.36))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }
}

struct QuickCommandButton: View {
    @EnvironmentObject private var store: CommandCenterStore
    let title: String
    let symbol: String
    let command: String

    var body: some View {
        Button {
            store.submitCommand(command, runtime: .localShell)
        } label: {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .tint(VQTheme.steel)
    }
}

private extension View {
    func commandComposerBackground() -> some View {
        background {
            ZStack {
                VQTheme.elevated
                LinearGradient(
                    colors: [Color.white.opacity(0.060), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline.opacity(0.95), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
    }
}

struct RunRow: View {
    let run: AgentRun

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: run.phaseSymbol)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(run.status.tint)
                    .background(run.status.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(run.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(run.agent) · \(run.device) · \(run.model)")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()
                StatusPill(title: run.status.title, tint: run.status.tint)
            }

            ProgressView(value: run.progress)
                .tint(run.status.tint)
        }
        .padding(.vertical, 4)
    }
}

struct CommandRunListRow: View {
    let run: CommandRun
    var isSelected: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: run.phaseSymbol)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(run.status.tint)
                    .background(run.status.tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(run.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(run.agent) · \(run.device) · \(run.runtimeOrDefault.shortTitle)")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer()
                StatusPill(title: run.status.title, tint: run.status.tint)
            }

            HStack(spacing: 8) {
                ProgressView(value: run.progress)
                    .tint(run.status.tint)
                Text(run.elapsedLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                    .frame(width: 54, alignment: .trailing)
            }
        }
        .padding(10)
        .background(isSelected ? VQTheme.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? VQTheme.accent.opacity(0.35) : Color.clear, lineWidth: 1)
        }
    }
}

extension AgentRun {
    var phaseSymbol: String {
        switch phase {
        case .requirements: "checklist"
        case .implementation: "hammer"
        case .testing: "testtube.2"
        case .github: "point.3.connected.trianglepath.dotted"
        case .deploy: "paperplane"
        }
    }
}

extension CommandRun {
    var phaseSymbol: String {
        switch phase {
        case .requirements: "checklist"
        case .implementation: "hammer"
        case .testing: "testtube.2"
        case .github: "point.3.connected.trianglepath.dotted"
        case .deploy: "paperplane"
        }
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text("\(device.type) · \(device.hostName)")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                }
                Spacer()
                StatusPill(title: device.status.title, tint: device.status.tint)
            }

            HStack {
                Label(device.tailscaleIP, systemImage: "network")
                Spacer()
                if let battery = device.battery {
                    Label(battery, systemImage: "battery.75percent")
                }
            }
            .font(.caption)
            .foregroundStyle(VQTheme.secondaryText)

            ProgressView(value: device.workload)
                .tint(device.status.tint)

            FlowLayout(items: device.capabilities)
        }
        .padding(.vertical, 4)
    }
}

struct ContextPackageIndicator: View {
    let title: String
    let subtitle: String
    let items: [String]

    init(
        title: String = "Shared Context Package",
        subtitle: String = "Same memory, requirements, policies, repo context, and output contract are passed to every role.",
        items: [String] = MockData.contextPackage
    ) {
        self.title = title
        self.subtitle = subtitle
        self.items = items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "archivebox")
                    .frame(width: 28, height: 28)
                    .foregroundStyle(VQTheme.green)
                    .background(VQTheme.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                StatusPill(title: "Unified", tint: VQTheme.green)
            }

            FlowLayout(items: items)
        }
        .padding(12)
        .background(VQTheme.green.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.green.opacity(0.18), lineWidth: 1)
        }
    }
}

struct QRCodeView: View {
    let payload: String

    var body: some View {
        Group {
            if let image = Self.makeImage(from: payload) {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(VQTheme.ink)
            }
        }
        .padding(10)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
        .accessibilityLabel("Pairing QR code")
    }

    private static let context = CIContext()

    private static func makeImage(from payload: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct FlowLayout: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(VQTheme.steel)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(VQTheme.steel.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }
}

struct ApprovalRow: View {
    let approval: ApprovalRequest
    let compact: Bool

    init(_ approval: ApprovalRequest, compact: Bool = false) {
        self.approval = approval
        self.compact = compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: approval.riskType.symbol)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(VQTheme.amber)
                    .background(VQTheme.amber.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(approval.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text(approval.reason)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(approval.action)
                        .font(.caption.monospaced())
                        .foregroundStyle(VQTheme.steel)
                        .lineLimit(2)
                }
            }

            if !compact {
                HStack {
                    StatusPill(title: approval.riskType.title, tint: VQTheme.amber)
                    Text(approval.affectedTarget)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button("Approve", action: {})
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    Button("Reject", action: {})
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    Button(action: {}) {
                        Image(systemName: "text.bubble")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    .help("Ask follow-up")
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(.vertical, 4)
    }
}

struct KeyValueLine: View {
    let key: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
            Spacer(minLength: 16)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct EmptyDivider: View {
    var body: some View {
        Rectangle()
            .fill(VQTheme.hairline)
            .frame(height: 1)
    }
}
