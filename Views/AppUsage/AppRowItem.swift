import SwiftUI

// MARK: - AppRowItem

struct AppRowItem: View {
    let summary: AppUsageSummary
    let index: Int
    let isSelected: Bool
    let action: () -> Void

    @State private var appeared = false

    private var rowColor: Color { DS.Colors.chartPalette[index % DS.Colors.chartPalette.count] }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                // App icon
                appIcon

                // Name + category + sparkline
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(summary.appName)
                            .font(DS.Fonts.metricLabel())
                            .fontWeight(.semibold)
                            .foregroundColor(DS.Colors.primaryText)
                            .lineLimit(1)

                        CategoryBadge(category: summary.category)
                    }

                    HStack(spacing: DS.Spacing.sm) {
                        Text(Formatters.durationShort(summary.totalDuration))
                            .font(DS.Fonts.caption())
                            .foregroundColor(rowColor)

                        Text("·")
                            .foregroundColor(DS.Colors.tertiaryText)

                        Text(String(format: "%.0f%%", summary.percentOfTotal))
                            .font(DS.Fonts.caption())
                            .foregroundColor(DS.Colors.secondaryText)

                        Text("·")
                            .foregroundColor(DS.Colors.tertiaryText)

                        Text("\(summary.sessionCount) sessions")
                            .font(DS.Fonts.caption())
                            .foregroundColor(DS.Colors.tertiaryText)
                    }
                }

                Spacer()

                // Sparkline
                SparklineView(
                    data: summary.sparklineData,
                    color: rowColor,
                    height: 24,
                    showDot: false
                )
                .frame(width: 60)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? DS.Colors.primaryAccent : DS.Colors.tertiaryText)
                    .rotationEffect(.degrees(isSelected ? 90 : 0))
                    .animation(DS.Animations.spring, value: isSelected)
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? DS.Colors.primaryAccent.opacity(0.08) : Color.clear)
            )
            .overlay(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(DS.Colors.primaryAccent.opacity(0.2), lineWidth: 0.5)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -12)
        .animation(DS.Animations.stagger(index: index), value: appeared)
        .onAppear { appeared = true }
    }

    private var appIcon: some View {
        ZStack {
            if let icon = summary.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .shadow(color: rowColor.opacity(0.2), radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 9)
                    .fill(rowColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(summary.appName.prefix(1)))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(rowColor)
                    )
            }
        }
    }
}
