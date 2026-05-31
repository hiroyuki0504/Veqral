import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins
@preconcurrency import AVFoundation
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
                    }

                    Spacer()
                }
                .padding(.top, 6)

                HostConnectionStrip()

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
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HostConnectionStrip: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        if !store.remoteHost.isPaired {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(tint)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(L10n.tr(title))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)
                StatusPill(title: status, tint: tint)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(VQTheme.elevated.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            }
        }
    }

    private var isOnline: Bool {
        store.remoteHost.isEnabled && store.remoteHost.isPaired && store.remoteHostHealth?.status == "ok"
    }

    private var title: String {
        if isOnline { return "Mac Host connected" }
        if store.remoteHost.isEnabled && store.remoteHost.isPaired { return "Mac Host offline" }
        return "Pair Mac Host"
    }

    private var detail: String {
        if store.remoteHost.isPaired {
            return store.remoteHost.displayEndpoint
        }
        return L10n.tr("Scan the menu bar QR from Devices.")
    }

    private var status: String {
        if isOnline { return "Connected" }
        if store.remoteHost.isEnabled && store.remoteHost.isPaired { return "Offline" }
        return "Pairing needed"
    }

    private var symbol: String {
        if isOnline { return "checkmark.circle" }
        if store.remoteHost.isEnabled && store.remoteHost.isPaired { return "wifi.exclamationmark" }
        return "qrcode.viewfinder"
    }

    private var tint: Color {
        if isOnline { return VQTheme.green }
        if store.remoteHost.isEnabled && store.remoteHost.isPaired { return VQTheme.amber }
        return VQTheme.amber
    }
}

enum VQDisplay {
    static func workspaceName(_ workspace: WorkspaceSnapshot) -> String {
        humanName(workspace.projectName, fallbackPath: workspace.workingDirectory, fallback: L10n.tr("Workspace"))
    }

    static func projectName(_ project: AgentProjectSpace) -> String {
        humanName(project.name, fallbackPath: project.workingDirectory, fallback: L10n.tr("Project"))
    }

    @MainActor
    static func hostName(_ store: CommandCenterStore) -> String {
        let candidate = store.remoteHost.name.nilIfBlank ?? store.workspace.hostName.nilIfBlank ?? store.workspace.deviceName
        return humanName(candidate, fallbackPath: store.workspace.workingDirectory, fallback: "Mac Host")
    }

    static func endpoint(_ host: RemoteHostConfiguration) -> String {
        host.endpoint.nilIfBlank ?? L10n.tr("Not Paired")
    }

    static func workspaceStatus(_ workspace: WorkspaceSnapshot) -> String {
        let raw = workspace.statusSummary.nilIfBlank ?? (workspace.errorMessage == nil ? "Ready" : "Unavailable")
        return L10n.tr(raw)
    }

    static func workspaceStatusTint(_ workspace: WorkspaceSnapshot) -> Color {
        let status = workspace.statusSummary.lowercased()
        if workspace.errorMessage != nil || status.contains("unavailable") || status.contains("not detected") {
            return VQTheme.unavailable
        }
        if status.contains("refresh") || status.contains("check") || status.contains("pending") {
            return VQTheme.amber
        }
        return workspace.changedFiles == 0 ? VQTheme.green : VQTheme.amber
    }

    static func pathTail(_ path: String, fallback: String = "Not detected") -> String {
        let clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return L10n.tr(fallback) }
        let name = URL(fileURLWithPath: clean).lastPathComponent
        return name.isEmpty ? clean : name
    }

    private static func humanName(_ name: String, fallbackPath: String, fallback: String) -> String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty, !looksOpaque(clean) {
            return clean
        }
        let pathName = pathTail(fallbackPath, fallback: fallback)
        return looksOpaque(pathName) ? fallback : pathName
    }

    private static func looksOpaque(_ value: String) -> Bool {
        UUID(uuidString: value) != nil || value.contains("/private/var/mobile/Containers/")
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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

struct ApprovalActionButtons: View {
    @EnvironmentObject private var store: CommandCenterStore
    let approval: CommandApproval
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.reject(approval)
            } label: {
                Label(L10n.tr("Reject"), systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                store.approve(approval)
            } label: {
                Label(L10n.tr("Approve"), systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .controlSize(compact ? .small : .regular)
        .font((compact ? Font.caption2 : Font.footnote).weight(.semibold))
    }
}

struct RunApprovalCallout: View {
    let approval: CommandApproval
    var compact = false

    private var tint: Color {
        approval.tintName == "amber" ? VQTheme.amber : VQTheme.red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: approval.symbolName)
                    .frame(width: compact ? 24 : 30, height: compact ? 24 : 30)
                    .foregroundStyle(tint)
                    .background(tint.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.tr("Approval required"))
                        .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text(approval.detail)
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(compact ? 2 : 3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            ApprovalActionButtons(approval: approval, compact: compact)
        }
        .padding(compact ? 9 : 11)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(tint.opacity(0.48), lineWidth: 1)
        }
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
                TextField(store.selectedRuntime.commandPlaceholder, text: $store.commandDraft, axis: .vertical)
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
                QuickCommandButton(title: L10n.tr("Remote"), symbol: "arrow.triangle.pull", command: "git remote -v")
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

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> QRCodeScannerController {
        QRCodeScannerController(onCode: onCode, onFailure: onFailure)
    }

    func updateUIViewController(_ uiViewController: QRCodeScannerController, context: Context) {}
}

final class QRCodeScannerController: UIViewController, @preconcurrency AVCaptureMetadataOutputObjectsDelegate {
    private let onCode: (String) -> Void
    private let onFailure: (String) -> Void
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didCapture = false

    init(onCode: @escaping (String) -> Void, onFailure: @escaping (String) -> Void) {
        self.onCode = onCode
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            onFailure(L10n.tr("Camera is not available on this device. Use manual pairing instead."))
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                onFailure(L10n.tr("Camera input is unavailable. Use manual pairing instead."))
                return
            }
            session.addInput(input)
        } catch {
            onFailure("\(L10n.tr("Camera could not start.")) \(error.localizedDescription)")
            return
        }

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onFailure(L10n.tr("QR scanning is unavailable. Use manual pairing instead."))
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = output.availableMetadataObjectTypes.contains(.qr) ? [.qr] : []

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didCapture,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else {
            return
        }
        didCapture = true
        session.stopRunning()
        onCode(value)
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

struct RemoteDeviceSummaryRow: View {
    let device: RemoteDeviceRecord
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: isCurrent ? "iphone.gen3" : "rectangle.connected.to.line.below")
                .frame(width: 28, height: 28)
                .foregroundStyle(device.lastSeenAt == nil ? VQTheme.unavailable : VQTheme.green)
                .background((device.lastSeenAt == nil ? VQTheme.unavailable : VQTheme.green).opacity(0.12))
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
            StatusPill(title: device.lastSeenAt == nil ? "Paired" : "Seen", tint: device.lastSeenAt == nil ? VQTheme.unavailable : VQTheme.green)
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
                    Text(L10n.tr(title))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text(L10n.tr(subtitle))
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
                Text(L10n.tr(item))
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

struct CompactKeyValueLine: View {
    let key: String
    let value: String
    var monospaced = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.tr(key))
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
            Spacer(minLength: 16)
            Text(value)
                .font(monospaced ? .caption.monospaced().weight(.semibold) : .caption.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
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

private extension CommandRuntime {
    var commandPlaceholder: String {
        switch self {
        case .hermesAgent:
            L10n.tr("Send instructions to Hermes...")
        case .codexDirect:
            L10n.tr("Send instructions to Codex...")
        case .claudeDirect:
            L10n.tr("Send instructions to Claude...")
        case .localShell:
            L10n.tr("Enter a shell command...")
        }
    }
}
