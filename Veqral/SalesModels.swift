import Foundation
import SwiftUI

enum SalesLeadStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case new
    case auditReady = "audit_ready"
    case proposalReady = "proposal_ready"
    case contacted
    case won
    case lost
    case doNotContact = "do_not_contact"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .new: "未対応"
        case .auditReady: "監査済み"
        case .proposalReady: "提案準備"
        case .contacted: "連絡済み"
        case .won: "受注"
        case .lost: "失注"
        case .doNotContact: "連絡しない"
        }
    }

    var tint: Color {
        switch self {
        case .new: VQTheme.steel
        case .auditReady: VQTheme.accent
        case .proposalReady: VQTheme.amber
        case .contacted: VQTheme.ink
        case .won: VQTheme.green
        case .lost, .doNotContact: VQTheme.unavailable
        }
    }
}

struct SalesLead: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var businessName: String
    var category: String
    var area: String
    var officialWebsiteURL: String?
    var googleMapsURL: String?
    var googlePlaceID: String?
    var phone: String?
    var email: String?
    var status: SalesLeadStatus
    var notes: String
    var latestAudit: WebsiteAudit?
    var latestRedesignMock: RedesignMock?
    var latestProposal: Proposal?
    var portfolioAssetID: String?
    var hermesHandoffPath: String?
    var outreachLogs: [OutreachLog]
    var createdAt: Date
    var updatedAt: Date

    static func empty() -> SalesLead {
        let now = Date()
        return SalesLead(
            id: UUID().uuidString.lowercased(),
            businessName: "",
            category: "",
            area: "",
            officialWebsiteURL: nil,
            googleMapsURL: nil,
            googlePlaceID: nil,
            phone: nil,
            email: nil,
            status: .new,
            notes: "",
            latestAudit: nil,
            latestRedesignMock: nil,
            latestProposal: nil,
            portfolioAssetID: nil,
            hermesHandoffPath: nil,
            outreachLogs: [],
            createdAt: now,
            updatedAt: now
        )
    }
}

struct WebsiteAudit: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var leadID: String
    var url: String
    var mobileViewport: String
    var score: Int
    var summary: String
    var findings: [WebsiteAuditFinding]
    var businessImpacts: [String]
    var screenshotPath: String
    var lighthouseSummaryPath: String?
    var createdAt: Date
}

struct WebsiteAuditFinding: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var severity: String
    var title: String
    var detail: String
    var recommendation: String
}

struct RedesignMock: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var leadID: String
    var headline: String
    var subheadline: String
    var cta: String
    var htmlPath: String
    var screenshotPath: String
    var notes: String
    var createdAt: Date
    var approvedAt: Date?
}

struct Proposal: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var leadID: String
    var title: String
    var htmlPath: String
    var pdfPath: String?
    var imagePath: String?
    var summary: String
    var pricing: [String]
    var emailDraft: String
    var dmDraft: String
    var phoneScript: String
    var approvalStatus: String
    var createdAt: Date
    var approvedAt: Date?
}

struct OutreachLog: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var channel: String
    var note: String
    var createdAt: Date
}

struct RemoteSalesLeadListResponse: Codable, Sendable {
    var leads: [SalesLead]
}

struct RemoteSalesCSVImportResponse: Codable, Sendable {
    var imported: Int
    var skipped: Int
    var leads: [SalesLead]
}

struct RemoteSalesLeadAsset: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var kind: String
    var path: String
    var createdAt: Date?
}

struct RemoteSalesLeadAssetsResponse: Codable, Sendable {
    var leadID: String
    var assets: [RemoteSalesLeadAsset]
}

struct RemoteSalesPortfolioPromotionResponse: Codable, Sendable {
    var lead: SalesLead
    var asset: PortfolioAsset
}

struct RemoteSalesHermesHandoffResponse: Codable, Sendable {
    var lead: SalesLead
    var notePath: String
    var note: String
}
