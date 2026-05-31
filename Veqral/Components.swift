import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
import AVFoundation
import PhotosUI
import UniformTypeIdentifiers

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
                        Text(L10n.tr(title))
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
        .navigationTitle(L10n.tr(title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SpinningCommandNodeMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = false

    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            VQTheme.elevated.opacity(0.95),
                            VQTheme.control.opacity(0.74)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: VQTheme.accent.opacity(0.18), radius: size * 0.18, x: 0, y: 0)
                .shadow(color: .black.opacity(0.28), radius: size * 0.16, x: 0, y: size * 0.08)

            RotatingNodeConstellation(size: size)
                .rotationEffect(.degrees(reduceMotion ? 24 : (spin ? 360 : 0)))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.96),
                            VQTheme.amber,
                            VQTheme.amber.opacity(0.30)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size * 0.18
                    )
                )
                .frame(width: size * 0.26, height: size * 0.26)
                .overlay {
                    Circle()
                        .stroke(VQTheme.amber.opacity(0.86), lineWidth: max(1, size * 0.035))
                }
                .shadow(color: VQTheme.amber.opacity(0.46), radius: size * 0.16, x: 0, y: 0)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            startSpinning()
        }
        .onChange(of: reduceMotion) { _, isReduced in
            if isReduced {
                spin = false
            } else {
                startSpinning()
            }
        }
        .accessibilityLabel("Command node mark")
    }

    private func startSpinning() {
        spin = false
        withAnimation(.linear(duration: 5.8).repeatForever(autoreverses: false)) {
            spin = true
        }
    }
}

private struct RotatingNodeConstellation: View {
    let size: CGFloat

    private let nodeColors: [Color] = [
        VQTheme.accent,
        VQTheme.green,
        VQTheme.amber,
        VQTheme.violet,
        VQTheme.steel
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = side * 0.34
            let nodeSize = side * 0.118
            let lineWidth = max(1, side * 0.045)

            ZStack {
                Circle()
                    .trim(from: 0.06, to: 0.31)
                    .stroke(VQTheme.steel.opacity(0.82), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .rotationEffect(.degrees(16))

                Circle()
                    .trim(from: 0.42, to: 0.66)
                    .stroke(VQTheme.steel.opacity(0.66), style: StrokeStyle(lineWidth: lineWidth * 0.78, lineCap: .round))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .rotationEffect(.degrees(16))

                ForEach(0..<5, id: \.self) { index in
                    let nodePoint = point(index: index, radius: radius, center: center)

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: nodePoint)
                    }
                    .stroke(VQTheme.steel.opacity(0.78), style: StrokeStyle(lineWidth: max(1, side * 0.033), lineCap: .round))

                    Circle()
                        .fill(nodeColors[index])
                        .frame(width: nodeSize, height: nodeSize)
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.72), lineWidth: max(1, side * 0.022))
                        }
                        .shadow(color: nodeColors[index].opacity(0.44), radius: side * 0.070, x: 0, y: 0)
                        .position(nodePoint)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func point(index: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = (-CGFloat.pi / 2) + (CGFloat(index) * 2 * .pi / 5)
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

struct VQPanel<Content: View>: View {
    let title: String
    let systemImage: String?
    let actionImage: String?
    let action: (() -> Void)?
    let content: Content

    init(_ title: String, systemImage: String? = nil, actionImage: String? = nil, action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.actionImage = actionImage
        self.action = action
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
                Text(L10n.tr(title))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                if let actionImage {
                    if let action {
                        Button(action: action) {
                            Image(systemName: actionImage)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(VQTheme.secondaryText)
                        .help(title)
                    } else {
                        Image(systemName: actionImage)
                            .foregroundStyle(VQTheme.secondaryText)
                            .accessibilityHidden(true)
                    }
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
        Text(L10n.tr(title))
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
                Text(L10n.tr(metric.title))
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
                TextField(L10n.tr("What should the agents do next?"), text: $store.commandDraft, axis: .vertical)
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
                .help(L10n.tr("Send"))
            }
            .padding(12)
            .background(VQTheme.control.opacity(0.74))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VQTheme.hairline, lineWidth: 1)
            }

            HStack(spacing: 8) {
                QuickCommandButton(title: L10n.tr("Status"), symbol: "checklist", command: "git status --short")
                QuickCommandButton(title: L10n.tr("Diff"), symbol: "plus.forwardslash.minus", command: "git diff --stat")
                QuickCommandButton(title: L10n.tr("Build"), symbol: "hammer", command: "xcodebuild -project Veqral.xcodeproj -scheme Veqral -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' CODE_SIGNING_ALLOWED=NO build")
                QuickCommandButton(title: "Remote", symbol: "arrow.triangle.pull", command: "git remote -v")
            }

            CommandAttachmentControls()
        }
        .padding(14)
        .commandComposerBackground()
    }
}

struct CommandAttachmentControls: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var showCamera = false
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    requestCamera()
                } label: {
                    Label(L10n.tr("Camera"), systemImage: "camera")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))

                PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                    Label(L10n.tr("Photos"), systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))

                if !store.pendingAttachments.isEmpty {
                    Button(role: .destructive) {
                        store.clearAttachments()
                    } label: {
                        Label(L10n.tr("Clear"), systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                }

                Spacer()
            }
            .font(.footnote.weight(.semibold))

            if !store.pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.pendingAttachments) { attachment in
                            AttachmentChip(attachment: attachment) {
                                store.removeAttachment(attachment)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if !store.attachmentMessage.isEmpty {
                Text(store.attachmentMessage)
                    .font(.caption)
                    .foregroundStyle(store.attachmentMessage.localizedCaseInsensitiveContains("denied") || store.attachmentMessage.localizedCaseInsensitiveContains("restricted") ? VQTheme.amber : VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                if let data = image.jpegData(compressionQuality: 0.82) {
                    store.addImageAttachment(data: data, fileExtension: "jpg", mimeType: "image/jpeg")
                } else {
                    store.attachmentMessage = "Camera capture failed: image data could not be encoded."
                }
                showCamera = false
            } onCancel: {
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        await MainActor.run {
                            store.attachmentMessage = "Photo could not be loaded."
                        }
                        return
                    }
                    let type = item.supportedContentTypes.first
                    await MainActor.run {
                        store.addImageAttachment(
                            data: data,
                            fileExtension: type?.preferredFilenameExtension ?? "jpg",
                            mimeType: type?.preferredMIMEType ?? "image/jpeg"
                        )
                        selectedPhoto = nil
                    }
                } catch {
                    await MainActor.run {
                        store.attachmentMessage = "Photo load failed: \(error.localizedDescription)"
                        selectedPhoto = nil
                    }
                }
            }
        }
    }

    private func requestCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    store.attachmentMessage = L10n.tr("Camera is not available on this device. Use Photos instead.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        showCamera = true
                    } else {
                        store.attachmentMessage = L10n.tr("Camera permission denied. Enable it in Settings to attach captures.")
                    }
                }
            }
        case .denied:
            store.attachmentMessage = L10n.tr("Camera permission denied. Enable it in Settings to attach captures.")
        case .restricted:
            store.attachmentMessage = L10n.tr("Camera access is restricted on this device.")
        @unknown default:
            store.attachmentMessage = L10n.tr("Camera authorization state is unavailable.")
        }
    }
}

private struct AttachmentChip: View {
    let attachment: CommandAttachment
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let image = UIImage(data: attachment.data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .frame(width: 34, height: 34)
                    .foregroundStyle(VQTheme.accent)
                    .background(VQTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Text(byteLabel(attachment.byteCount))
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
            }

            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(VQTheme.secondaryText)
        }
        .padding(6)
        .background(VQTheme.control.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }

    private func byteLabel(_ bytes: Int) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        }
        if bytes >= 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        }
        return "\(bytes) B"
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
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

struct RemoteDeviceSummaryRow: View {
    let device: RemoteDeviceRecord
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: isCurrent ? "iphone.gen3" : "rectangle.connected.to.line.below")
                .frame(width: 28, height: 28)
                .foregroundStyle(device.lastSeenAt == nil ? VQTheme.amber : VQTheme.green)
                .background((device.lastSeenAt == nil ? VQTheme.amber : VQTheme.green).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                Text(device.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            StatusPill(title: device.lastSeenAt == nil ? "Paired" : "Seen", tint: device.lastSeenAt == nil ? VQTheme.amber : VQTheme.green)
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
        items: [String] = ContextPackage.items
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
                    StatusPill(title: "Review in Approvals", tint: VQTheme.accent)
                    Text("Approve, reject, or follow up from the live approval queue.")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
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
            Text(L10n.tr(key))
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
