import SwiftUI
import UIKit

enum VQTheme {
    static let canvas = adaptive(light: ui(0.940, 0.946, 0.944), dark: ui(0.018, 0.026, 0.029))
    static let sidebar = adaptive(light: ui(0.920, 0.928, 0.928), dark: ui(0.022, 0.031, 0.035))
    static let elevated = adaptive(light: ui(0.988, 0.990, 0.986), dark: ui(0.050, 0.063, 0.068))
    static let panel = adaptive(light: ui(0.976, 0.980, 0.976), dark: ui(0.066, 0.080, 0.086))
    static let control = adaptive(light: ui(0.904, 0.914, 0.912), dark: ui(0.112, 0.129, 0.137))
    static let terminal = adaptive(light: ui(0.980, 0.984, 0.980), dark: ui(0.015, 0.030, 0.034))
    static let ink = adaptive(light: ui(0.060, 0.070, 0.076), dark: ui(0.930, 0.955, 0.952))
    static let secondaryText = adaptive(light: ui(0.390, 0.416, 0.430), dark: ui(0.620, 0.665, 0.672))
    static let mutedText = adaptive(light: ui(0.530, 0.552, 0.560), dark: ui(0.425, 0.474, 0.486))
    static let hairline = adaptive(light: ui(0.780, 0.798, 0.794), dark: ui(0.176, 0.216, 0.226))
    static let accent = Color(red: 0.165, green: 0.875, blue: 0.855)
    static let green = Color(red: 0.430, green: 0.830, blue: 0.365)
    static let amber = Color(red: 0.980, green: 0.660, blue: 0.150)
    static let red = Color(red: 0.980, green: 0.315, blue: 0.275)
    static let violet = Color(red: 0.620, green: 0.470, blue: 0.980)
    static let steel = adaptive(light: ui(0.218, 0.258, 0.276), dark: ui(0.720, 0.770, 0.775))
    static let glow = Color(red: 0.110, green: 0.760, blue: 0.735)

    private static func ui(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

enum AppearanceMode: String {
    case dark
    case light

    var colorScheme: ColorScheme {
        switch self {
        case .dark: .dark
        case .light: .light
        }
    }

    var toggleTitle: String {
        switch self {
        case .dark: "White mode"
        case .light: "Dark mode"
        }
    }

    var toggleSymbol: String {
        switch self {
        case .dark: "sun.max"
        case .light: "moon"
        }
    }
}

struct PanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    VQTheme.panel
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.060),
                            Color.white.opacity(0.018),
                            Color.black.opacity(0.080)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VQTheme.hairline.opacity(0.92), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.20), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func panelBackground() -> some View {
        modifier(PanelBackground())
    }
}
