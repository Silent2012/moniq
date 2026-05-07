import SwiftUI

// MARK: - SidebarView

struct SidebarView: View {
    @Binding var selection: NavItem
    @Binding var sidebarVisible: Bool
    @ObservedObject var vm: DashboardViewModel
    @EnvironmentObject var theme: AppTheme

    @State private var hoveredItem: NavItem?

    private let topItems: [NavItem]    = [.dashboard, .cpu, .appUsage, .network, .battery, .analytics]
    private let bottomItems: [NavItem] = [.settings, .alerts]

    var body: some View {
        VStack(spacing: 0) {
            // App logo
            logoHeader

            Divider()
                .background(DS.Colors.cardBorder)
                .padding(.horizontal, DS.Spacing.md)

            // Top nav
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(topItems) { item in
                        NavRow(
                            item: item,
                            isSelected: selection == item,
                            isHovered: hoveredItem == item
                        ) {
                            withAnimation(DS.Animations.spring) { selection = item }
                        }
                        .onHover { h in hoveredItem = h ? item : nil }
                    }
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.top, DS.Spacing.md)
            }

            Spacer()

            // Bottom nav
            Divider()
                .background(DS.Colors.cardBorder)
                .padding(.horizontal, DS.Spacing.md)

            VStack(spacing: DS.Spacing.xs) {
                ForEach(bottomItems) { item in
                    NavRow(
                        item: item,
                        isSelected: selection == item,
                        isHovered: hoveredItem == item
                    ) {
                        withAnimation(DS.Animations.spring) { selection = item }
                    }
                    .onHover { h in hoveredItem = h ? item : nil }
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm)

            Divider()
                .background(DS.Colors.cardBorder)
                .padding(.horizontal, DS.Spacing.md)

            // System mini stats footer
            systemFooter
        }
        .frame(width: DS.Layout.sidebarWidth)
        .background(DS.Colors.primaryBackground)
    }

    // MARK: - Logo header
    private var logoHeader: some View {
        HStack(spacing: 0) {
            // Traffic-light clearance — macOS overlays ~72 pt of buttons here
            Color.clear.frame(width: 72)

            Text("moniq")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .gradientForeground(theme.heroGradient)
                .glowEffect(color: theme.primaryAccent, radius: 12, opacity: 0.25)

            Spacer()

            // Collapse button — lives inside sidebar so it moves with it
            Button {
                withAnimation(DS.Animations.spring) { sidebarVisible = false }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DS.Colors.tertiaryText)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(DS.Colors.cardBorder.opacity(0.35)))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Hide sidebar")
        }
        .padding(.trailing, DS.Spacing.md)
        .frame(height: DS.Layout.titleBarHeight)
    }

    // MARK: - Footer mini stats
    private var systemFooter: some View {
        VStack(spacing: DS.Spacing.sm) {
            // CPU mini row
            MiniStatRow(
                icon: "cpu",
                label: "CPU",
                value: String(format: "%.0f%%", vm.cpuData.usage),
                color: DS.Colors.secondaryAccent,
                sparkData: vm.cpuHistory
            )
            MiniStatRow(
                icon: "memorychip",
                label: "RAM",
                value: String(format: "%.0f%%", vm.memoryData.usagePercent),
                color: DS.Colors.pinkAccent,
                sparkData: vm.memHistory
            )

            HStack {
                LiveBadge()
                Spacer()
                Text("v\(AppConstants.appVersion)")
                    .font(DS.Fonts.micro())
                    .foregroundColor(DS.Colors.tertiaryText)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.md)
    }
}

// MARK: - NavRow

private struct NavRow: View {
    let item: NavItem
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void

    var accentColor: Color { Color(hex: item.accentColor) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                // Left accent bar
                Rectangle()
                    .fill(isSelected ? accentColor : Color.clear)
                    .frame(width: 3)
                    .cornerRadius(2)

                // Icon
                ZStack {
                    if isSelected || isHovered {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 30, height: 30)
                            .blur(radius: isSelected ? 4 : 0)
                    }
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isSelected ? accentColor : DS.Colors.secondaryText)
                        .frame(width: 18)
                }
                .frame(width: 30)

                Text(item.rawValue)
                    .font(DS.Fonts.metricLabel())
                    .foregroundColor(isSelected ? DS.Colors.primaryText : DS.Colors.secondaryText)

                Spacer()
            }
            .frame(height: 38)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DS.Gradients.sidebarSelection(color: accentColor))
                    } else if isHovered {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DS.Colors.hoverState)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .animation(DS.Animations.spring, value: isSelected)
        .animation(DS.Animations.spring, value: isHovered)
    }
}

// MARK: - MiniStatRow (footer)

private struct MiniStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    let sparkData: [Double]

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(color)
                .frame(width: 12)

            Text(label)
                .font(DS.Fonts.micro())
                .foregroundColor(DS.Colors.tertiaryText)

            Spacer()

            SparklineView(data: sparkData, color: color, height: 16, showDot: false, showFill: false)
                .frame(width: 50)

            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .frame(width: 34, alignment: .trailing)
                .monospacedDigit()
        }
    }
}

// MARK: - Preview

#Preview {
    SidebarView(selection: .constant(.dashboard), sidebarVisible: .constant(true), vm: DashboardViewModel())
        .frame(height: 700)
        .background(DS.Colors.primaryBackground)
}
