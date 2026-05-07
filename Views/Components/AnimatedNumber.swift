import SwiftUI

// MARK: - Number format types

enum NumberFormat {
    case percent(decimals: Int = 0)
    case gigabytes(decimals: Int = 1)
    case megabytes(decimals: Int = 0)
    case megabitsPerSec(decimals: Int = 1)
    case integer
    case custom(format: String)

    func string(for value: Double) -> String {
        switch self {
        case .percent(let d):       return String(format: "%.\(d)f%%", value)
        case .gigabytes(let d):     return String(format: "%.\(d)f GB", value)
        case .megabytes(let d):     return String(format: "%.\(d)f MB", value)
        case .megabitsPerSec(let d):return String(format: "%.\(d)f Mbps", value)
        case .integer:              return String(Int(value.rounded()))
        case .custom(let f):        return String(format: f, value)
        }
    }
}

// MARK: - AnimatedNumber

struct AnimatedNumber: View {
    let value: Double
    var format: NumberFormat      = .percent()
    var font: Font                = DS.Fonts.heroNumber()
    var color: Color              = DS.Colors.primaryText
    var useGradient: Bool         = false

    @State private var displayValue: Double = 0

    var body: some View {
        let text = Text(format.string(for: displayValue))
            .font(font)
            .monospacedDigit()

        if useGradient {
            text.gradientForeground(DS.Gradients.heroText)
        } else {
            text.foregroundColor(color)
        }
    }

    // We animate via onChange — the actual animation is spring-based
    // SwiftUI's animatable data would require custom conformance; we
    // use a Timer approach via .animation on the wrapped state
}

// MARK: - Cleaner animated number using animatableData

struct SmoothNumber: View, Animatable {
    var value: Double
    var format: NumberFormat    = .percent()
    var font: Font              = DS.Fonts.heroNumber()
    var color: Color            = DS.Colors.primaryText

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(format.string(for: value))
            .font(font)
            .monospacedDigit()
            .foregroundColor(color)
    }
}

// MARK: - Gradient Animated Number (for hero cards)

struct HeroNumber: View {
    let value: Double
    var format: NumberFormat = .percent()
    var useGradient: Bool    = true
    var color: Color         = DS.Colors.primaryText

    @State private var animated: Double = 0

    var body: some View {
        Group {
            if useGradient {
                Text(format.string(for: animated))
                    .font(DS.Fonts.heroNumber())
                    .monospacedDigit()
                    .gradientForeground(DS.Gradients.heroText)
            } else {
                Text(format.string(for: animated))
                    .font(DS.Fonts.heroNumber())
                    .monospacedDigit()
                    .foregroundColor(color)
            }
        }
        .onAppear {
            withAnimation(DS.Animations.dataUpdate) { animated = value }
        }
        .onChange(of: value) { newVal in
            withAnimation(DS.Animations.dataUpdate) { animated = newVal }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HeroNumber(value: 47.3, format: .percent(decimals: 1))
        HeroNumber(value: 11.2, format: .gigabytes(), useGradient: false, color: DS.Colors.pinkAccent)
        HeroNumber(value: 156.4, format: .megabitsPerSec(), useGradient: false, color: DS.Colors.successGreen)
    }
    .padding()
    .background(DS.Colors.primaryBackground)
}
