import SwiftUI

// MARK: - Design System

enum DS {

    // MARK: - Colors
    enum Colors {
        static let primaryBackground   = Color(hex: "#0A0A0F")
        static let secondaryBackground = Color(hex: "#111118")
        static let tertiaryBackground  = Color(hex: "#1A1A24")
        static let cardBorder          = Color(hex: "#2A2A3A")
        static let hoverState          = Color(hex: "#1E1E2E")

        static let primaryAccent   = Color(hex: "#6C63FF")
        static let secondaryAccent = Color(hex: "#00D4FF")
        static let successGreen    = Color(hex: "#00FF88")
        static let warningAmber    = Color(hex: "#FFB830")
        static let dangerRed       = Color(hex: "#FF4757")
        static let pinkAccent      = Color(hex: "#FF6B9D")

        static let primaryText   = Color.white
        static let secondaryText = Color(hex: "#8B8BA7")
        static let tertiaryText  = Color(hex: "#4A4A6A")
        static let accentText    = Color(hex: "#6C63FF")

        static let chartPalette: [Color] = [
            Color(hex: "#6C63FF"), Color(hex: "#00D4FF"), Color(hex: "#00FF88"),
            Color(hex: "#FFB830"), Color(hex: "#FF6B9D"), Color(hex: "#FF4757"),
            Color(hex: "#A78BFA"), Color(hex: "#34D399"), Color(hex: "#FB923C"),
            Color(hex: "#38BDF8")
        ]

        static func forCPU(_ value: Double) -> Color {
            if value > 80 { return dangerRed }
            if value > 50 { return warningAmber }
            return secondaryAccent
        }

        static func forBattery(_ value: Double) -> Color {
            if value > 50 { return successGreen }
            if value > 20 { return warningAmber }
            return dangerRed
        }

        static func forHealth(_ pct: Double) -> Color {
            if pct >= 80 { return successGreen }
            if pct >= 60 { return warningAmber }
            return dangerRed
        }
    }

    // MARK: - Fonts
    enum Fonts {
        static func heroNumber()    -> Font { .system(size: 48, weight: .bold,    design: .rounded) }
        static func largeNumber()   -> Font { .system(size: 36, weight: .bold,    design: .rounded) }
        static func mediumNumber()  -> Font { .system(size: 26, weight: .bold,    design: .rounded) }
        static func smallNumber()   -> Font { .system(size: 20, weight: .bold,    design: .rounded) }
        static func sectionTitle()  -> Font { .system(size: 22, weight: .semibold) }
        static func cardTitle()     -> Font { .system(size: 15, weight: .semibold) }
        static func metricLabel()   -> Font { .system(size: 13, weight: .medium)  }
        static func body()          -> Font { .system(size: 13, weight: .regular) }
        static func caption()       -> Font { .system(size: 11, weight: .regular) }
        static func micro()         -> Font { .system(size: 10, weight: .medium)  }
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Layout
    enum Layout {
        static let sidebarWidth:       CGFloat = 220
        static let contentPadding:     CGFloat = 24
        static let cardGap:            CGFloat = 16
        static let sectionGap:         CGFloat = 32
        static let cardCornerRadius:   CGFloat = 16
        static let cardPadding:        CGFloat = 20
        static let titleBarHeight:     CGFloat = 52
        static let minWindowWidth:     CGFloat = 900
        static let minWindowHeight:    CGFloat = 600
        static let defaultWindowWidth: CGFloat = 1200
        static let defaultWindowHeight:CGFloat = 760
    }

    // MARK: - Gradients
    enum Gradients {
        static let heroText = LinearGradient(
            colors: [Color(hex: "#6C63FF"), Color(hex: "#00D4FF")],
            startPoint: .leading, endPoint: .trailing
        )
        static let purpleToClear = LinearGradient(
            colors: [Color(hex: "#6C63FF").opacity(0.35), .clear],
            startPoint: .top, endPoint: .bottom
        )
        static let cyanToClear = LinearGradient(
            colors: [Color(hex: "#00D4FF").opacity(0.3), .clear],
            startPoint: .top, endPoint: .bottom
        )
        static let greenToClear = LinearGradient(
            colors: [Color(hex: "#00FF88").opacity(0.25), .clear],
            startPoint: .top, endPoint: .bottom
        )

        static func chartFill(color: Color) -> LinearGradient {
            LinearGradient(
                colors: [color.opacity(0.35), color.opacity(0.02)],
                startPoint: .top, endPoint: .bottom
            )
        }

        static func sidebarSelection(color: Color) -> LinearGradient {
            LinearGradient(
                colors: [color.opacity(0.18), color.opacity(0.08)],
                startPoint: .leading, endPoint: .trailing
            )
        }
    }

    // MARK: - Animations
    enum Animations {
        static let spring          = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let dataUpdate      = Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let chartUpdate     = Animation.easeInOut(duration: 0.6)
        static let navCrossfade    = Animation.easeInOut(duration: 0.25)
        static let staggerBase     = Animation.spring(response: 0.5, dampingFraction: 0.75)
        static let pulse           = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: false)
        static let breathe         = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)

        static func stagger(index: Int) -> Animation {
            staggerBase.delay(Double(index) * 0.08)
        }
    }

    // MARK: - Shadow helpers
    static func glowShadow(color: Color, intensity: Double = 1.0) -> some ViewModifier {
        GlowShadowModifier(color: color, intensity: intensity)
    }
}

// MARK: - GlowShadowModifier
private struct GlowShadowModifier: ViewModifier {
    let color: Color
    let intensity: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.3 * intensity), radius: 20 * intensity, x: 0, y: 0)
            .shadow(color: color.opacity(0.15 * intensity), radius: 40 * intensity, x: 0, y: 0)
    }
}
