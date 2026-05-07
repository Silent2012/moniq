import SwiftUI

// MARK: - AppTheme
// Single source of truth for the user-selected accent colour.
// Injected as @EnvironmentObject from moniqApp so every view
// can observe it and re-render when the user changes the theme.

@MainActor
final class AppTheme: ObservableObject {

    static let palette: [(name: String, hex: String)] = [
        ("Purple", "#6C63FF"),
        ("Cyan",   "#00D4FF"),
        ("Green",  "#00FF88"),
        ("Pink",   "#FF6B9D"),
        ("Amber",  "#FFB830"),
        ("Red",    "#FF4757"),
    ]

    @Published private(set) var primaryAccent: Color
    @Published private(set) var accentIndex: Int

    init() {
        let saved = UserDefaults.standard.integer(forKey: DefaultsKey.accentColorIndex)
        let idx   = min(saved, Self.palette.count - 1)
        accentIndex   = idx
        primaryAccent = Color(hex: Self.palette[idx].hex)
    }

    func set(index: Int) {
        let idx   = min(max(index, 0), Self.palette.count - 1)
        accentIndex   = idx
        primaryAccent = Color(hex: Self.palette[idx].hex)
        UserDefaults.standard.set(idx, forKey: DefaultsKey.accentColorIndex)
    }

    var heroGradient: LinearGradient {
        LinearGradient(
            colors: [primaryAccent, DS.Colors.secondaryAccent],
            startPoint: .leading, endPoint: .trailing
        )
    }
}
