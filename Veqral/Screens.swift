import SwiftUI
import UIKit
import AVFoundation

struct SalesLabView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var statusFilter: SalesLeadStatus?
    @State private var isShowingLeadEditor = false
    @State private var isShowingCSVImport = false
    @State private var draftLead = SalesLead.empty()
    @State private var csvText = ""

    private var filteredLeads: [SalesLead] {
        store.salesLeads.filter { lead in
            statusFilter == nil || lead.status == statusFilter
        }
    }

    var body: some View {
        ScreenScaffold(title: "営業ラボ", systemImage: "chart.line.uptrend.xyaxis") {
            header
            filters
            leadGrid
            detail
        }
        .onAppear {
            if store.salesLeads.isEmpty {
                store.refreshSalesLeads()
            }
        }
        .sheet(isPresented: $isShowingLeadEditor) {
            SalesLeadEditor(lead: $draftLead) {
                store.saveSalesLead(draftLead)
                isShowingLeadEditor = false
                draftLead = SalesLead.empty()
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingCSVImport) {
            SalesCSVImportSheet(csvText: $csvText) {
                store.importSalesCSV(csvText)
                isShowingCSVImport = false
                csvText = ""
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        VQPanel("案件生成ツール", systemImage: "building.2", actionImage: "arrow.clockwise") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    StatusPill(title: "\(store.salesLeads.count)件", tint: VQTheme.accent)
                    StatusPill(title: "\(store.salesLeads.filter { $0.status == .proposalReady }.count)提案", tint: VQTheme.amber)
                    StatusPill(title: "\(store.salesLeads.filter { $0.status == .won }.count)受注", tint: VQTheme.green)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Button(action: store.refreshSalesLeads) {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))

                    Button {
                        draftLead = SalesLead.empty()
                        isShowingLeadEditor = true
                    } label: {
                        Label("手動登録", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 8))

                    Button {
                        csvText = ""
                        isShowingCSVImport = true
                    } label: {
                        Label("CSV", systemImage: "tablecells")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    Spacer()
                }

                Text("公式URLを人が登録した案件だけを扱います。連絡文は生成とコピーまでで、自動送信はしません。")
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if !store.salesLabMessage.isEmpty {
                    Text(store.salesLabMessage)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var filters: some View {
        VQPanel("絞り込み", systemImage: "line.3.horizontal.decrease.circle") {
            Picker("状態", selection: $statusFilter) {
                Text("すべて").tag(nil as SalesLeadStatus?)
                ForEach(SalesLeadStatus.allCases) { status in
                    Text(status.title).tag(status as SalesLeadStatus?)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var leadGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], alignment: .leading, spacing: 12) {
            if filteredLeads.isEmpty {
                VQPanel("案件", systemImage: "tray") {
                    Text(store.remoteHost.isPaired ? "条件に合う案件はありません。" : "Mac Host とペアリングしてください。")
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
            ForEach(filteredLeads) { lead in
                Button {
                    store.selectSalesLead(lead)
                } label: {
                    SalesLeadCard(lead: lead, isSelected: store.selectedSalesLead?.id == lead.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let lead = store.selectedSalesLead {
            VQPanel(lead.businessName.isEmpty ? "案件詳細" : lead.businessName, systemImage: "doc.text.magnifyingglass") {
                VStack(alignment: .leading, spacing: 14) {
                    SalesLeadSummaryPanel(lead: lead) {
                        draftLead = lead
                        isShowingLeadEditor = true
                    }

                    Picker("状態", selection: Binding(
                        get: { lead.status },
                        set: { store.updateSelectedSalesLeadStatus($0) }
                    )) {
                        ForEach(SalesLeadStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)

                    SalesAuditPanel(lead: lead)
                    SalesRedesignPanel(lead: lead)
                    SalesProposalPanel(lead: lead)
                    SalesAssetsPanel(assets: store.salesLeadAssets)
                    SalesHandoffPanel(note: store.salesHermesHandoffNote, lead: lead)
                }
            }
        }
    }
}

private struct SalesLeadCard: View {
    let lead: SalesLead
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "building.2")
                    .frame(width: 30, height: 30)
                    .foregroundStyle(isSelected ? VQTheme.accent : VQTheme.secondaryText)
                    .background(VQTheme.control.opacity(0.48))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer()
                StatusPill(title: lead.status.title, tint: lead.status.tint)
            }
            Text(lead.businessName.isEmpty ? "名称未設定" : lead.businessName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .lineLimit(2)
            Text([lead.area, lead.category].compactMap { $0.vqNilIfBlank }.joined(separator: " / ").vqNilIfBlank ?? "地域・業種未設定")
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .lineLimit(2)
            FlowLayout(items: badges)
        }
        .padding(12)
        .background(isSelected ? VQTheme.accent.opacity(0.09) : VQTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? VQTheme.accent.opacity(0.45) : VQTheme.hairline, lineWidth: 1)
        }
    }

    private var badges: [String] {
        [
            lead.latestAudit.map { "監査 \($0.score)" },
            lead.latestRedesignMock == nil ? nil : "改善案",
            lead.latestProposal == nil ? nil : "提案書"
        ].compactMap { $0 }
    }
}

private struct SalesLeadSummaryPanel: View {
    @Environment(\.openURL) private var openURL
    let lead: SalesLead
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusPill(title: lead.status.title, tint: lead.status.tint)
                if let place = lead.googlePlaceID?.vqNilIfBlank {
                    StatusPill(title: "Place ID保持", tint: VQTheme.steel)
                        .accessibilityLabel(place)
                }
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
            }

            VStack(spacing: 7) {
                KeyValueLine(key: "地域", value: lead.area.vqNilIfBlank ?? "未設定")
                KeyValueLine(key: "業種", value: lead.category.vqNilIfBlank ?? "未設定")
                KeyValueLine(key: "電話", value: lead.phone?.vqNilIfBlank ?? "未設定")
                KeyValueLine(key: "メール", value: lead.email?.vqNilIfBlank ?? "未設定")
            }

            HStack(spacing: 8) {
                linkButton("公式サイト", systemImage: "safari", urlText: lead.officialWebsiteURL)
                linkButton("地図", systemImage: "map", urlText: lead.googleMapsURL)
                Spacer()
            }

            if let notes = lead.notes.vqNilIfBlank {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func linkButton(_ title: String, systemImage: String, urlText: String?) -> some View {
        if let urlText = urlText?.vqNilIfBlank, let url = URL(string: urlText) {
            Button {
                openURL(url)
            } label: {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
        }
    }
}

private struct SalesAuditPanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    let lead: SalesLead

    var body: some View {
        VQPanel("Web監査", systemImage: "iphone.gen3.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let audit = lead.latestAudit {
                        StatusPill(title: "スコア \(audit.score)", tint: scoreTint(audit.score))
                        StatusPill(title: audit.mobileViewport, tint: VQTheme.steel)
                    } else {
                        StatusPill(title: "未実行", tint: VQTheme.unavailable)
                    }
                    Spacer()
                    Button(action: store.auditSelectedSalesLead) {
                        Label(lead.latestAudit == nil ? "監査" : "再監査", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    .disabled(lead.officialWebsiteURL?.vqNilIfBlank == nil || store.isLoadingSalesLab)
                }

                if let audit = lead.latestAudit {
                    Text(audit.summary)
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(audit.findings.prefix(4)) { finding in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(finding.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VQTheme.ink)
                            Text(finding.recommendation)
                                .font(.caption)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if !audit.businessImpacts.isEmpty {
                        FlowLayout(items: audit.businessImpacts.prefix(3).map { $0 })
                    }
                    CompactKeyValueLine(key: "保存先", value: audit.screenshotPath, monospaced: true)
                } else {
                    Text("公式URLを登録すると、スマホ幅の監査と改善観点を作成します。")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
        }
    }

    private func scoreTint(_ score: Int) -> Color {
        if score >= 80 { return VQTheme.green }
        if score >= 60 { return VQTheme.amber }
        return VQTheme.red
    }
}

private struct SalesRedesignPanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    let lead: SalesLead

    var body: some View {
        VQPanel("スマホ改善案", systemImage: "paintbrush.pointed") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(title: lead.latestRedesignMock == nil ? "未生成" : "生成済み", tint: lead.latestRedesignMock == nil ? VQTheme.unavailable : VQTheme.accent)
                    if lead.latestRedesignMock?.approvedAt != nil {
                        StatusPill(title: "採用", tint: VQTheme.green)
                    }
                    Spacer()
                    Button(action: store.generateSelectedSalesRedesign) {
                        Label(lead.latestRedesignMock == nil ? "生成" : "再生成", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    .disabled(store.isLoadingSalesLab)
                }

                if let mock = lead.latestRedesignMock {
                    Text(mock.headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text(mock.subheadline)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    KeyValueLine(key: "CTA", value: mock.cta)
                    CompactKeyValueLine(key: "HTML", value: mock.htmlPath, monospaced: true)
                    CompactKeyValueLine(key: "画像", value: mock.screenshotPath, monospaced: true)
                    HStack {
                        Button {
                            var updated = lead
                            updated.latestRedesignMock?.approvedAt = Date()
                            store.saveSalesLead(updated)
                        } label: {
                            Label("採用", systemImage: "checkmark")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        Spacer()
                    }
                } else {
                    Text("既存サイトのコピーではなく、地域・業種・問い合わせ導線からオリジナルのスマホLP案を作ります。")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
        }
    }
}

private struct SalesProposalPanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    let lead: SalesLead

    var body: some View {
        VQPanel("提案と連絡文", systemImage: "doc.richtext") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(title: lead.latestProposal == nil ? "未生成" : "下書きあり", tint: lead.latestProposal == nil ? VQTheme.unavailable : VQTheme.amber)
                    if lead.latestProposal?.approvedAt != nil {
                        StatusPill(title: "承認済み", tint: VQTheme.green)
                    }
                    Spacer()
                    Button(action: store.generateSelectedSalesProposal) {
                        Label(lead.latestProposal == nil ? "生成" : "再生成", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    .disabled(store.isLoadingSalesLab)
                }

                if let proposal = lead.latestProposal {
                    Text(proposal.summary)
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    FlowLayout(items: proposal.pricing)
                    VStack(alignment: .leading, spacing: 8) {
                        copyRow("メール文案", text: proposal.emailDraft)
                        copyRow("DM文案", text: proposal.dmDraft)
                        copyRow("電話スクリプト", text: proposal.phoneScript)
                    }
                    HStack(spacing: 8) {
                        Button(action: store.approveSelectedSalesProposal) {
                            Label("承認", systemImage: "checkmark.seal")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))

                        Button {
                            store.markSelectedSalesLeadContacted(channel: "manual", note: "提案文をコピーして人が連絡")
                        } label: {
                            Label("連絡済み", systemImage: "paperplane")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        Spacer()
                    }
                    CompactKeyValueLine(key: "提案書", value: proposal.htmlPath, monospaced: true)
                    if let pdfPath = proposal.pdfPath {
                        CompactKeyValueLine(key: "PDF", value: pdfPath, monospaced: true)
                    }
                } else {
                    Text("3万円の改善案、15〜30万円のLP改善、5〜15万円の月次改善を軸に、人が確認して使う文案を作ります。")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
        }
    }

    private func copyRow(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
                Spacer()
                Button {
                    UIPasteboard.general.string = text
                    store.salesLabMessage = "\(title)をコピーしました。"
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(VQTheme.ink)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(VQTheme.control.opacity(0.44))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SalesAssetsPanel: View {
    let assets: [RemoteSalesLeadAsset]

    var body: some View {
        VQPanel("生成物", systemImage: "shippingbox") {
            VStack(alignment: .leading, spacing: 8) {
                if assets.isEmpty {
                    Text("監査・改善案・提案書を作ると保存先が表示されます。")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                } else {
                    ForEach(assets) { asset in
                        CompactKeyValueLine(key: asset.kind, value: asset.path, monospaced: true)
                    }
                }
            }
        }
    }
}

private struct SalesHandoffPanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    let note: String
    let lead: SalesLead

    var body: some View {
        VQPanel("次の委譲", systemImage: "arrow.triangle.branch") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Button(action: store.createSelectedSalesHermesHandoff) {
                        Label("Hermes Desktopメモ", systemImage: "sparkles")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))

                    Button(action: store.promoteSelectedSalesLeadToPortfolio) {
                        Label("Portfolioへ昇格", systemImage: "rectangle.3.group")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    .disabled(lead.status != .won)
                    Spacer()
                }
                if let path = lead.hermesHandoffPath?.vqNilIfBlank {
                    CompactKeyValueLine(key: "メモ", value: path, monospaced: true)
                }
                if !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(8)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct SalesLeadEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var lead: SalesLead
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("基本") {
                    TextField("店舗・会社名", text: $lead.businessName)
                    TextField("業種", text: $lead.category)
                    TextField("地域", text: $lead.area)
                    Picker("状態", selection: $lead.status) {
                        ForEach(SalesLeadStatus.allCases) { status in
                            Text(status.title).tag(status)
                        }
                    }
                }
                Section("連絡先") {
                    optionalField("公式URL", value: $lead.officialWebsiteURL)
                    optionalField("Google Maps URL", value: $lead.googleMapsURL)
                    optionalField("Place ID", value: $lead.googlePlaceID)
                    optionalField("電話", value: $lead.phone)
                    optionalField("メール", value: $lead.email)
                }
                Section("メモ") {
                    TextField("メモ", text: $lead.notes, axis: .vertical)
                        .lineLimit(4...8)
                }
            }
            .navigationTitle("案件登録")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                        dismiss()
                    }
                    .disabled(lead.businessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func optionalField(_ title: String, value: Binding<String?>) -> some View {
        TextField(title, text: Binding(
            get: { value.wrappedValue ?? "" },
            set: { value.wrappedValue = $0.vqNilIfBlank }
        ))
    }
}

private struct SalesCSVImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var csvText: String
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("businessName, category, area, officialWebsiteURL, googleMapsURL, googlePlaceID, phone, email, notes, status を読み取ります。")
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                TextEditor(text: $csvText)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(VQTheme.control.opacity(0.42))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding()
            .navigationTitle("CSV取り込み")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("取り込む") {
                        onImport()
                        dismiss()
                    }
                    .disabled(csvText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct PortfolioView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var kindFilter: PortfolioAssetKind?
    @State private var statusFilter: PortfolioAssetStatus?
    @State private var isShowingAddAsset = false
    @State private var draftAsset = PortfolioAsset.empty()
    @State private var editorTitle = "Add Asset"

    private var filteredAssets: [PortfolioAsset] {
        store.portfolioAssets.filter { asset in
            (kindFilter == nil || asset.kind == kindFilter) &&
            (statusFilter == nil || asset.status == statusFilter)
        }
    }

    var body: some View {
        ScreenScaffold(title: "Portfolio", systemImage: "rectangle.3.group") {
            portfolioHeader
            filters
            assetGrid
            selectedAssetDetail
        }
        .onAppear {
            if store.portfolioAssets.isEmpty {
                store.refreshPortfolio()
            }
            store.refreshCostGovernance()
        }
        .sheet(isPresented: $isShowingAddAsset) {
            PortfolioAssetEditor(asset: $draftAsset, title: editorTitle) {
                store.savePortfolioAsset(draftAsset)
                isShowingAddAsset = false
                draftAsset = PortfolioAsset.empty()
                editorTitle = "Add Asset"
            }
            .presentationDetents([.large])
        }
    }

    private var portfolioHeader: some View {
        VQPanel("Portfolio Overview", systemImage: "rectangle.3.group", actionImage: "arrow.clockwise") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusPill(title: "\(store.portfolioAssets.count) \(L10n.tr("assets"))", tint: VQTheme.accent)
                    StatusPill(title: "\(store.portfolioAssets.filter { $0.status == .running }.count) \(L10n.tr("running"))", tint: VQTheme.green)
                    StatusPill(title: "\(store.portfolioAssets.filter { $0.status == .stopped }.count) \(L10n.tr("stopped"))", tint: VQTheme.amber)
                    Spacer()
                }
                HStack(spacing: 8) {
                    Button(action: store.refreshPortfolio) {
                        Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))

                    Button(action: store.discoverPortfolio) {
                        Label(L10n.tr("Discover"), systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 8))

                    Button {
                        draftAsset = PortfolioAsset.empty()
                        editorTitle = "Add Asset"
                        isShowingAddAsset = true
                    } label: {
                        Label(L10n.tr("Add"), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    Spacer()
                }
                if !store.portfolioMessage.isEmpty {
                    Text(store.portfolioMessage)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var filters: some View {
        VQPanel("Filters", systemImage: "line.3.horizontal.decrease.circle") {
            VStack(alignment: .leading, spacing: 10) {
                Picker(L10n.tr("Kind"), selection: $kindFilter) {
                    Text(L10n.tr("All")).tag(nil as PortfolioAssetKind?)
                    ForEach(PortfolioAssetKind.allCases) { kind in
                        Text(kind.title).tag(kind as PortfolioAssetKind?)
                    }
                }
                .pickerStyle(.segmented)

                Picker(L10n.tr("Status"), selection: $statusFilter) {
                    Text(L10n.tr("All")).tag(nil as PortfolioAssetStatus?)
                    ForEach(PortfolioAssetStatus.allCases) { status in
                        Text(status.title).tag(status as PortfolioAssetStatus?)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var assetGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], alignment: .leading, spacing: 12) {
            if filteredAssets.isEmpty {
                VQPanel("Assets", systemImage: "tray") {
                    Text(store.remoteHost.isPaired ? L10n.tr("No assets registered yet.") : L10n.tr("Mac Host pairing is required."))
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
            ForEach(filteredAssets) { asset in
                Button {
                    store.selectPortfolioAsset(asset)
                } label: {
                    PortfolioAssetCard(asset: asset, isSelected: store.selectedPortfolioAsset?.id == asset.id)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var selectedAssetDetail: some View {
        if let asset = store.selectedPortfolioAsset {
            VQPanel(asset.name.isEmpty ? L10n.tr("Asset Detail") : asset.name, systemImage: asset.kind.symbol) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        StatusPill(title: asset.kind.title, tint: VQTheme.steel)
                        StatusPill(title: (store.selectedPortfolioStatus?.status ?? asset.status).title, tint: tint(for: store.selectedPortfolioStatus?.status ?? asset.status))
                        StatusPill(title: asset.backupState == .git ? "Git" : L10n.tr("Local only"), tint: asset.backupState == .git ? VQTheme.green : VQTheme.steel)
                        Spacer()
                        Button {
                            draftAsset = asset
                            editorTitle = "Edit Asset"
                            isShowingAddAsset = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        Button(action: store.refreshSelectedPortfolioDetail) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }

                    if !asset.summary.isEmpty {
                        Text(asset.summary)
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 7) {
                        KeyValueLine(key: "Health", value: store.selectedPortfolioStatus?.health ?? L10n.tr("Not checked"))
                        KeyValueLine(key: "Machine", value: asset.runtimeHost ?? L10n.tr("This Mac"))
                        KeyValueLine(key: "Repository", value: asset.sourceRefs.github ?? L10n.tr("Not set"))
                        if let driveURL = asset.sourceRefs.driveUrl?.vqNilIfBlank {
                            KeyValueLine(key: "Drive", value: driveURL)
                        }
                        if let cpu = store.selectedPortfolioStatus?.cpuPercent {
                            KeyValueLine(key: "CPU", value: String(format: "%.1f%%", cpu))
                        }
                        if let memory = store.selectedPortfolioStatus?.memoryMB {
                            KeyValueLine(key: "Memory", value: String(format: "%.1f MB", memory))
                        }
                    }

                    if let summary = store.costSummary(for: asset) {
                        CostGovernancePanel(summary: summary)
                    }

                    if asset.kind == .engagement {
                        PortfolioEngagementPanel(asset: asset, assets: store.portfolioAssets)
                    }

                    PortfolioRecentCommitsPanel(commits: store.portfolioCommits)

                    PortfolioControlPanel(asset: asset)

                    VQPanel("Live Logs", systemImage: "terminal") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Button(action: store.summarizePortfolioLogs) {
                                    Label(L10n.tr("Summarize"), systemImage: "sparkles")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                Spacer()
                            }
                            if !store.portfolioLogSummary.isEmpty {
                                Text(store.portfolioLogSummary)
                                    .font(.caption)
                                    .foregroundStyle(VQTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                ForEach(Array(store.portfolioLogLines.suffix(12).enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(VQTheme.secondaryText)
                                        .lineLimit(3)
                                }
                                if store.portfolioLogLines.isEmpty {
                                    Text(L10n.tr("No logs loaded yet."))
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    HStack {
                        Button(action: store.linkSelectedPortfolioAssetToProject) {
                            Label(asset.linkedProjectId == nil ? L10n.tr("Create Project Link") : L10n.tr("Open Project"), systemImage: "sparkles.rectangle.stack")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))

                        if asset.backupState == .localOnly {
                            Button(action: store.promotePortfolioAsset) {
                                Label(L10n.tr("Private Repo"), systemImage: "arrow.up.right.square")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func tint(for status: PortfolioAssetStatus) -> Color {
        switch status {
        case .running: VQTheme.green
        case .stopped: VQTheme.amber
        case .unknown, .notApplicable: VQTheme.unavailable
        }
    }
}

private struct PortfolioAssetCard: View {
    let asset: PortfolioAsset
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: asset.kind.symbol)
                    .frame(width: 30, height: 30)
                    .foregroundStyle(isSelected ? VQTheme.accent : VQTheme.secondaryText)
                    .background(VQTheme.control.opacity(0.48))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Spacer()
                StatusPill(title: asset.status.title, tint: tint(for: asset.status))
            }
            Text(asset.name.isEmpty ? L10n.tr("Untitled") : asset.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .lineLimit(2)
            Text(asset.summary.isEmpty ? asset.kind.title : asset.summary)
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .lineLimit(2)
            FlowLayout(items: Array(asset.tags.prefix(4)) + [asset.runtimeHost ?? L10n.tr("This Mac")])
        }
        .padding(12)
        .background(isSelected ? VQTheme.accent.opacity(0.09) : VQTheme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? VQTheme.accent.opacity(0.45) : VQTheme.hairline, lineWidth: 1)
        }
    }

    private func tint(for status: PortfolioAssetStatus) -> Color {
        switch status {
        case .running: VQTheme.green
        case .stopped: VQTheme.amber
        case .unknown, .notApplicable: VQTheme.unavailable
        }
    }
}

private struct PortfolioControlPanel: View {
    @EnvironmentObject private var store: CommandCenterStore
    let asset: PortfolioAsset

    var body: some View {
        VQPanel("Controls", systemImage: "switch.2") {
            HStack(spacing: 8) {
                controlButton("start", title: "Start", symbol: "play")
                controlButton("stop", title: "Stop", symbol: "stop")
                controlButton("restart", title: "Restart", symbol: "arrow.clockwise")
                controlButton("deploy", title: "Deploy", symbol: "paperplane")
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func controlButton(_ action: String, title: String, symbol: String) -> some View {
        let command = asset.controls?.command(for: action)
        Button {
            store.runPortfolioControl(action)
        } label: {
            Label(L10n.tr(title), systemImage: symbol)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 8))
        .disabled(command == nil)
    }
}

private struct PortfolioEngagementPanel: View {
    let asset: PortfolioAsset
    let assets: [PortfolioAsset]

    var body: some View {
        VQPanel("Engagement", systemImage: "person.text.rectangle") {
            VStack(alignment: .leading, spacing: 8) {
                KeyValueLine(key: "Client", value: asset.client ?? L10n.tr("Not set"))
                KeyValueLine(key: "Phase", value: asset.phase ?? L10n.tr("Not set"))
                if let timeline = asset.timeline?.vqNilIfBlank {
                    KeyValueLine(key: "Timeline", value: timeline)
                }
                if !asset.deliverables.isEmpty {
                    Text(L10n.tr("Deliverables"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.secondaryText)
                    FlowLayout(items: asset.deliverables.map(\.name))
                }
                if !asset.relatedAssetIds.isEmpty {
                    Text(L10n.tr("Related Apps"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.secondaryText)
                    FlowLayout(items: asset.relatedAssetIds.map(relatedAssetName))
                }
            }
        }
    }

    private func relatedAssetName(_ id: String) -> String {
        assets.first(where: { $0.id == id })?.name.vqNilIfBlank ?? L10n.tr("Unknown")
    }
}

private struct PortfolioRecentCommitsPanel: View {
    let commits: [PortfolioRecentCommit]

    var body: some View {
        VQPanel("Recent Commits", systemImage: "clock.arrow.circlepath") {
            VStack(alignment: .leading, spacing: 8) {
                if commits.isEmpty {
                    Text(L10n.tr("No recent commits"))
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                } else {
                    ForEach(commits) { commit in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(commit.message.components(separatedBy: .newlines).first ?? commit.message)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VQTheme.ink)
                                .lineLimit(2)
                            Text("\(commit.author) · \(commit.date.formatted(date: .abbreviated, time: .shortened)) · \(commit.shortSHA)")
                                .font(.caption2)
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct PortfolioAssetEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var asset: PortfolioAsset
    let title: String
    let onSave: () -> Void
    @State private var localPath = ""
    @State private var tags = ""
    @State private var driveURL = ""
    @State private var deliverables = ""
    @State private var relatedAssetIDs = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("Basics")) {
                    Picker(L10n.tr("Kind"), selection: $asset.kind) {
                        ForEach(PortfolioAssetKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    TextField(L10n.tr("Name"), text: $asset.name)
                    TextField(L10n.tr("Summary"), text: $asset.summary, axis: .vertical)
                    TextField(L10n.tr("Tags"), text: $tags)
                }

                Section(L10n.tr("Source")) {
                    TextField(L10n.tr("GitHub owner/repo"), text: Binding(
                        get: { asset.sourceRefs.github ?? "" },
                        set: { asset.sourceRefs.github = $0.vqNilIfBlank }
                    ))
                    TextField(L10n.tr("Drive URL"), text: $driveURL)
                    TextField(L10n.tr("Local folder"), text: $localPath)
                }

                Section(L10n.tr("Health")) {
                    TextField(L10n.tr("http / cmd"), text: Binding(
                        get: { asset.healthSpec?.type ?? "" },
                        set: { value in
                            let target = asset.healthSpec?.target ?? ""
                            asset.healthSpec = value.vqNilIfBlank.map { PortfolioHealthSpec(type: $0, target: target) }
                        }
                    ))
                    TextField(L10n.tr("Target"), text: Binding(
                        get: { asset.healthSpec?.target ?? "" },
                        set: { value in
                            let type = asset.healthSpec?.type ?? "http"
                            asset.healthSpec = value.vqNilIfBlank.map { PortfolioHealthSpec(type: type, target: $0) }
                        }
                    ))
                }

                Section(L10n.tr("Controls")) {
                    controlField("Start", keyPath: \.start)
                    controlField("Stop", keyPath: \.stop)
                    controlField("Restart", keyPath: \.restart)
                    controlField("Deploy", keyPath: \.deploy)
                }

                if asset.kind == .engagement {
                    Section(L10n.tr("Engagement")) {
                        TextField(L10n.tr("Client"), text: Binding(get: { asset.client ?? "" }, set: { asset.client = $0.vqNilIfBlank }))
                        TextField(L10n.tr("Phase"), text: Binding(get: { asset.phase ?? "" }, set: { asset.phase = $0.vqNilIfBlank }))
                        TextField(L10n.tr("Timeline"), text: Binding(get: { asset.timeline ?? "" }, set: { asset.timeline = $0.vqNilIfBlank }))
                        TextField(L10n.tr("Deliverables"), text: $deliverables)
                        TextField(L10n.tr("Related Apps"), text: $relatedAssetIDs)
                    }
                }
            }
            .navigationTitle(L10n.tr(title))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("Save")) {
                        applyFields()
                        onSave()
                    }
                    .disabled(asset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                localPath = asset.sourceRefs.localPaths.first?.path ?? ""
                tags = asset.tags.joined(separator: ", ")
                driveURL = asset.sourceRefs.driveUrl ?? ""
                deliverables = asset.deliverables.map { "\($0.name)=\($0.ref)" }.joined(separator: ", ")
                relatedAssetIDs = asset.relatedAssetIds.joined(separator: ", ")
            }
        }
    }

    private func controlField(_ title: String, keyPath: WritableKeyPath<PortfolioControls, String?>) -> some View {
        TextField(L10n.tr(title), text: Binding(
            get: { asset.controls?[keyPath: keyPath] ?? "" },
            set: { value in
                var controls = asset.controls ?? PortfolioControls(start: nil, stop: nil, restart: nil, deploy: nil)
                controls[keyPath: keyPath] = value.vqNilIfBlank
                asset.controls = controls
            }
        ))
    }

    private func applyFields() {
        asset.tags = tags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        asset.sourceRefs.driveUrl = driveURL.vqNilIfBlank
        if let path = localPath.vqNilIfBlank {
            asset.sourceRefs.localPaths = [PortfolioLocalPath(machineId: ProcessInfo.processInfo.hostName, path: path)]
            if asset.sourceRefs.github == nil {
                asset.backupState = .localOnly
            }
        }
        asset.deliverables = deliverables.split(separator: ",").compactMap { item in
            let parts = item.split(separator: "=", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let name = parts.first?.vqNilIfBlank else { return nil }
            let ref = parts.dropFirst().first?.vqNilIfBlank ?? name
            return PortfolioDeliverable(name: name, ref: ref)
        }
        asset.relatedAssetIds = relatedAssetIDs.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        asset.status = asset.kind == .content ? .notApplicable : asset.status
    }
}

private extension PortfolioAssetKind {
    var symbol: String {
        switch self {
        case .app: "app.connected.to.app.below.fill"
        case .engagement: "person.text.rectangle"
        case .content: "doc.richtext"
        }
    }
}

private extension PortfolioControls {
    func command(for action: String) -> String? {
        switch action {
        case "start": start?.vqNilIfBlank
        case "stop": stop?.vqNilIfBlank
        case "restart": restart?.vqNilIfBlank
        case "deploy": deploy?.vqNilIfBlank
        default: nil
        }
    }
}

private extension String {
    var vqNilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct DevicesView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var remoteEndpoint = ""
    @State private var remotePairingCode = ""
    @State private var remoteDeviceName = ProcessInfo.processInfo.hostName
    @State private var pairingURLInput = ""
    @State private var showPairingScanner = false
    @State private var scannerStatusMessage = ""
    @State private var remoteStatusMessage = ""
    @State private var isPairing = false
    private let columns = [GridItem(.adaptive(minimum: 320), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Devices", systemImage: "macbook.and.iphone") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                VQPanel("Workspace", systemImage: "folder") {
                    VStack(alignment: .leading, spacing: 12) {
                        KeyValueLine(key: "Project", value: VQDisplay.workspaceName(store.workspace))
                        CompactKeyValueLine(key: "Git root", value: store.workspace.rootPath.isEmpty ? L10n.tr("Not detected") : store.workspace.rootPath, monospaced: true)
                        KeyValueLine(key: "Branch", value: store.workspace.branchLabel)
                        KeyValueLine(key: "State", value: VQDisplay.workspaceStatus(store.workspace))
                        CompactKeyValueLine(key: "Hermes path", value: store.workspace.hermesPath.isEmpty ? L10n.tr("Not detected") : store.workspace.hermesPath, monospaced: true)
                        KeyValueLine(key: "Tailscale", value: store.workspace.tailscaleIP.isEmpty ? L10n.tr("Not detected") : store.workspace.tailscaleIP)
                        if let error = store.workspace.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(VQTheme.amber)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VQPanel("Remote Mac Host", systemImage: "antenna.radiowaves.left.and.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            StatusPill(
                                title: remoteStatusTitle,
                                tint: remoteStatusTint
                            )
                            .accessibilityIdentifier("gate2.remote.pairedState")
                            .accessibilityLabel(store.remoteHost.isPaired ? "paired" : "notPaired")
                            .accessibilityValue(remoteStatusTitle)
                            StatusPill(title: "HMAC", tint: VQTheme.steel)
                            StatusPill(title: "Keychain", tint: VQTheme.green)
                            Spacer()
                        }

                        Text(remoteOnline ? L10n.tr("Ready for remote runs.") : L10n.tr("Scan the menu bar QR or paste the pairing link."))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(remoteOnline ? VQTheme.green : VQTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        if let telemetry = store.remoteHostTelemetry {
                            HStack(spacing: 8) {
                                compactTelemetryValue(compactPercent(telemetry.cpu.totalPercent), identifier: "gate2.telemetry.cpu.value")
                                compactTelemetryValue(compactMemory(telemetry.memory), identifier: "gate2.telemetry.memory.value")
                                compactTelemetryValue(compactDisk(telemetry.disk), identifier: "gate2.telemetry.disk.value")
                                compactTelemetryValue(telemetry.thermal.state.isEmpty ? "—" : telemetry.thermal.state, identifier: "gate2.telemetry.thermal.value")
                                Spacer()
                            }
                        }

                        HStack(spacing: 8) {
                            Button {
                                beginPairingScan()
                            } label: {
                                Label(L10n.tr("Scan QR"), systemImage: "qrcode.viewfinder")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))

                            Button {
                                applyPairingURLInput()
                            } label: {
                                Label(L10n.tr("Use Link"), systemImage: "link")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .disabled(pairingURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("gate2.pairing.useLink")
                        }
                        .font(.footnote.weight(.semibold))

                        RemoteConnectionField(title: L10n.tr("Pairing URL"), placeholder: "veqral://pair?endpoint=http://100.x.x.x:7878&code=ABCD1234", text: $pairingURLInput, identifier: "gate2.pairing.url")
                        RemoteConnectionField(title: L10n.tr("Saved endpoint"), placeholder: store.workspace.macHostEndpoint, text: $remoteEndpoint, identifier: "gate2.pairing.endpoint")
                        RemoteConnectionField(title: L10n.tr("Pairing code"), placeholder: L10n.tr("8-character code from menu bar QR"), text: $remotePairingCode, identifier: "gate2.pairing.code")
                        RemoteConnectionField(title: L10n.tr("This device name"), placeholder: "iPhone・iPad", text: $remoteDeviceName, identifier: "gate2.pairing.deviceName")

                        KeyValueLine(key: "Saved endpoint", value: VQDisplay.endpoint(store.remoteHost))
                        KeyValueLine(key: "Device ID", value: store.remoteHost.deviceID.isEmpty ? L10n.tr("Not Paired") : "\(store.remoteHost.deviceID.prefix(8))...")
                        KeyValueLine(key: "Tailscale", value: store.remoteHostHealth?.tailscaleIP ?? (store.workspace.tailscaleIP.isEmpty ? L10n.tr("Not verified") : store.workspace.tailscaleIP))
                        KeyValueLine(key: "Host", value: store.remoteHostHealth?.host ?? L10n.tr("Not connected"))
                        KeyValueLine(key: "Hermes", value: store.remoteHostHealth?.hermesVersion ?? L10n.tr("Not checked"))
                        KeyValueLine(key: "Push", value: store.pushNotificationMessage.isEmpty ? VeqralFeatureFlags.pushUnavailableMessage : store.pushNotificationMessage)
                        KeyValueLine(key: "Execution", value: store.remoteHost.isEnabled ? L10n.tr("iPhone/iPad -> Tailscale -> Mac Host -> Hermes") : L10n.tr("Pair a Mac Host before running on iPhone/iPad"))

                        HStack(spacing: 8) {
                            Button {
                                pairRemoteHost()
                            } label: {
                                Label(L10n.tr(isPairing ? "Pairing" : "Pair"), systemImage: "link.badge.plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .disabled(isPairing || remoteEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || remotePairingCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("gate2.pairing.pair")

                            Button {
                                store.disableRemoteHost()
                                remoteStatusMessage = L10n.tr("Remote Host disabled. Pairing data remains in Keychain.")
                            } label: {
                                Label(L10n.tr("Disable"), systemImage: "wifi.slash")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))

                            Button {
                                store.refreshRemoteHostStatus()
                            } label: {
                                Label(L10n.tr(store.isRefreshingRemoteHost ? "Refreshing" : "Refresh Host"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .disabled(!store.remoteHost.isPaired || store.isRefreshingRemoteHost)
                            .accessibilityIdentifier("gate2.host.refresh")

                            Button {
                                store.sendDiscordTestNotification()
                            } label: {
                                Label("Discord テスト", systemImage: "paperplane")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .disabled(!store.remoteHost.isPaired)
                            .accessibilityIdentifier("gate2.discord.test")
                        }
                        .font(.footnote.weight(.semibold))

                        if !store.remoteHostMessage.isEmpty {
                            Text(store.remoteHostMessage)
                                .font(.caption)
                                .foregroundStyle(store.remoteHostMessage.localizedCaseInsensitiveContains("failed") || store.remoteHostMessage.localizedCaseInsensitiveContains("offline") ? VQTheme.amber : VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !remoteStatusMessage.isEmpty {
                            Text(remoteStatusMessage)
                                .font(.caption)
                                .foregroundStyle(remoteStatusMessage.contains("failed") || remoteStatusMessage.contains("失敗") ? VQTheme.amber : VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("gate2.remote.status")
                        }

                        if !store.discordTestMessage.isEmpty {
                            Text(store.discordTestMessage)
                                .font(.caption)
                                .foregroundStyle(store.discordTestMessage.contains("失敗") || store.discordTestMessage.localizedCaseInsensitiveContains("failed") ? VQTheme.amber : VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("gate2.discord.message")
                        }
                    }
                }

                AuthOnboardingPanel(
                    status: store.authOnboardingStatus,
                    message: store.authOnboardingMessage,
                    isPaired: store.remoteHost.isPaired,
                    refresh: { store.refreshAuthOnboarding() },
                    persist: { store.refreshAuthOnboarding(persistReadyMarkers: true) }
                )

                VQPanel("CLI Diagnostics", systemImage: "stethoscope") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let toolStatuses = store.remoteHostHealth?.toolStatuses, !toolStatuses.isEmpty {
                            ForEach(toolStatuses) { status in
                                ToolDiagnosticRow(status: status)
                                if status.id != toolStatuses.last?.id {
                                    EmptyDivider()
                                }
                            }
                        } else {
                            Text(store.remoteHost.isPaired ? L10n.tr("Refresh the Mac Host to inspect Codex, Claude, and Hermes adapters.") : L10n.tr("Pair a Mac Host to inspect CLI versions."))
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VQPanel("Host Status", systemImage: "waveform.path.ecg") {
                    HostTelemetryPanel(
                        telemetry: store.remoteHostTelemetry,
                        isPaired: store.remoteHost.isPaired,
                        message: store.remoteHostTelemetryMessage
                    )
                }

                VQPanel("Run Agent on This Mac", systemImage: "switch.2") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.tr("Choose which native agent the paired Mac Host should spawn for the next command."))
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach([CommandRuntime.codexDirect, .claudeDirect, .hermesAgent]) { runtime in
                            Button {
                                store.selectRuntime(runtime)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: runtime.symbol)
                                        .frame(width: 34, height: 34)
                                        .foregroundStyle(store.selectedRuntime == runtime ? VQTheme.accent : VQTheme.secondaryText)
                                        .background((store.selectedRuntime == runtime ? VQTheme.accent : VQTheme.steel).opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(runtime.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(VQTheme.ink)
                                        Text(runtime.contextModeDescription)
                                            .font(.caption)
                                            .foregroundStyle(VQTheme.secondaryText)
                                    }
                                    Spacer()
                                    StatusPill(
                                        title: store.selectedRuntime == runtime ? "Selected" : "Available",
                                        tint: store.selectedRuntime == runtime ? VQTheme.green : VQTheme.steel
                                    )
                                }
                                .padding(10)
                                .background(store.selectedRuntime == runtime ? VQTheme.accent.opacity(0.08) : VQTheme.control.opacity(0.30))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }

                        KeyValueLine(key: "Direct mode", value: L10n.tr("Codex and Claude keep their own native history."))
                        KeyValueLine(key: "Hermes mode", value: L10n.tr("Project chats share Hermes memory across model changes."))
                    }
                }

                VQPanel("Paired Devices", systemImage: "iphone.gen3.radiowaves.left.and.right") {
                    VStack(alignment: .leading, spacing: 12) {
                        let devices = store.visibleRemoteDevices
                        if devices.isEmpty {
                            Text(store.remoteHost.isPaired ? L10n.tr("No other paired devices yet.") : L10n.tr("Pair a Mac Host to list trusted iPhone/iPad clients."))
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        }

                        ForEach(devices) { device in
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "rectangle.connected.to.line.below")
                                    .foregroundStyle(device.lastSeenAt == nil ? VQTheme.unavailable : VQTheme.green)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(device.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(L10n.tr("Last seen")) \(dateLabel(device.lastSeenAt))")
                                        .font(.caption)
                                        .foregroundStyle(VQTheme.secondaryText)
                                    Text(device.pushUpdatedAt == nil ? L10n.tr("Push not registered") : "Push \(device.pushEnvironment ?? L10n.tr("unknown")) - \(dateLabel(device.pushUpdatedAt))")
                                        .font(.caption)
                                        .foregroundStyle(device.pushUpdatedAt == nil ? VQTheme.secondaryText : VQTheme.green)
                                    Text(device.id)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(VQTheme.secondaryText)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    store.revokeRemoteDevice(device)
                                } label: {
                                    Label(L10n.tr("Revoke"), systemImage: "xmark.circle")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                            }
                            if device.id != devices.last?.id {
                                EmptyDivider()
                            }
                        }
                    }
                }

                VQPanel("Host Audit", systemImage: "list.bullet.rectangle") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            if store.remoteAuditLines.isEmpty {
                                StatusPill(title: L10n.tr("No audit events"), tint: VQTheme.unavailable)
                            } else {
                                StatusPill(title: "\(store.remoteAuditLines.count) \(L10n.tr("events"))", tint: VQTheme.steel)
                            }
                            Spacer()
                            Button(action: store.refreshRemoteHostStatus) {
                                Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            .font(.footnote.weight(.semibold))
                            .disabled(!store.remoteHost.isPaired)
                        }

                        if store.remoteAuditLines.isEmpty {
                            Text(L10n.tr("No audit events loaded yet."))
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        }

                        ForEach(Array(store.remoteAuditLines.suffix(8).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundStyle(VQTheme.secondaryText)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VQPanel("Mac Host Pairing", systemImage: "qrcode.viewfinder") {
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.system(size: 54, weight: .light))
                            .foregroundStyle(VQTheme.accent)
                            .frame(width: 132, height: 132)
                            .background(VQTheme.control.opacity(0.62))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(VQTheme.hairline, lineWidth: 1)
                            }

                        VStack(alignment: .leading, spacing: 12) {
                            KeyValueLine(key: "Saved endpoint", value: VQDisplay.endpoint(store.remoteHost))
                            KeyValueLine(key: "Current state", value: L10n.tr(remoteStatusTitle))
                            KeyValueLine(key: "Transport", value: "Tailscale WebSocket")
                            KeyValueLine(key: "Host app", value: L10n.tr("Use the Mac Host pairing QR or deep link"))
                            Text(L10n.tr("Pairing codes are generated by the running Mac Host and rotate after successful pairing. Paste the Host endpoint and current code above if the QR deep link is unavailable."))
                                .font(.caption)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Button(action: store.refreshRemoteHostStatus) {
                                    Label(L10n.tr("Refresh Host"), systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                .disabled(!store.remoteHost.isPaired)
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
        }
        .onAppear {
            syncRemoteFields()
            applyUITestPairingURLIfNeeded()
            if store.remoteHost.isPaired {
                store.refreshAuthOnboarding()
            }
        }
        .onChange(of: store.remoteHost) { _, _ in
            syncRemoteFields()
        }
        .task(id: store.remoteHost.deviceID) {
            await telemetryLoop()
        }
        .sheet(isPresented: $showPairingScanner) {
            PairingQRScannerSheet(
                statusMessage: scannerStatusMessage,
                onCode: { payload in
                    showPairingScanner = false
                    handleScannedPairingPayload(payload)
                },
                onFailure: { message in
                    scannerStatusMessage = message
                    remoteStatusMessage = message
                }
            )
        }
        .accessibilityIdentifier("gate2.screen.devices")
    }

    private func syncRemoteFields() {
        remoteEndpoint = store.remoteHost.endpoint.isEmpty ? store.workspace.macHostEndpoint : store.remoteHost.endpoint
        if remoteDeviceName.isEmpty {
            remoteDeviceName = ProcessInfo.processInfo.hostName
        }
    }

    private func applyUITestPairingURLIfNeeded() {
        let url = ProcessInfo.processInfo.environment["VEQRAL_UI_TEST_PAIRING_URL"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard pairingURLInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        if let url, !url.isEmpty {
            pairingURLInput = url
            return
        }
        let env = ProcessInfo.processInfo.environment
        guard CommandLine.arguments.contains("-veqral-ui-testing") || env["VEQRAL_UI_TESTING"] == "1" else {
            return
        }
        Task {
            await fetchUITestPairingURL()
        }
    }

    @MainActor
    private func fetchUITestPairingURL() async {
        struct PairingStatus: Decodable {
            var pairingURL: String
            var pairingCode: String?
        }
        #if targetEnvironment(simulator)
        let pairingStatusURLs = ["http://127.0.0.1:18778/v1/pairing", "http://100.96.40.99:18778/v1/pairing"]
        #else
        let pairingStatusURLs = ["http://100.96.40.99:18778/v1/pairing", "http://127.0.0.1:18778/v1/pairing"]
        #endif
        for value in pairingStatusURLs {
            guard let url = URL(string: value),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let status = try? JSONDecoder().decode(PairingStatus.self, from: data),
                  !status.pairingURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            #if targetEnvironment(simulator)
            let code = status.pairingCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if value.contains("127.0.0.1"), !code.isEmpty {
                var components = URLComponents()
                components.scheme = "veqral"
                components.host = "pair"
                components.queryItems = [
                    URLQueryItem(name: "endpoint", value: "http://127.0.0.1:18778"),
                    URLQueryItem(name: "code", value: code)
                ]
                pairingURLInput = components.string ?? status.pairingURL
                return
            }
            #endif
            pairingURLInput = status.pairingURL
            return
        }
    }

    private func telemetryLoop() async {
        guard await MainActor.run(body: { store.remoteHost.isPaired }) else { return }
        await MainActor.run {
            store.refreshRemoteHostTelemetry()
        }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            let isPaired = await MainActor.run(body: { store.remoteHost.isPaired })
            guard isPaired else { return }
            await MainActor.run {
                store.refreshRemoteHostTelemetry()
            }
        }
    }

    private func pairRemoteHost(pairingSignature: String? = nil) {
        isPairing = true
        remoteStatusMessage = L10n.tr("Pairing with Mac Host...")
        let endpoint = remoteEndpoint
        let code = remotePairingCode
        let deviceName = remoteDeviceName.isEmpty ? ProcessInfo.processInfo.hostName : remoteDeviceName
        Task { @MainActor in
            do {
                try await store.pairRemoteHost(endpoint: endpoint, pairingCode: code, pairingSignature: pairingSignature, deviceName: deviceName)
                remotePairingCode = ""
                remoteStatusMessage = L10n.tr("Paired. Future runs will launch through Mac Host.")
            } catch {
                remoteStatusMessage = "\(L10n.tr("Pairing failed")): \(error.localizedDescription)"
            }
            isPairing = false
        }
    }

    private func beginPairingScan() {
        scannerStatusMessage = L10n.tr("Point the camera at the Mac Host QR.")
        #if targetEnvironment(macCatalyst)
        remoteStatusMessage = L10n.tr("QR scanning is unavailable on Mac Catalyst. Use the pairing link or code.")
        return
        #else
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            remoteStatusMessage = L10n.tr("Camera is not available on this device. Use manual pairing instead.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showPairingScanner = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showPairingScanner = true
                    } else {
                        remoteStatusMessage = L10n.tr("Camera permission denied. Enable it in Settings to scan pairing QR.")
                    }
                }
            }
        case .denied:
            remoteStatusMessage = L10n.tr("Camera permission denied. Enable it in Settings to scan pairing QR.")
        case .restricted:
            remoteStatusMessage = L10n.tr("Camera access is restricted on this device.")
        @unknown default:
            remoteStatusMessage = L10n.tr("Camera authorization state is unavailable.")
        }
        #endif
    }

    private func applyPairingURLInput() {
        let value = pairingURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        handleScannedPairingPayload(value)
    }

    private func handleScannedPairingPayload(_ payload: String) {
        guard let url = URL(string: payload),
              url.scheme == "veqral",
              url.host == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            remoteStatusMessage = L10n.tr("Pairing QR was not recognized.")
            return
        }
        var values: [String: String] = [:]
        components.queryItems?.forEach { item in
            if let value = item.value {
                values[item.name] = value
            }
        }
        guard let endpoint = values["endpoint"], let code = values["code"] else {
            remoteStatusMessage = L10n.tr("Pairing URL is missing endpoint or code.")
            return
        }
        let signature = values["signature"] ?? values["sig"]
        remoteEndpoint = endpoint
        remotePairingCode = code
        pairingURLInput = payload
        remoteStatusMessage = L10n.tr("QR recognized. Pairing...")
        pairRemoteHost(pairingSignature: signature)
    }

    private var remoteOnline: Bool {
        store.remoteHost.isEnabled && store.remoteHost.isPaired && store.remoteHostHealth?.status == "ok"
    }

    private var remoteStatusTitle: String {
	        if remoteOnline { return "Online" }
	        if store.remoteHost.isEnabled && store.remoteHost.isPaired { return "Offline" }
	        return "Not Paired"
    }

    private var remoteStatusTint: Color {
        if remoteOnline { return VQTheme.green }
        if store.remoteHost.isEnabled && store.remoteHost.isPaired { return VQTheme.unavailable }
        return VQTheme.amber
    }

    private func compactTelemetryValue(_ value: String, identifier: String) -> some View {
        Text(value)
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(VQTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(VQTheme.control.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityIdentifier(identifier)
    }

    private func compactPercent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    private func compactMemory(_ memory: RemoteHostTelemetryMemory) -> String {
        guard let used = memory.usedBytes, let total = memory.totalBytes, total > 0 else { return "—" }
        return "\(Int((Double(used) / Double(total) * 100).rounded()))%"
    }

    private func compactDisk(_ disk: RemoteHostTelemetryDisk) -> String {
        guard let value = disk.usedPercent else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return L10n.tr("Never") }
        return Self.deviceDateFormatter.string(from: date)
    }

    private static let deviceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct HostTelemetryPanel: View {
    let telemetry: RemoteHostTelemetry?
    let isPaired: Bool
    let message: String

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let telemetry {
                HStack(spacing: 8) {
                    StatusPill(title: L10n.tr("Live"), tint: VQTheme.green)
                    StatusPill(title: thermalLabel(telemetry.thermal.state), tint: thermalTint(telemetry.thermal.state))
                    StatusPill(title: "\(L10n.tr("Updated")) \(relativeTime(telemetry.checkedAt))", tint: VQTheme.steel)
                    Spacer()
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                    telemetryMetric("CPU Usage", value: percent(telemetry.cpu.totalPercent), symbol: "cpu", identifier: "gate2.telemetry.cpu")
                    telemetryMetric("Load", value: loadAverage(telemetry.cpu.loadAverage), symbol: "gauge.with.dots.needle.67percent", identifier: "gate2.telemetry.load")
                    telemetryMetric("Memory", value: memorySummary(telemetry.memory), symbol: "memorychip", identifier: "gate2.telemetry.memory")
                    telemetryMetric("Disk", value: diskSummary(telemetry.disk), symbol: "internaldrive", identifier: "gate2.telemetry.disk")
                    telemetryMetric("Thermal State", value: thermalLabel(telemetry.thermal.state), symbol: "thermometer.medium", identifier: "gate2.telemetry.thermal")
                    telemetryMetric("Uptime", value: uptime(telemetry.uptime.seconds), symbol: "clock.arrow.circlepath", identifier: "gate2.telemetry.uptime")
                    telemetryMetric("Battery", value: powerSummary(telemetry.power), symbol: "battery.75", identifier: "gate2.telemetry.battery")
                    telemetryMetric("Network", value: networkSummary(telemetry.network), symbol: "network", identifier: "gate2.telemetry.network")
                }

                VStack(alignment: .leading, spacing: 8) {
                    KeyValueLine(key: "Memory Pressure", value: telemetry.memory.pressure)
                    KeyValueLine(key: "OS", value: telemetry.uptime.osVersion)
                    KeyValueLine(key: "Machine", value: telemetry.uptime.machineModel)
                    KeyValueLine(key: "Raw Temperature", value: telemetry.thermal.rawTemperatureC.map { String(format: "%.1f C", $0) } ?? "—")
                    KeyValueLine(key: "Fan", value: telemetry.thermal.fanRPM.map { String(format: "%.0f rpm", $0) } ?? "—")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.tr("Top Processes"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    if telemetry.topProcesses.isEmpty {
                        Text(L10n.tr("No process sample."))
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                    } else {
                        ForEach(telemetry.topProcesses.prefix(5)) { process in
                            HStack(spacing: 8) {
                                Text(process.name)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(VQTheme.ink)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("CPU \(percent(process.cpuPercent))")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(VQTheme.secondaryText)
                                Text(memoryMB(process.memoryMB))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(VQTheme.secondaryText)
                            }
                        }
                    }
                }
            } else {
                Text(isPaired ? L10n.tr("Refresh Host to load telemetry.") : L10n.tr("Host telemetry appears after pairing."))
                    .font(.subheadline)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(message.contains("失敗") || message.localizedCaseInsensitiveContains("failed") ? VQTheme.amber : VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("gate2.telemetry.message")
            }
        }
        .accessibilityIdentifier("gate2.telemetry.panel")
    }

    private func telemetryMetric(_ title: String, value: String, symbol: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 22)
                .foregroundStyle(VQTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr(title))
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                Text(value)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(2)
                    .accessibilityIdentifier("\(identifier).value")
            }
        }
        .padding(9)
        .background(VQTheme.control.opacity(0.30))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier(identifier)
    }

    private func memorySummary(_ memory: RemoteHostTelemetryMemory) -> String {
        "\(bytes(memory.usedBytes)) / \(bytes(memory.totalBytes))"
    }

    private func diskSummary(_ disk: RemoteHostTelemetryDisk) -> String {
        "\(percent(disk.usedPercent)) \(L10n.tr("used")) · \(bytes(disk.freeBytes)) \(L10n.tr("free"))"
    }

    private func loadAverage(_ values: [Double]) -> String {
        guard values.count == 3 else { return "—" }
        return values.map { String(format: "%.2f", $0) }.joined(separator: " / ")
    }

    private func powerSummary(_ power: RemoteHostTelemetryPower) -> String {
        guard power.isBatteryAvailable else {
            return power.isACPowered == true ? L10n.tr("AC power") : "—"
        }
        let percentText = power.batteryPercent.map { String(format: "%.0f%%", $0) } ?? "—"
        if power.isCharging == true {
            return "\(percentText) · \(L10n.tr("Charging"))"
        }
        return percentText
    }

    private func networkSummary(_ network: RemoteHostTelemetryNetwork) -> String {
        let route = network.tailscaleIP ?? network.interfaceName ?? "—"
        if let rx = network.rxBytesPerSecond, let tx = network.txBytesPerSecond {
            return "\(route) · ↓ \(bytesPerSecond(rx)) ↑ \(bytesPerSecond(tx))"
        }
        return route
    }

    private func thermalLabel(_ state: String) -> String {
        switch state {
        case "nominal":
            return L10n.tr("Nominal")
        case "fair":
            return L10n.tr("Fair")
        case "serious":
            return L10n.tr("Serious")
        case "critical":
            return L10n.tr("Critical")
        default:
            return L10n.tr("Unknown")
        }
    }

    private func thermalTint(_ state: String) -> Color {
        switch state {
        case "nominal":
            return VQTheme.green
        case "fair":
            return VQTheme.amber
        case "serious", "critical":
            return VQTheme.red
        default:
            return VQTheme.unavailable
        }
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f%%", value)
    }

    private func bytes(_ value: UInt64?) -> String {
        guard let value else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary)
    }

    private func bytesPerSecond(_ value: Double) -> String {
        "\(ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .binary))/s"
    }

    private func memoryMB(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f MB", value)
    }

    private func uptime(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        if seconds < 60 {
            return "\(seconds)s"
        }
        return "\(seconds / 60)m"
    }
}

private struct PairingQRScannerSheet: View {
    let statusMessage: String
    let onCode: (String) -> Void
    let onFailure: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                QRCodeScannerView(onCode: onCode, onFailure: onFailure)
                    .ignoresSafeArea()

                VStack(spacing: 10) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(VQTheme.accent)
                    Text(statusMessage.isEmpty ? L10n.tr("Point the camera at the Mac Host QR.") : statusMessage)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                    Text(L10n.tr("The QR is shown from the Veqral menu bar app."))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.black.opacity(0.58))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AuthOnboardingPanel: View {
    let status: RemoteAuthOnboardingStatus?
    let message: String
    let isPaired: Bool
    let refresh: () -> Void
    let persist: () -> Void

    var body: some View {
        VQPanel("認証オンボーディング", systemImage: "person.badge.key") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    StatusPill(title: status?.allRequiredReady == true ? "準備完了" : "確認が必要", tint: status?.allRequiredReady == true ? VQTheme.green : VQTheme.amber)
                    if let status {
                        StatusPill(title: "\(status.readyCount)/\(status.providers.count)", tint: VQTheme.steel)
                    }
                    Spacer()
                    Button(action: refresh) {
                        Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    .disabled(!isPaired)

                    Button(action: persist) {
                        Label("ログイン確認", systemImage: "key.viewfinder")
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    .disabled(!isPaired)
                }
                .font(.footnote.weight(.semibold))

                Text(isPaired ? (message.isEmpty ? "Mac 側で login した後、この画面で確認します。" : message) : L10n.tr("Mac Host pairing is required."))
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let status {
                    ForEach(status.providers) { provider in
                        AuthProviderRow(provider: provider)
                        if provider.id != status.providers.last?.id {
                            EmptyDivider()
                        }
                    }
                } else {
                    Text("Codex / Claude / Hermes のログイン状態は Host 接続後に表示されます。")
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
        }
    }
}

private struct AuthProviderRow: View {
    let provider: RemoteAuthProviderStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(tint)
                    .background(tint.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(provider.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                StatusPill(title: provider.isInstalled ? "CLI" : "未インストール", tint: provider.isInstalled ? VQTheme.green : VQTheme.amber)
                StatusPill(title: provider.isLoggedIn ? "login 済み" : "login 未確認", tint: provider.isLoggedIn ? VQTheme.green : VQTheme.amber)
                StatusPill(title: provider.hermesProviderReady ? "Hermes OK" : "Hermes 未確認", tint: provider.hermesProviderReady ? VQTheme.green : VQTheme.amber)
                if provider.keychainMarkerPresent {
                    StatusPill(title: "Keychain", tint: VQTheme.green)
                }
                Spacer(minLength: 0)
            }

            Text(provider.summary)
                .font(.caption)
                .foregroundStyle(provider.isReady ? VQTheme.secondaryText : VQTheme.amber)
                .fixedSize(horizontal: false, vertical: true)

            commandLine(provider.loginCommand)
            if let alternate = provider.alternateLoginCommand, !alternate.isEmpty {
                commandLine(alternate)
            }

            if !provider.credentialHints.isEmpty {
                Text(provider.credentialHints.joined(separator: " / "))
                    .font(.caption2.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            ForEach(provider.warnings, id: \.self) { warning in
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(VQTheme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func commandLine(_ command: String) -> some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.caption.monospaced())
                .foregroundStyle(VQTheme.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button {
                UIPasteboard.general.string = command
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle(radius: 8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(VQTheme.control.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var tint: Color {
        provider.isReady ? VQTheme.green : VQTheme.amber
    }

    private var iconName: String {
        switch provider.id {
        case "codex":
            return "terminal"
        case "claude":
            return "bubble.left.and.text.bubble.right"
        default:
            return "point.3.connected.trianglepath.dotted"
        }
    }
}

private struct ToolDiagnosticRow: View {
    let status: RemoteCLIToolStatus

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .frame(width: 28, height: 28)
                .foregroundStyle(tint)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(status.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    StatusPill(title: status.isInstalled ? "Installed" : "Missing", tint: status.isInstalled ? VQTheme.green : VQTheme.amber)
                    StatusPill(title: status.isKnownCompatible ? "Adapter OK" : "Check Adapter", tint: status.isKnownCompatible ? VQTheme.green : VQTheme.amber)
                    Spacer(minLength: 0)
                }
                Text(status.versionSummary)
                    .font(.caption.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(2)
                Text(status.compatibilityNote)
                    .font(.caption)
                    .foregroundStyle(status.isKnownCompatible ? VQTheme.secondaryText : VQTheme.amber)
                    .fixedSize(horizontal: false, vertical: true)
                if let commandShape = status.commandShape, !commandShape.isEmpty {
                    Text(commandShape)
                        .font(.caption2.monospaced())
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var tint: Color {
        if !status.isInstalled { return VQTheme.amber }
        return status.isKnownCompatible ? VQTheme.green : VQTheme.amber
    }

    private var iconName: String {
        switch status.engine {
        case "codex":
            return "terminal"
        case "claude":
            return "bubble.left.and.text.bubble.right"
        default:
            return "point.3.connected.trianglepath.dotted"
        }
    }
}

struct ProjectsView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var newChatTitle = ""
    @State private var renameChatTitle = ""

    var body: some View {
        ScreenScaffold(title: "Projects", systemImage: "folder") {
            VQPanel(VQDisplay.workspaceName(store.workspace), systemImage: "folder.badge.gearshape") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatusPill(title: VQDisplay.workspaceStatus(store.workspace), tint: VQDisplay.workspaceStatusTint(store.workspace))
                        Spacer()
                        Label("\(store.runs.count)", systemImage: "play.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    KeyValueLine(key: "Repository", value: store.workspace.remoteLabel)
                    CompactKeyValueLine(key: "Local path", value: store.workspace.workingDirectory, monospaced: true)
                    CompactKeyValueLine(key: "Git root", value: store.workspace.rootPath.isEmpty ? L10n.tr("Not detected") : store.workspace.rootPath, monospaced: true)
                    KeyValueLine(key: "Branch", value: store.workspace.branchLabel)
                    FlowLayout(items: ["Hermes Project", "Codex Direct", "Claude Direct", L10n.tr("Approvals"), "Git Diff"])
                }
            }

            VQPanel("Hermes Projects", systemImage: "sparkles.rectangle.stack") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        StatusPill(title: "Unified memory", tint: VQTheme.green)
                        StatusPill(title: store.selectedHermesChoiceTitle.isEmpty ? "Hermes Auto" : store.selectedHermesChoiceTitle, tint: VQTheme.accent)
                        Spacer()
                        Button {
                            store.useCurrentWorkspaceForHermes()
                        } label: {
                            Label(L10n.tr("Use Current Folder"), systemImage: "folder.badge.plus")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }
                    .font(.footnote.weight(.semibold))

                    if store.agentProjects.isEmpty {
                        Text(L10n.tr("Select a folder on Mac or use the current workspace to create the first Hermes project."))
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }

                    ForEach(store.agentProjects) { project in
                        Button {
                            store.selectAgentProject(project)
                            renameChatTitle = store.selectedAgentChat?.title ?? ""
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(VQDisplay.projectName(project))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VQTheme.ink)
                                    Spacer()
                                    StatusPill(
                                        title: store.selectedAgentProject?.id == project.id ? "Selected" : "\(project.chats.count) \(L10n.tr("chats"))",
                                        tint: store.selectedAgentProject?.id == project.id ? VQTheme.green : VQTheme.steel
                                    )
                                }
                                Text(project.workingDirectory)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(VQTheme.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(10)
                            .background(store.selectedAgentProject?.id == project.id ? VQTheme.accent.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VQPanel("Hermes Chats", systemImage: "bubble.left.and.text.bubble.right") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        TextField(L10n.tr("New chat title"), text: $newChatTitle)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            store.createHermesChat(title: newChatTitle)
                            newChatTitle = ""
                        } label: {
                            Label(L10n.tr("New Chat"), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }

                    if store.selectedAgentProject?.chats.isEmpty != false {
                        Text(L10n.tr("Create a chat to run Hermes inside the selected project. Separate chats can use different models while Hermes keeps project memory."))
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }

                    HermesChatModelPicker()

                    ForEach(store.selectedAgentProject?.chats ?? []) { chat in
                        let isSelected = store.selectedAgentChat?.id == chat.id
                        HStack(spacing: 10) {
                            Image(systemName: "message.badge.waveform")
                                .foregroundStyle(isSelected ? VQTheme.accent : VQTheme.secondaryText)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                if isSelected {
                                    TextField(L10n.tr("Session name"), text: $renameChatTitle)
                                        .textFieldStyle(.roundedBorder)
                                        .onAppear {
                                            renameChatTitle = chat.title
                                        }
                                } else {
                                    Text(chat.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VQTheme.ink)
                                }
                                Text(chat.sessionID ?? L10n.tr("New Hermes session"))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(VQTheme.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            if isSelected {
                                Button(L10n.tr("Save Name")) {
                                    store.renameSelectedHermesChat(renameChatTitle)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                            }
                            StatusPill(title: chat.model.isEmpty ? chat.provider : chat.model, tint: VQTheme.accent)
                        }
                        .padding(10)
                        .background(isSelected ? VQTheme.accent.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if !isSelected {
                                store.selectAgentChat(chat)
                                renameChatTitle = chat.title
                            }
                        }
                    }

                    HStack {
                        Button {
                            store.submitHermesProjectCommand()
                        } label: {
                            Label(L10n.tr("Send to Selected Chat"), systemImage: "paperplane")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(store.commandDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        Text(L10n.tr("Uses Command draft"))
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                }
            }
        }
        .onAppear(perform: store.ensureAgentProjectForCurrentWorkspace)
        .onChange(of: store.selectedAgentChat?.id) { _, _ in
            renameChatTitle = store.selectedAgentChat?.title ?? ""
        }
    }
}

private struct HermesChatModelPicker: View {
    @EnvironmentObject private var store: CommandCenterStore

    private var selection: Binding<String> {
        Binding(
            get: { store.selectedHermesProvider + "|" + store.selectedHermesModel },
            set: { value in
                let parts = value.split(separator: "|", maxSplits: 1).map(String.init)
                let choice = HermesModelChoice.defaults.first {
                    $0.provider == parts.first && $0.model == (parts.count > 1 ? parts[1] : "")
                }
                if let choice {
                    store.selectHermesModel(choice)
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(L10n.tr("Hermes Model"), systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                StatusPill(title: store.selectedHermesChoiceTitle.isEmpty ? "Hermes Auto" : store.selectedHermesChoiceTitle, tint: VQTheme.accent)
            }

            Picker(L10n.tr("Hermes Model"), selection: selection) {
                ForEach(HermesModelChoice.defaults) { choice in
                    Text(choice.title).tag(choice.provider + "|" + choice.model)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 6) {
                KeyValueLine(key: "Provider", value: store.selectedHermesProvider)
                KeyValueLine(key: "Model", value: store.selectedHermesModel.isEmpty ? L10n.tr("Hermes default") : store.selectedHermesModel)
            }

            Text(L10n.tr("Codex and Claude direct modes keep their own CLI model settings."))
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(VQTheme.control.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct RunsView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedPhase: RunPhase? = nil

    private var filteredRuns: [CommandRun] {
        store.visibleRuns(phase: selectedPhase)
    }

    var body: some View {
        ScreenScaffold(title: "Runs", systemImage: "play.rectangle.on.rectangle") {
            ApprovalFastLane()

            VQPanel("Pipeline", systemImage: "timeline.selection") {
                PhaseRail(current: selectedPhase ?? store.selectedRun?.phase ?? .implementation)
                Picker("Phase", selection: $selectedPhase) {
                    Text(L10n.tr("All")).tag(nil as RunPhase?)
                    ForEach(RunPhase.allCases) { phase in
                        Text(phase.title).tag(phase as RunPhase?)
                    }
                }
                .pickerStyle(.segmented)
            }

            VQPanel("Queue", systemImage: "list.bullet.rectangle") {
                VStack(alignment: .leading, spacing: 12) {
                    if filteredRuns.isEmpty {
                        Text(L10n.tr("No runs in this phase yet."))
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    ForEach(filteredRuns) { run in
                        Button {
                            store.selectRun(run.id)
                        } label: {
                            CommandRunListRow(run: run, isSelected: store.selectedRunID == run.id)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                store.archiveRun(run)
                            } label: {
                                Label(L10n.tr("Archive"), systemImage: "archivebox")
                            }
                            .tint(.gray)
                        }
                        if run.id != filteredRuns.last?.id {
                            EmptyDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct ApprovalFastLane: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        let pending = store.pendingApprovals(limit: 4)
        if !pending.isEmpty {
            VQPanel(L10n.tr("One-tap approvals"), systemImage: "hand.raised.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("Approve or reject without opening a run."))
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                    ForEach(pending) { approval in
                        CompactApprovalDecisionRow(approval: approval)
                        if approval.id != pending.last?.id {
                            EmptyDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct CompactApprovalDecisionRow: View {
    let approval: CommandApproval

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: approval.symbolName)
                .frame(width: 30, height: 30)
                .foregroundStyle(approval.tint)
                .background(approval.tint.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(approval.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                Text(approval.detail)
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            ApprovalActionButtons(approval: approval)
                .frame(minWidth: 190)
        }
        .font(.footnote.weight(.semibold))
    }
}

struct DiffView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var imageMode: ImageDiffMode = .sideBySide

    var body: some View {
        ScreenScaffold(title: "Diff", systemImage: "plus.forwardslash.minus") {
            VQPanel("Changed Files", systemImage: "doc.on.doc") {
                VStack(alignment: .leading, spacing: 12) {
                    let diffs = store.diffEntries(for: store.selectedRun?.id)
                    if diffs.isEmpty {
                        Text(L10n.tr("Git diffはまだありません。Mac版でgit管理下のフォルダを指定すると取得します。"))
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    ForEach(diffs) { file in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(file.path)
                                    .font(.subheadline.monospaced().weight(.semibold))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text("+\(file.additions) -\(file.deletions)")
                                    .font(.caption.monospaced().weight(.semibold))
                                    .foregroundStyle(file.deletions > 0 ? VQTheme.amber : VQTheme.green)
                            }
                            HStack {
                                Button {
                                    store.attachDiffInstruction(file)
                                } label: {
                                    Label(L10n.tr("Attach to Command"), systemImage: "paperclip")
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                                Spacer()
                            }
                            .font(.caption.weight(.semibold))

                            if let patch = file.patch?.trimmingCharacters(in: .whitespacesAndNewlines), !patch.isEmpty {
                                ForEach(Self.hunks(from: patch).prefix(3), id: \.self) { hunk in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            StatusPill(title: L10n.tr("Diff Hunk"), tint: VQTheme.accent)
                                            Spacer()
                                            Button {
                                                store.attachDiffInstruction(file, hunk: hunk)
                                            } label: {
                                                Label(L10n.tr("Attach to Command"), systemImage: "paperclip")
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(VQTheme.accent)
                                        }
                                        Text(hunk)
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(VQTheme.secondaryText)
                                            .lineLimit(12)
                                            .textSelection(.enabled)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(VQTheme.control.opacity(0.36))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }
                            }
                        }
                        if file.id != diffs.last?.id {
                            EmptyDivider()
                        }
                    }
                }
            }

            VQPanel(L10n.tr("Image Diff"), systemImage: "photo.stack") {
                ImageDiffComparisonPanel(artifacts: store.remoteArtifacts, imageData: store.artifactImageData, mode: $imageMode)
            }

            VQPanel("Review Notes", systemImage: "text.badge.checkmark") {
                VStack(alignment: .leading, spacing: 10) {
                    ReviewNote(symbol: "checkmark.circle", text: "Responsive navigation separates iPhone tabs from iPad inspection.")
                    ReviewNote(symbol: "antenna.radiowaves.left.and.right", text: "Mac Host can now stream Hermes logs and sync run diffs over the remote transport.")
                    ReviewNote(symbol: "arrow.triangle.2.circlepath", text: "Diff summaries are populated from the paired Host when a remote run is available.")
                }
            }
        }
    }

    private static func hunks(from patch: String) -> [String] {
        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var hunks: [String] = []
        var current: [String] = []
        for line in lines {
            if line.hasPrefix("@@") {
                if !current.isEmpty {
                    hunks.append(current.joined(separator: "\n"))
                    current.removeAll()
                }
            }
            if line.hasPrefix("@@") || !current.isEmpty {
                current.append(line)
            }
        }
        if !current.isEmpty {
            hunks.append(current.joined(separator: "\n"))
        }
        return hunks.isEmpty ? [patch] : hunks
    }
}

private enum ImageDiffMode: String, CaseIterable, Identifiable {
    case sideBySide
    case slider
    case overlay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sideBySide: L10n.tr("Side by side")
        case .slider: L10n.tr("Slider")
        case .overlay: L10n.tr("Overlay")
        }
    }
}

private struct ImageDiffComparisonPanel: View {
    let artifacts: [RemoteArtifactRecord]
    let imageData: [String: Data]
    @Binding var mode: ImageDiffMode
    @State private var sliderValue = 0.5

    private var images: [RemoteArtifactRecord] {
        artifacts.filter { artifact in
            let type = artifact.type.lowercased()
            let path = artifact.path.lowercased()
            return ["png", "jpg", "jpeg", "gif", "image/png", "image/jpeg"].contains(type)
                || path.hasSuffix(".png")
                || path.hasSuffix(".jpg")
                || path.hasSuffix(".jpeg")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(L10n.tr("Image Diff"), selection: $mode) {
                ForEach(ImageDiffMode.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            if images.count < 2 {
                Text(L10n.tr("No image artifacts yet."))
                    .font(.subheadline)
                    .foregroundStyle(VQTheme.secondaryText)
            } else {
                let before = images[0]
                let after = images[1]
                switch mode {
                case .sideBySide:
                    HStack(spacing: 10) {
                        ArtifactImagePreview(artifact: before, data: imageData[before.id], label: "Before")
                        ArtifactImagePreview(artifact: after, data: imageData[after.id], label: "After")
                    }
                case .slider:
                    VStack(spacing: 10) {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                ArtifactUIImage(artifact: after, data: imageData[after.id])
                                ArtifactUIImage(artifact: before, data: imageData[before.id])
                                    .mask(alignment: .leading) {
                                        Rectangle().frame(width: proxy.size.width * CGFloat(sliderValue))
                                    }
                                Rectangle()
                                    .fill(VQTheme.accent)
                                    .frame(width: 2)
                                    .offset(x: proxy.size.width * CGFloat(sliderValue))
                            }
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Slider(value: $sliderValue)
                    }
                case .overlay:
                    ZStack {
                        ArtifactUIImage(artifact: before, data: imageData[before.id])
                        ArtifactUIImage(artifact: after, data: imageData[after.id])
                            .opacity(0.52)
                            .blendMode(.screen)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }
}

private struct ArtifactImagePreview: View {
    let artifact: RemoteArtifactRecord
    let data: Data?
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.tr(label))
                .font(.caption.weight(.semibold))
                .foregroundStyle(VQTheme.secondaryText)
            ArtifactUIImage(artifact: artifact, data: data)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct ArtifactUIImage: View {
    let artifact: RemoteArtifactRecord
    let data: Data?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.25))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(VQTheme.accent)
                    Text(artifact.title)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VQTheme.control.opacity(0.32))
            }
        }
    }

    private var image: UIImage? {
        data.flatMap(UIImage.init(data:)) ?? UIImage(contentsOfFile: artifact.path)
    }
}

struct ArtifactsView: View {
    @EnvironmentObject private var store: CommandCenterStore
    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        ScreenScaffold(title: "Artifacts", systemImage: "shippingbox") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                if store.remoteArtifacts.isEmpty {
                    VQPanel("No Artifacts", systemImage: "shippingbox") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.tr("Artifacts appear here after a real Mac Host run produces files or receives image attachments from iOS."))
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            if store.remoteHost.isPaired {
                                Button(action: store.refreshRemoteHostStatus) {
                                    Label(L10n.tr("Refresh Host"), systemImage: "arrow.clockwise")
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle(radius: 8))
                            }
                        }
                    }
                } else {
                    ForEach(store.remoteArtifacts) { artifact in
                        VQPanel(artifact.title, systemImage: symbol(for: artifact.type)) {
                            VStack(alignment: .leading, spacing: 12) {
                                ZStack {
                                    Rectangle()
                                        .fill(VQTheme.steel.opacity(0.08))
                                    Image(systemName: symbol(for: artifact.type))
                                        .font(.system(size: 44, weight: .light))
                                        .foregroundStyle(VQTheme.accent)
                                }
                                .frame(height: 118)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                KeyValueLine(key: "Type", value: artifact.type.uppercased())
                                KeyValueLine(key: "Source", value: artifact.path)
                                KeyValueLine(key: "Size", value: byteLabel(artifact.bytes))
                                StatusPill(title: "Synced from Host", tint: VQTheme.green)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if store.remoteHost.isEnabled, store.remoteHost.isPaired {
                store.refreshRemoteHostStatus()
            }
        }
    }

    private func symbol(for type: String) -> String {
        switch type.lowercased() {
        case "png", "jpg", "jpeg", "gif":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "html", "htm":
            return "safari"
        case "json":
            return "curlybraces.square"
        case "log", "txt":
            return "doc.text"
        case "md":
            return "text.alignleft"
        default:
            return "shippingbox"
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

struct HistoryView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var toolFilter = "all"
    @State private var projectFilter = "all"
    @State private var searchText = ""
    @State private var dateFilter = ""
    @State private var namedOnly = false
    @State private var sessionNameDraft = ""

    private var displayedSessions: [RemoteHistorySession] {
        namedOnly ? store.remoteHistorySessions.filter { store.hasCustomHistoryTitle($0) } : store.remoteHistorySessions
    }

    var body: some View {
        ScreenScaffold(title: "History", systemImage: "clock.arrow.circlepath") {
            VQPanel("Filters", systemImage: "line.3.horizontal.decrease.circle") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Picker("Tool", selection: $toolFilter) {
                            Text(L10n.tr("All")).tag("all")
                            Text("Claude").tag(RemoteHistoryTool.claude.rawValue)
                            Text("Codex").tag(RemoteHistoryTool.codex.rawValue)
                        }
                        .pickerStyle(.segmented)

                        Button(action: refresh) {
                            Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))

                        Button {
                            store.startNewDirectSession(.codex)
                        } label: {
                            Label(L10n.tr("New Codex"), systemImage: "curlybraces.square")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))

                        Button {
                            store.startNewDirectSession(.claude)
                        } label: {
                            Label(L10n.tr("New Claude"), systemImage: "text.bubble")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                    }

                    HStack(spacing: 10) {
                        Picker("Project", selection: $projectFilter) {
                            Text(L10n.tr("All Projects")).tag("all")
                            ForEach(store.remoteHistoryProjects, id: \.self) { project in
                                Text(project).tag(project)
                            }
                        }
                        .frame(maxWidth: 260)

                        TextField(L10n.tr("Search prompts, tools, output"), text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(refresh)

                        TextField("YYYY-MM-DD", text: $dateFilter)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 132)
                            .onSubmit(refresh)

                        Toggle(L10n.tr("Named only"), isOn: $namedOnly)
                            .toggleStyle(.switch)
                            .font(.caption.weight(.semibold))
                    }

                    if !store.remoteHistoryMessage.isEmpty {
                        Text(store.remoteHistoryMessage)
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                }
            }

            VQPanel("Sessions", systemImage: "tablecells") {
                VStack(alignment: .leading, spacing: 0) {
                    HistoryHeaderRow()
                    EmptyDivider()

                    if store.isLoadingRemoteHistory, store.remoteHistorySessions.isEmpty {
                        ProgressView()
                            .padding(.vertical, 18)
                    } else if displayedSessions.isEmpty {
                        Text(store.remoteHost.isPaired ? L10n.tr("No Claude or Codex sessions matched this filter.") : L10n.tr("Pair with Mac Host to read Claude/Codex history."))
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(displayedSessions) { session in
                            Button {
                                store.loadRemoteHistoryDetail(session)
                                sessionNameDraft = store.historyTitle(for: session)
                            } label: {
                                HistorySessionRow(session: session, displayTitle: store.historyTitle(for: session), isSelected: store.selectedHistorySession?.id == session.id)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    store.continueHistorySession(session)
                                } label: {
                                    Label(L10n.tr("Continue"), systemImage: "arrowshape.turn.up.right")
                                }
                                .tint(.accentColor)
                            }
                            EmptyDivider()
                        }
                    }
                }
            }

            VQPanel("Session Detail", systemImage: "text.bubble") {
                if let session = store.selectedHistorySession {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(store.historyTitle(for: session))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(VQTheme.ink)
                                    .lineLimit(2)
                                Text(session.filePath)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(VQTheme.secondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button {
                                store.continueHistorySession(session)
                            } label: {
                                Label(L10n.tr("Continue"), systemImage: "arrowshape.turn.up.right")
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                            StatusPill(title: "\(store.remoteHistoryTurns.count) \(L10n.tr("turns"))", tint: VQTheme.accent)
                        }

                        HStack(spacing: 8) {
                            TextField(L10n.tr("Session name"), text: $sessionNameDraft)
                                .textFieldStyle(.roundedBorder)
                            Button(L10n.tr("Save Name")) {
                                store.renameHistorySession(session, title: sessionNameDraft)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 8))
                        }
                        .font(.footnote.weight(.semibold))

                        if store.remoteHistoryTurns.isEmpty, store.isLoadingRemoteHistory {
                            ProgressView()
                                .padding(.vertical, 18)
                        } else if store.remoteHistoryTurns.isEmpty {
                            Text(L10n.tr("Select a session to load turns."))
                                .font(.subheadline)
                                .foregroundStyle(VQTheme.secondaryText)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(store.remoteHistoryTurns) { turn in
                                    HistoryTurnView(turn: turn)
                                }
                            }
                        }
                    }
                } else {
                    Text(L10n.tr("Select a Claude or Codex session from the table."))
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
        }
        .onAppear {
            if store.remoteHistorySessions.isEmpty {
                refresh()
            }
            if let session = store.selectedHistorySession {
                sessionNameDraft = store.historyTitle(for: session)
            }
        }
        .onChange(of: store.selectedHistorySession) { _, session in
            sessionNameDraft = session.map(store.historyTitle(for:)) ?? ""
        }
    }

    private func refresh() {
        let tool = RemoteHistoryTool(rawValue: toolFilter)
        store.refreshRemoteHistory(
            tool: tool,
            project: projectFilter == "all" ? nil : projectFilter,
            query: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            date: dateFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private struct HistoryHeaderRow: View {
    var body: some View {
        HStack(spacing: 12) {
            Text(L10n.tr("Tool")).frame(width: 72, alignment: .leading)
            Text(L10n.tr("Project")).frame(width: 140, alignment: .leading)
            Text(L10n.tr("Started")).frame(width: 150, alignment: .leading)
            Text(L10n.tr("Turns")).frame(width: 56, alignment: .trailing)
            Text(L10n.tr("Prompt Summary")).frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(VQTheme.secondaryText)
        .padding(.vertical, 6)
    }
}

private struct HistorySessionRow: View {
    let session: RemoteHistorySession
    let displayTitle: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            StatusPill(title: session.tool.title, tint: session.tool == .claude ? VQTheme.violet : VQTheme.green)
                .frame(width: 72, alignment: .leading)
            Text(session.project)
                .frame(width: 140, alignment: .leading)
                .lineLimit(1)
            Text(session.startedAt.map(Self.dateFormatter.string(from:)) ?? L10n.tr("Unknown"))
                .font(.caption.monospaced())
                .foregroundStyle(VQTheme.secondaryText)
                .frame(width: 150, alignment: .leading)
            Text("\(session.messageCount)")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .frame(width: 56, alignment: .trailing)
            VStack(alignment: .leading, spacing: 3) {
                Text(displayTitle)
                    .font(.subheadline)
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                Text(session.model ?? session.projectPath)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isSelected ? VQTheme.accent.opacity(0.10) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct HistoryTurnView: View {
    let turn: RemoteHistoryTurn
    @State private var expanded = false

    private var isTool: Bool {
        turn.role == "tool" || turn.kind != "message"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                StatusPill(title: turn.role.capitalized, tint: tint)
                Text(turn.timestamp.map(Self.dateFormatter.string(from:)) ?? "")
                    .font(.caption2.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                Spacer()
                if isTool {
                    Button(L10n.tr(expanded ? "Collapse" : "Expand")) {
                        expanded.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.accent)
                }
            }

            Text(displayText)
                .font(isTool ? .caption.monospaced() : .subheadline)
                .foregroundStyle(isTool ? VQTheme.secondaryText : VQTheme.ink)
                .lineLimit(isTool && !expanded ? 4 : nil)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(VQTheme.elevated.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }

    private var displayText: String {
        turn.text.isEmpty ? L10n.tr("(empty)") : turn.text
    }

    private var tint: Color {
        switch turn.role {
        case "user":
            return VQTheme.accent
        case "assistant":
            return VQTheme.green
        default:
            return VQTheme.amber
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}

struct ApprovalsView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScreenScaffold(title: "Approvals", systemImage: "hand.raised") {
            VQPanel("Policy", systemImage: "lock.shield") {
                FlowLayout(items: [L10n.tr("File deletion"), L10n.tr("Billing"), L10n.tr("Production"), L10n.tr("Secrets"), L10n.tr("Screen control")])
            }

            HermesApprovalsSection()

            let pending = store.pendingApprovals()
            if pending.isEmpty {
                VQPanel("Queue", systemImage: "checkmark.shield") {
                    Text(L10n.tr("No pending approvals. Risky commands stop here and run from the Mac build after approval."))
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }

            ForEach(pending) { approval in
                VQPanel(approval.riskLabel, systemImage: approval.symbolName) {
                    CommandApprovalQueueRow(approval: approval)
                }
            }
        }
        .accessibilityIdentifier("gate2.screen.approvals")
    }
}

private struct CommandApprovalQueueRow: View {
    @EnvironmentObject private var store: CommandCenterStore
    let approval: CommandApproval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: approval.symbolName)
                    .frame(width: 28, height: 28)
                    .foregroundStyle(approval.tint)
                    .background(approval.tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(approval.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VQTheme.ink)
                    Text(approval.detail)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ApprovalImpactPreview(
                approval: approval,
                diffs: store.diffEntries(for: approval.runID),
                compact: false,
                includePatch: false
            )

            HStack {
                StatusPill(title: approval.riskLabel, tint: approval.tint)
                Spacer()
                ApprovalActionButtons(approval: approval)
                    .frame(maxWidth: 260)
            }
            .font(.footnote.weight(.semibold))
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("gate2.approval.pending")
    }
}

struct MemoryView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var selectedScope: MemoryScope = .project

    private var selectedRemoteFile: RemoteMemoryFile? {
        guard let selectedRemoteMemoryID = store.selectedRemoteMemoryID else { return nil }
        return store.remoteMemoryFiles.first { $0.id == selectedRemoteMemoryID }
    }

    var body: some View {
        ScreenScaffold(title: "Memory", systemImage: "brain.head.profile") {
            VQPanel("Hermes プロジェクト記憶", systemImage: "sparkles.rectangle.stack") {
                ProjectMemoryReadOnlyView()
            }

            VQPanel("Hermes Memory Files", systemImage: "externaldrive.connected.to.line.below") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        StatusPill(
                            title: store.remoteHost.isEnabled && store.remoteHost.isPaired ? "Mac Host Connected" : "Pair Mac Host",
                            tint: store.remoteHost.isEnabled && store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber
                        )
                        StatusPill(title: "USER.md", tint: VQTheme.accent)
                        StatusPill(title: "MEMORY.md", tint: VQTheme.accent)
                        StatusPill(title: "Skills", tint: VQTheme.secondaryText)
                        Spacer()
                        Button {
                            store.refreshRemoteMemory()
                        } label: {
                            Label(L10n.tr(store.isLoadingRemoteMemory ? "Loading" : "Refresh"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(store.isLoadingRemoteMemory || !(store.remoteHost.isEnabled && store.remoteHost.isPaired))
                    }
                    .font(.footnote.weight(.semibold))

                    if !(store.remoteHost.isEnabled && store.remoteHost.isPaired) {
                        Text(L10n.tr("DevicesでMac HostをQRペアリングすると、Mac上のHermesメモリをここから確認・編集できます。"))
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        RemoteMemoryEditor(selectedFile: selectedRemoteFile)
                    }

                    if !store.remoteMemoryMessage.isEmpty {
                        Text(store.remoteMemoryMessage)
                            .font(.caption)
                            .foregroundStyle(store.remoteMemoryMessage.contains("failed") || store.remoteMemoryMessage.contains("失敗") ? VQTheme.amber : VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VQPanel("Scope", systemImage: "square.stack.3d.up") {
                Picker("Scope", selection: $selectedScope) {
                    ForEach(MemoryScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }

            VQPanel("\(selectedScope.title) Memory", systemImage: "pin") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.tr("Use Hermes Memory Files above to load live USER.md, MEMORY.md, and skills from the paired Mac Host."))
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VQPanel("Context Package", systemImage: "archivebox") {
                FlowLayout(items: ContextPackage.items)
            }
        }
        .onAppear {
            if store.remoteHost.isEnabled, store.remoteHost.isPaired, store.remoteMemoryFiles.isEmpty {
                store.refreshRemoteMemory()
            }
            if store.remoteHost.isEnabled,
               store.remoteHost.isPaired,
               store.remoteProjectMemory?.projectID != store.selectedAgentProject?.id {
                store.refreshRemoteProjectMemory()
            }
        }
        .accessibilityIdentifier("gate2.screen.memory")
    }
}

struct GitHubOpsView: View {
    @EnvironmentObject private var store: CommandCenterStore

    var body: some View {
        ScreenScaffold(title: "GitHub", systemImage: "point.3.connected.trianglepath.dotted") {
            VQPanel("Release Flow", systemImage: "arrow.triangle.branch") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        StatusPill(title: store.remoteHost.isPaired ? "Mac Host" : "Local Snapshot", tint: store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber)
                        StatusPill(title: github.ghAuthenticated ? "gh auth OK" : "gh auth needed", tint: github.ghAuthenticated ? VQTheme.green : VQTheme.amber)
                        Spacer()
                    }

                    GitHubStep(title: "Branch", value: branchLabel, status: branchLabel == "No branch" ? "Missing" : "Ready", tint: branchLabel == "No branch" ? VQTheme.amber : VQTheme.green)
                    GitHubStep(title: "Working Tree", value: workingTreeLabel, status: changedFiles == 0 ? "Clean" : "Dirty", tint: changedFiles == 0 ? VQTheme.green : VQTheme.amber)
                    GitHubStep(title: "Pull Request", value: github.pullRequestURL.isEmpty ? L10n.tr("Not opened") : github.pullRequestURL, status: github.pullRequestState, tint: github.pullRequestURL.isEmpty ? VQTheme.secondaryText : VQTheme.accent)
                    GitHubStep(title: "CI", value: github.checksSummary, status: github.checksSummary.localizedCaseInsensitiveContains("failing") ? "Failing" : "Status", tint: github.checksSummary.localizedCaseInsensitiveContains("failing") ? VQTheme.red : VQTheme.secondaryText)
                    GitHubStep(title: "Deploy", value: L10n.tr("Approval required"), status: "Locked", tint: VQTheme.red)

                    HStack(spacing: 8) {
                        Button(action: store.refreshGitHubStatus) {
                            Label(L10n.tr("Refresh"), systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(!store.remoteHost.isPaired)

                        Button(action: store.createDraftPRFromHost) {
                            Label(L10n.tr("Create Draft PR"), systemImage: "plus.square.on.square")
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.roundedRectangle(radius: 8))
                        .disabled(!store.remoteHost.isPaired || branchLabel == "No branch")
                    }
                    .font(.footnote.weight(.semibold))
                }
            }

            VQPanel("Repository", systemImage: "tray.full") {
                VStack(alignment: .leading, spacing: 12) {
                    KeyValueLine(key: "Remote", value: github.remote.isEmpty ? store.workspace.remoteLabel : github.remote)
                    KeyValueLine(key: "Git root", value: github.gitRoot.isEmpty ? store.workspace.rootPath : github.gitRoot)
                    KeyValueLine(key: "Ahead/behind", value: github.aheadBehind.isEmpty ? L10n.tr("No upstream data") : github.aheadBehind)
                    KeyValueLine(key: "Review mode", value: L10n.tr("Branch + commit + draft PR automatic, merge/deploy approval"))
                    if let error = github.error, !error.isEmpty {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(VQTheme.amber)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !store.remoteHostMessage.isEmpty {
                        Text(store.remoteHostMessage)
                            .font(.caption)
                            .foregroundStyle(store.remoteHostMessage.localizedCaseInsensitiveContains("failed") ? VQTheme.amber : VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .onAppear {
            if store.remoteHost.isEnabled, store.remoteHost.isPaired {
                store.refreshGitHubStatus()
            }
        }
    }

    private var github: RemoteGitHubStatus {
        store.remoteGitHubStatus
    }

    private var branchLabel: String {
        if !github.branch.isEmpty { return github.branch }
        return store.workspace.branchLabel
    }

    private var changedFiles: Int {
        github.gitRoot.isEmpty ? store.workspace.changedFiles : github.changedFiles
    }

    private var workingTreeLabel: String {
            changedFiles == 0 ? L10n.tr("Clean") : "\(changedFiles) \(L10n.tr("changed files"))"
    }
}

private struct PhaseRail: View {
    let current: RunPhase

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(RunPhase.allCases) { phase in
                    VStack(spacing: 6) {
                        Image(systemName: phase == current ? "circle.fill" : "circle")
                            .font(.caption)
                            .foregroundStyle(phase == current ? VQTheme.accent : VQTheme.secondaryText)
                        Text(phase.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            ProgressView(value: Double(RunPhase.allCases.firstIndex(of: current) ?? 0), total: Double(RunPhase.allCases.count - 1))
                .tint(VQTheme.accent)
        }
    }
}

private struct ReviewNote: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(symbol.contains("exclamationmark") ? VQTheme.amber : VQTheme.green)
                .padding(.top, 1)
            Text(L10n.tr(text))
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

private struct RemoteConnectionField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var identifier: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VQTheme.secondaryText)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.footnote)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(VQTheme.control.opacity(0.64))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }
                .accessibilityIdentifier(identifier ?? "")
        }
    }
}

private struct ProjectMemoryReadOnlyView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var memoryQuestion = ""

    private var displayedSnapshot: RemoteProjectMemoryResponse? {
        guard let snapshot = store.remoteProjectMemory else { return nil }
        guard snapshot.projectID == store.selectedAgentProject?.id else { return nil }
        return snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                StatusPill(
                    title: store.remoteHost.isEnabled && store.remoteHost.isPaired ? "Mac Host 接続済み" : "Mac Host 未接続",
                    tint: store.remoteHost.isEnabled && store.remoteHost.isPaired ? VQTheme.green : VQTheme.amber
                )
                StatusPill(title: "読み取り専用", tint: VQTheme.secondaryText)
                if let snapshot = displayedSnapshot {
                    StatusPill(title: "\(snapshot.sessions.count) セッション", tint: snapshot.sessions.isEmpty ? VQTheme.secondaryText : VQTheme.accent)
                }
                if let fetchedAt = store.remoteProjectMemoryLastFetchedAt {
                    StatusPill(title: "最終取得 \(Self.projectMemoryDateFormatter.string(from: fetchedAt))", tint: VQTheme.steel)
                }
                Spacer()
                Button {
                    store.refreshRemoteProjectMemory()
                } label: {
                    Label(store.isLoadingRemoteProjectMemory ? "読み込み中" : "更新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .disabled(store.isLoadingRemoteProjectMemory || !(store.remoteHost.isEnabled && store.remoteHost.isPaired))
                .accessibilityIdentifier("gate2.memory.refreshProject")
            }
            .font(.footnote.weight(.semibold))

            if !(store.remoteHost.isEnabled && store.remoteHost.isPaired) {
                Text("Mac Host とペアリングすると、選択中の Hermes Project が使う native memory とセッションを確認できます。")
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let snapshot = displayedSnapshot {
                snapshotView(snapshot)
                memoryQuestionPanel
            } else {
                Text(store.isLoadingRemoteProjectMemory ? "プロジェクト記憶を読み込み中..." : "更新すると、選択中の Hermes Project の記憶を表示します。")
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                memoryQuestionPanel
            }

            if !store.remoteProjectMemoryMessage.isEmpty {
                Text(store.remoteProjectMemoryMessage)
                    .font(.caption)
                    .foregroundStyle(store.remoteProjectMemoryMessage.contains("失敗") ? VQTheme.amber : VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("gate2.memory.message")
            }
        }
    }

    private static let projectMemoryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private var memoryQuestionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("記憶に聞く", systemImage: "questionmark.bubble")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                StatusPill(title: hermesModelLabel, tint: VQTheme.accent)
            }
            TextField("例: 先週このプロジェクトで何をしていた？", text: $memoryQuestion, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.caption)
                .lineLimit(2...4)
                .padding(10)
                .background(VQTheme.control.opacity(0.50))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }

            HStack(spacing: 8) {
                ForEach(Self.questionExamples, id: \.self) { example in
                    Button(example) {
                        memoryQuestion = example
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 8))
                    .controlSize(.small)
                }
                Spacer()
                Button {
                    let question = memoryQuestion
                    memoryQuestion = ""
                    store.askSelectedProjectMemory(question)
                } label: {
                    Label("Hermes Chat へ送る", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .disabled(memoryQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.selectedAgentProject == nil)
            }
            .font(.caption.weight(.semibold))

            Text("回答は同じ Hermes Project の新しい Chat として実行されます。Project 記憶は読み取り専用表示のまま、保存や継承は Hermes native memory/session に任せます。")
                .font(.caption2)
                .foregroundStyle(VQTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(VQTheme.elevated.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VQTheme.hairline, lineWidth: 1)
        }
    }

    private var hermesModelLabel: String {
        let provider = store.selectedHermesProvider.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = store.selectedHermesModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !provider.isEmpty, !model.isEmpty {
            return "\(provider) / \(model)"
        }
        return model.isEmpty ? "Hermes 既定" : model
    }

    private static let questionExamples = [
        "先週このプロジェクトで何をしていた？",
        "未解決の論点は？",
        "次に触るべきファイルは？"
    ]

    @ViewBuilder
    private func snapshotView(_ snapshot: RemoteProjectMemoryResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.projectName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                    .lineLimit(1)
                Text("Hermes source: \(snapshot.source)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(snapshot.memoryFile.relativePath)
                    .font(.caption2.monospaced())
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
            }

            if snapshot.memoryContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("表示できるプロジェクト記憶はまだありません。Chat で覚えた事実が Hermes native memory に保存されるとここに出ます。")
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    Text(snapshot.memoryContent)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(VQTheme.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .accessibilityIdentifier("gate2.memory.content")
                }
                .frame(minHeight: 160, maxHeight: 280)
                .background(VQTheme.control.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Hermes セッション")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VQTheme.secondaryText)
                if snapshot.sessions.isEmpty {
                    Text("このプロジェクトのセッションはまだありません。")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                } else {
                    ForEach(snapshot.sessions.prefix(8)) { session in
                        ProjectMemorySessionRow(session: session)
                    }
                }
            }

            ForEach(snapshot.warnings, id: \.self) { warning in
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(VQTheme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ProjectMemorySessionRow: View {
    let session: RemoteProjectMemorySession

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(session.endedAt == nil ? VQTheme.green : VQTheme.secondaryText)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.title?.vqNilIfBlank ?? session.id)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(session.messageCount)")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(VQTheme.ink)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(VQTheme.control.opacity(0.38))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var detail: String {
        let date = session.startedAt?.formatted(date: .abbreviated, time: .shortened) ?? "日時不明"
        let model = session.model?.vqNilIfBlank ?? "モデル未記録"
        let usage = "入力 \(session.inputTokens) / 出力 \(session.outputTokens)"
        return "\(date) ・ \(model) ・ \(usage)"
    }
}

private struct RemoteMemoryEditor: View {
    @EnvironmentObject private var store: CommandCenterStore
    let selectedFile: RemoteMemoryFile?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                fileList
                    .frame(width: 230)
                editor
            }

            VStack(alignment: .leading, spacing: 14) {
                fileList
                editor
            }
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.remoteMemoryFiles.isEmpty {
                    Text(L10n.tr("No Hermes memory files loaded."))
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
            } else {
                ForEach(store.remoteMemoryFiles) { file in
                    Button {
                        store.selectRemoteMemory(file)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: file.kind == "skill" ? "hammer" : "doc.text")
                                .foregroundStyle(file.id == store.selectedRemoteMemoryID ? VQTheme.accent : VQTheme.secondaryText)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(file.relativePath)
                                    .font(.caption2)
                                    .foregroundStyle(VQTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(file.id == store.selectedRemoteMemoryID ? VQTheme.accent.opacity(0.12) : VQTheme.control.opacity(0.46))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedFile?.relativePath ?? L10n.tr("Select a file"))
                        .font(.caption.weight(.semibold))
                    if let selectedFile {
                        Text("\(selectedFile.bytes) \(L10n.tr("bytes"))")
                            .font(.caption2)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                }
                Spacer()
                Button {
                    store.previewRemoteMemoryDiff()
                } label: {
                    Label(L10n.tr("Diff"), systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .disabled(selectedFile == nil || store.isLoadingRemoteMemory)

                Button {
                    store.saveRemoteMemory()
                } label: {
                    Label(L10n.tr("Save"), systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 8))
                .disabled(selectedFile == nil || store.isLoadingRemoteMemory)
            }
            .font(.footnote.weight(.semibold))

            TextEditor(text: $store.remoteMemoryContent)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(minHeight: 220)
                .background(VQTheme.control.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }

            if !store.remoteMemoryDiff.isEmpty {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(store.remoteMemoryDiff)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(VQTheme.ink)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                .background(VQTheme.panel.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VQTheme.hairline, lineWidth: 1)
                }
            }
        }
    }
}

private struct GitHubStep: View {
    let title: String
    let value: String
    let status: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr(title))
                    .font(.subheadline.weight(.semibold))
                Text(value)
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
            }
            Spacer()
            StatusPill(title: status, tint: tint)
        }
    }
}

// MARK: - Hermes remote control (model / reasoning / vault approvals)

struct HermesControlView: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var status: HermesControlStatus?
    @State private var modelDraft = ""
    @State private var providerDraft = ""
    @State private var reasoningDraft = "medium"
    @State private var message = ""
    @State private var isWorking = false

    var body: some View {
        ScreenScaffold(title: "Hermes 操作", systemImage: "slider.horizontal.3") {
            VQPanel("現在の設定", systemImage: "cpu") {
                VStack(alignment: .leading, spacing: 8) {
                    if let status {
                        HermesStatusLine(label: "モデル", value: status.model ?? "未設定")
                        HermesStatusLine(label: "プロバイダ", value: status.provider ?? "auto")
                        HermesStatusLine(label: "思考深度", value: status.reasoning ?? "medium")
                        if let note = status.note {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(VQTheme.amber)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text(isWorking ? "読み込み中…" : "Host から未取得です。")
                            .font(.subheadline)
                            .foregroundStyle(VQTheme.secondaryText)
                    }
                    Button {
                        Task { await load() }
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                    .disabled(isWorking)
                    .accessibilityIdentifier("hermes.control.refresh")
                }
            }

            VQPanel("プリセット", systemImage: "square.grid.3x1.below.line.grid.1x2") {
                VStack(alignment: .leading, spacing: 10) {
                    if let presets = status?.presets, !presets.isEmpty {
                        HStack(spacing: 10) {
                            ForEach(presets.prefix(3)) { preset in
                                Button {
                                    Task { await apply(HermesControlUpdate(presetID: preset.id, provider: nil, model: nil, reasoning: nil)) }
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(preset.label)
                                            .font(.subheadline.weight(.semibold))
                                        Text(preset.reasoning)
                                            .font(.caption2)
                                            .foregroundStyle(VQTheme.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isWorking || preset.isPlaceholder)
                                .accessibilityIdentifier("hermes.preset.\(preset.id)")
                            }
                        }
                        if presets.contains(where: \.isPlaceholder) {
                            Text("{{ }} のままのプリセットは vault の 90_Org/presets.md を編集すると有効になります。")
                                .font(.caption)
                                .foregroundStyle(VQTheme.secondaryText)
                        }
                    } else {
                        Text("プリセット未定義。vault の 90_Org/presets.md に | ラベル | モデル | 思考深度 | の表を作るとここに並びます。")
                            .font(.caption)
                            .foregroundStyle(VQTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            VQPanel("手動設定", systemImage: "wrench.and.screwdriver") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("モデル（例: anthropic/claude-opus-4.6）", text: $modelDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("hermes.field.model")
                    TextField("プロバイダ（空欄なら変更しない）", text: $providerDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("hermes.field.provider")
                    Picker("思考深度", selection: $reasoningDraft) {
                        ForEach(CommandCenterStore.hermesReasoningLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("hermes.field.reasoning")
                    Button {
                        Task {
                            await apply(HermesControlUpdate(
                                presetID: nil,
                                provider: providerDraft.trimmingCharacters(in: .whitespaces).isEmpty ? nil : providerDraft.trimmingCharacters(in: .whitespaces),
                                model: modelDraft.trimmingCharacters(in: .whitespaces).isEmpty ? nil : modelDraft.trimmingCharacters(in: .whitespaces),
                                reasoning: reasoningDraft
                            ))
                        }
                    } label: {
                        Label("適用", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isWorking)
                    .accessibilityIdentifier("hermes.control.apply")
                    Text("適用は新しい Hermes セッションから有効。実行中のチャットは /model・/reasoning で切替。")
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HermesApprovalsSection()

            if !message.isEmpty {
                VQPanel("結果", systemImage: "info.circle") {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .task { await load() }
        .accessibilityIdentifier("gate2.screen.hermes")
    }

    @MainActor
    private func load() async {
        guard store.remoteHost.isEnabled else {
            message = "Host 未接続です。Devices からペアリングしてください。"
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            let status = try await store.hermesControlStatus()
            self.status = status
            modelDraft = status.model ?? ""
            providerDraft = status.provider ?? ""
            if let reasoning = status.reasoning, CommandCenterStore.hermesReasoningLevels.contains(reasoning) {
                reasoningDraft = reasoning
            }
        } catch {
            message = "取得失敗: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func apply(_ update: HermesControlUpdate) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await store.updateHermesControl(update)
            status = result.status
            modelDraft = result.status.model ?? modelDraft
            providerDraft = result.status.provider ?? providerDraft
            if let reasoning = result.status.reasoning { reasoningDraft = reasoning }
            message = "\(result.applied.joined(separator: " / "))。\(result.note)"
        } catch {
            message = "適用失敗: \(error.localizedDescription)"
        }
    }
}

private struct HermesStatusLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(VQTheme.secondaryText)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VQTheme.ink)
                .textSelection(.enabled)
        }
    }
}

struct HermesApprovalsSection: View {
    @EnvironmentObject private var store: CommandCenterStore
    @State private var approvals: [HermesApprovalItem] = []
    @State private var message = ""
    @State private var isLoading = false

    var body: some View {
        VQPanel("Hermes 承認（vault）", systemImage: "tray.full") {
            VStack(alignment: .leading, spacing: 12) {
                if !store.remoteHost.isEnabled {
                    Text("Host 未接続のため取得できません。")
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                } else if approvals.isEmpty {
                    Text(isLoading ? "読み込み中…" : "Hermes の承認待ちはありません。playbook / skill / style の差分提案がここに届きます。")
                        .font(.subheadline)
                        .foregroundStyle(VQTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(approvals) { approval in
                    HermesApprovalRow(approval: approval) { decision in
                        Task { await decide(approval, decision: decision) }
                    }
                }

                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(VQTheme.secondaryText)
                }

                if store.remoteHost.isEnabled {
                    Button {
                        Task { await reload() }
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                    .accessibilityIdentifier("hermes.approvals.refresh")
                }
            }
        }
        .task { await reload() }
    }

    @MainActor
    private func reload() async {
        guard store.remoteHost.isEnabled else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            approvals = try await store.hermesApprovals()
            message = ""
        } catch {
            message = "取得失敗: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func decide(_ approval: HermesApprovalItem, decision: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await store.decideHermesApproval(approval, decision: decision)
            approvals.removeAll { $0.id == approval.id }
            message = decision == "approve" ? "承認しました: \(approval.title)" : "却下しました: \(approval.title)"
        } catch {
            message = "操作失敗: \(error.localizedDescription)"
        }
    }
}

private struct HermesApprovalRow: View {
    let approval: HermesApprovalItem
    let decide: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(approval.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VQTheme.ink)
                Spacer()
                if let createdAt = approval.createdAt {
                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(VQTheme.secondaryText)
                }
            }
            if !approval.summary.isEmpty {
                Text(approval.summary)
                    .font(.caption)
                    .foregroundStyle(VQTheme.secondaryText)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("却下", role: .destructive) { decide("reject") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("hermes.approval.reject")
                Button("承認") { decide("approve") }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("hermes.approval.approve")
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}
