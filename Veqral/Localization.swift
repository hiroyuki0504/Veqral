import Foundation

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system
    case japanese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            L10n.tr("System")
        case .japanese:
            "日本語"
        case .english:
            "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            Locale.autoupdatingCurrent
        case .japanese:
            Locale(identifier: "ja")
        case .english:
            Locale(identifier: "en")
        }
    }

    var bundleLanguageCode: String {
        switch self {
        case .system:
            "ja"
        case .japanese:
            "ja"
        case .english:
            "en"
        }
    }
}

enum L10n {
    static func tr(_ key: String) -> String {
        let language = UserDefaults.standard.string(forKey: "appLanguage").flatMap(AppLanguage.init(rawValue:)) ?? .system
        guard let path = Bundle.main.path(forResource: language.bundleLanguageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
