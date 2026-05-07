import SwiftUI
import AppKit

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >>  8) & 0xFF) / 255
            b = Double( int        & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >>  8) & 0xFF) / 255
            a = Double( int        & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - View Extensions
extension View {
    func gradientForeground(_ gradient: LinearGradient) -> some View {
        self.overlay(gradient).mask(self)
    }

    func glowEffect(color: Color, radius: CGFloat = 20, opacity: Double = 0.3) -> some View {
        self
            .shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(opacity * 0.5), radius: radius * 1.5, x: 0, y: 4)
    }

    func cardStyle(accentColor: Color = DS.Colors.primaryAccent, isHovered: Bool = false) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: DS.Layout.cardCornerRadius)
                    .fill(isHovered ? DS.Colors.hoverState : DS.Colors.secondaryBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Layout.cardCornerRadius)
                    .strokeBorder(
                        isHovered ? accentColor.opacity(0.4) : DS.Colors.cardBorder,
                        lineWidth: 1
                    )
            )
            .shadow(
                color: accentColor.opacity(isHovered ? 0.25 : 0.12),
                radius: isHovered ? 30 : 20,
                x: 0, y: isHovered ? 12 : 8
            )
    }

    func shimmerEffect(isAnimating: Bool) -> some View {
        self.modifier(ShimmerModifier(isAnimating: isAnimating))
    }

    func slideUpOnAppear(delay: Double = 0) -> some View {
        self.modifier(SlideUpOnAppearModifier(delay: delay))
    }

    func moniqSection(title: String, trailing: AnyView? = nil) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(title)
                    .font(DS.Fonts.sectionTitle())
                    .foregroundColor(DS.Colors.primaryText)
                Spacer()
                trailing
            }
            self
        }
    }
}

// MARK: - ShimmerModifier
struct ShimmerModifier: ViewModifier {
    let isAnimating: Bool
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .redacted(reason: isAnimating ? .placeholder : [])
            .overlay(
                Group {
                    if isAnimating {
                        GeometryReader { geo in
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geo.size.width * 0.6)
                            .offset(x: phase * geo.size.width * 1.5)
                            .onAppear {
                                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                    phase = 1.4
                                }
                            }
                        }
                        .clipped()
                    }
                }
            )
    }
}

// MARK: - SlideUpOnAppearModifier
struct SlideUpOnAppearModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .onAppear {
                withAnimation(DS.Animations.staggerBase.delay(delay)) {
                    appeared = true
                }
            }
    }
}

// MARK: - Double Extensions
extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }

    var asPercentString: String { String(format: "%.1f%%", self) }
    var asIntPercentString: String { String(format: "%d%%", Int(self)) }
}

// MARK: - Date Extensions
extension Date {
    var timeAgoString: String {
        let interval = -timeIntervalSinceNow
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }

    var hourInt: Int { Calendar.current.component(.hour, from: self) }
    var weekdayInt: Int { Calendar.current.component(.weekday, from: self) }
}

// MARK: - Array Extensions
extension Array where Element == Double {
    var normalized: [Double] {
        guard let max = self.max(), max > 0 else { return self.map { _ in 0 } }
        return self.map { $0 / max }
    }

    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

// MARK: - NSImage convenience
extension NSImage {
    static func appIcon(for bundleID: String) -> NSImage? {
        NSWorkspace.shared.icon(forFile: NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path ?? "")
    }
}
