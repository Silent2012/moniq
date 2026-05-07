import SwiftUI
import Charts

// MARK: - AppUsageView

struct AppUsageView: View {
    @StateObject private var vm: AppUsageViewModel

    init(tracker: AppUsageTracker) {
        // StateObject wrappedValue is only used on first creation;
        // subsequent parent re-renders (e.g. from dashVM updates) are ignored.
        _vm = StateObject(wrappedValue: AppUsageViewModel(tracker: tracker))
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main list + chart
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Layout.sectionGap) {
                    // Time range picker + productivity score
                    topBar
                        .slideUpOnAppear(delay: 0)

                    // Horizontal bar chart
                    if !vm.summaries.isEmpty {
                        appBarChart
                            .slideUpOnAppear(delay: 0.08)
                    }

                    // App list (no slide animation — prevents flash on background refresh)
                    appList
                }
                .padding(DS.Layout.contentPadding)
            }

            // Detail panel slides in from right
            if let selected = vm.selectedApp {
                AppDetailPanel(summary: selected) {
                    vm.selectApp(nil)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .trailing).combined(with: .opacity)
                ))
                .frame(width: 320)
            }
        }
        .background(DS.Colors.primaryBackground)
        .animation(DS.Animations.spring, value: vm.selectedApp?.id)
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            // Time range segmented control
            TimeRangePicker(selection: $vm.selectedRange)

            Spacer()

            // Productivity score widget (compact)
            ProductivityScoreCompact(score: vm.productivityScore)
        }
    }

    // MARK: - Bar chart

    private var appBarChart: some View {
        GlowingCard(accentColor: DS.Colors.primaryAccent) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("App Usage")
                    .font(DS.Fonts.cardTitle())
                    .foregroundColor(DS.Colors.primaryText)

                Chart(Array(vm.topAppsForChart.enumerated()), id: \.element.id) { idx, summary in
                    BarMark(
                        x: .value("Duration", summary.totalDuration / 3600),
                        y: .value("App", summary.appName)
                    )
                    .foregroundStyle(DS.Colors.chartPalette[idx % DS.Colors.chartPalette.count])
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text(Formatters.durationShort(summary.totalDuration))
                            .font(DS.Fonts.micro())
                            .foregroundColor(DS.Colors.secondaryText)
                            .padding(.leading, 2)
                    }
                }
                .chartXAxis {
                    AxisMarks { val in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(DS.Colors.cardBorder)
                        if let h = val.as(Double.self) {
                            AxisValueLabel {
                                Text(h == 0 ? "0" : String(format: "%.0fh", h))
                                    .font(DS.Fonts.micro()).foregroundStyle(DS.Colors.tertiaryText)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { val in
                        AxisValueLabel {
                            if let name = val.as(String.self) {
                                Text(name).font(DS.Fonts.caption()).foregroundStyle(DS.Colors.secondaryText)
                            }
                        }
                    }
                }
                .chartPlotStyle { $0.background(.clear) }
                .frame(height: CGFloat(vm.topAppsForChart.count) * 30 + 20)
            }
        }
    }

    // MARK: - App list

    private var appList: some View {
        GlowingCard(accentColor: DS.Colors.primaryAccent) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Text("All Apps")
                        .font(DS.Fonts.cardTitle())
                        .foregroundColor(DS.Colors.primaryText)
                    Spacer()
                    Text("\(vm.summaries.count) apps")
                        .font(DS.Fonts.caption())
                        .foregroundColor(DS.Colors.tertiaryText)
                }

                // Use transaction with no animation so skeleton↔list swaps are instant
                // (avoids the visible flash caused by cross-fading skeletons every 2 s)
                if vm.isLoading {
                    ForEach(0..<5, id: \.self) { _ in
                        loadingRow
                    }
                } else if vm.summaries.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(vm.summaries.enumerated()), id: \.element.id) { idx, summary in
                        AppRowItem(
                            summary: summary,
                            index: idx,
                            isSelected: vm.selectedApp?.id == summary.id
                        ) {
                            vm.selectApp(summary)
                        }
                        .animation(nil, value: summary.totalDuration)

                        if idx < vm.summaries.count - 1 {
                            Divider().background(DS.Colors.cardBorder.opacity(0.5))
                        }
                    }
                    .animation(nil, value: vm.summaries.count)
                }
            }
        }
    }

    private var loadingRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            RoundedRectangle(cornerRadius: 8).fill(DS.Colors.cardBorder).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(DS.Colors.cardBorder).frame(width: 120, height: 10)
                RoundedRectangle(cornerRadius: 3).fill(DS.Colors.cardBorder).frame(width: 80, height: 8)
            }
            Spacer()
        }
        .shimmerEffect(isAnimating: true)
        .padding(.vertical, DS.Spacing.xs)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 48))
                .foregroundColor(DS.Colors.cardBorder)

            Text("No app usage data yet")
                .font(DS.Fonts.cardTitle())
                .foregroundColor(DS.Colors.secondaryText)

            Text("Use your Mac and moniq will track which apps you spend time in.")
                .font(DS.Fonts.caption())
                .foregroundColor(DS.Colors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xxl)
    }
}

// MARK: - TimeRangePicker

struct TimeRangePicker: View {
    @Binding var selection: TimeRange
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 2) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(DS.Animations.spring) { selection = range }
                } label: {
                    Text(range.rawValue)
                        .font(DS.Fonts.caption())
                        .foregroundColor(selection == range ? DS.Colors.primaryText : DS.Colors.secondaryText)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 5)
                        .background(
                            Group {
                                if selection == range {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(DS.Colors.primaryAccent.opacity(0.2))
                                        .matchedGeometryEffect(id: "picker", in: animation)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(DS.Colors.cardBorder.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DS.Colors.cardBorder, lineWidth: 0.5))
    }
}

// MARK: - ProductivityScoreCompact

private struct ProductivityScoreCompact: View {
    let score: Double

    private var scoreColor: Color {
        if score > 70 { return DS.Colors.successGreen }
        if score > 40 { return DS.Colors.warningAmber }
        return DS.Colors.dangerRed
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            AnimatedRing(value: score / 100, color: scoreColor, lineWidth: 4, size: 36, glowEnabled: false) {
                Text(String(format: "%.0f", score))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("Productivity")
                    .font(DS.Fonts.micro())
                    .foregroundColor(DS.Colors.tertiaryText)
                Text(scoreLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(scoreColor)
            }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(RoundedRectangle(cornerRadius: 10).fill(DS.Colors.secondaryBackground))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DS.Colors.cardBorder, lineWidth: 0.5))
    }

    private var scoreLabel: String {
        if score > 70 { return "High" }
        if score > 40 { return "Medium" }
        return "Low"
    }
}

// MARK: - Preview

#Preview {
    AppUsageView(tracker: AppUsageTracker())
        .frame(width: 900, height: 700)
}
