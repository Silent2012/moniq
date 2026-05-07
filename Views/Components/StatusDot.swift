import SwiftUI

// MARK: - StatusDot

struct StatusDot: View {
    enum Status {
        case live, good, warning, danger, offline
        var color: Color {
            switch self {
            case .live:    return DS.Colors.successGreen
            case .good:    return DS.Colors.successGreen
            case .warning: return DS.Colors.warningAmber
            case .danger:  return DS.Colors.dangerRed
            case .offline: return DS.Colors.secondaryText
            }
        }
    }

    let status: Status
    var label: String?
    var size: CGFloat = 8
    var showPulse: Bool = true

    @State private var pulsing = false

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ZStack {
                if showPulse && (status == .live || status == .good) {
                    Circle()
                        .fill(status.color.opacity(0.4))
                        .frame(width: size * 2.2, height: size * 2.2)
                        .scaleEffect(pulsing ? 1.0 : 0.5)
                        .opacity(pulsing ? 0 : 0.6)
                        .animation(DS.Animations.pulse, value: pulsing)
                }

                Circle()
                    .fill(status.color)
                    .frame(width: size, height: size)
                    .shadow(color: status.color.opacity(0.6), radius: 4)
            }

            if let label {
                Text(label)
                    .font(DS.Fonts.micro())
                    .foregroundColor(DS.Colors.secondaryText)
            }
        }
        .onAppear { pulsing = true }
    }
}

// MARK: - MetricBadge

struct MetricBadge: View {
    let value: String
    let label: String
    var color: Color     = DS.Colors.primaryAccent
    var trend: Trend?    = nil

    enum Trend { case up, down, neutral }

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let trend {
                Image(systemName: trendIcon(trend))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(trendColor(trend))
            }
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(DS.Fonts.micro())
                .foregroundColor(DS.Colors.secondaryText)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(color.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.5)
        )
    }

    private func trendIcon(_ trend: Trend) -> String {
        switch trend {
        case .up:      return "arrow.up"
        case .down:    return "arrow.down"
        case .neutral: return "minus"
        }
    }

    private func trendColor(_ trend: Trend) -> Color {
        switch trend {
        case .up:      return DS.Colors.dangerRed
        case .down:    return DS.Colors.successGreen
        case .neutral: return DS.Colors.secondaryText
        }
    }
}

// MARK: - CategoryBadge

struct CategoryBadge: View {
    let category: AppConstants.AppCategory

    var body: some View {
        Text(category.rawValue)
            .font(DS.Fonts.micro())
            .foregroundColor(Color(hex: category.color))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(Color(hex: category.color).opacity(0.15))
            )
            .overlay(
                Capsule().strokeBorder(Color(hex: category.color).opacity(0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Live badge (sidebar)

struct LiveBadge: View {
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(DS.Colors.successGreen)
                .frame(width: 6, height: 6)
                .overlay(
                    Circle()
                        .stroke(DS.Colors.successGreen.opacity(0.4), lineWidth: 1)
                        .scaleEffect(pulsing ? 2.2 : 1.0)
                        .opacity(pulsing ? 0 : 1)
                )
                .shadow(color: DS.Colors.successGreen.opacity(0.6), radius: 3)

            Text("LIVE")
                .font(DS.Fonts.micro())
                .fontWeight(.bold)
                .foregroundColor(DS.Colors.successGreen)
                .tracking(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(DS.Colors.successGreen.opacity(0.1))
        )
        .overlay(
            Capsule().strokeBorder(DS.Colors.successGreen.opacity(0.25), lineWidth: 0.5)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            StatusDot(status: .live, label: "Live")
            StatusDot(status: .warning, label: "Warning")
            StatusDot(status: .danger, label: "Critical")
        }
        HStack(spacing: 8) {
            MetricBadge(value: "47%", label: "CPU", color: DS.Colors.secondaryAccent)
            MetricBadge(value: "8.2 GB", label: "RAM", color: DS.Colors.pinkAccent, trend: .up)
            MetricBadge(value: "12 MB/s", label: "DL", color: DS.Colors.successGreen, trend: .down)
        }
        LiveBadge()
        CategoryBadge(category: .productivity)
        CategoryBadge(category: .development)
    }
    .padding()
    .background(DS.Colors.primaryBackground)
}
