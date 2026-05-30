import SwiftUI
import UIKit

enum VQTheme {
    static let canvas = adaptive(light: ui(0.945, 0.950, 0.948), dark: ui(0.028, 0.044, 0.048))
    static let sidebar = adaptive(light: ui(0.925, 0.932, 0.934), dark: ui(0.035, 0.046, 0.050))
    static let elevated = adaptive(light: ui(0.988, 0.990, 0.986), dark: ui(0.066, 0.082, 0.088))
    static let panel = adaptive(light: ui(0.976, 0.980, 0.976), dark: ui(0.082, 0.098, 0.104))
    static let control = adaptive(light: ui(0.910, 0.918, 0.916), dark: ui(0.120, 0.136, 0.144))
    static let ink = adaptive(light: ui(0.065, 0.074, 0.080), dark: ui(0.930, 0.952, 0.948))
    static let secondaryText = adaptive(light: ui(0.405, 0.428, 0.440), dark: ui(0.610, 0.658, 0.666))
    static let mutedText = adaptive(light: ui(0.540, 0.558, 0.566), dark: ui(0.420, 0.470, 0.482))
    static let hairline = adaptive(light: ui(0.790, 0.805, 0.800), dark: ui(0.170, 0.205, 0.214))
    static let accent = Color(red: 0.185, green: 0.850, blue: 0.835)
    static let green = Color(red: 0.390, green: 0.780, blue: 0.345)
    static let amber = Color(red: 0.965, green: 0.655, blue: 0.180)
    static let red = Color(red: 0.950, green: 0.300, blue: 0.260)
    static let violet = Color(red: 0.590, green: 0.435, blue: 0.960)
    static let steel = adaptive(light: ui(0.220, 0.260, 0.278), dark: ui(0.720, 0.760, 0.770))

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
            .background(VQTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(VQTheme.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}

extension View {
    func panelBackground() -> some View {
        modifier(PanelBackground())
    }
}
