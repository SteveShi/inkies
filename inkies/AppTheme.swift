import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"

    var id: String { self.rawValue }

    var localizedName: String {
        switch self {
        case .light: return String(localized: "Light Mode")
        case .dark: return String(localized: "Dark Mode")
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark: return .dark
        }
    }
}
