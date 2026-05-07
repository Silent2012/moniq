import SwiftUI
import Charts

// MARK: - AppDetailPanel

struct AppDetailPanel: View {
    let summary: AppUsageSummary
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            panelHeader
                .padding(DS.Spacing.md)

            Divider().background(DS.Colors.cardBorder)

            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {
                    // Usage timeline
                    hourlyChart

                    // Stats grid
                    statsGrid

                    // 7-day comparison
                    weeklyChart
                }
                .padding(DS.Spacing.md)
            }
        }
        .background(DS.Colors.secondaryBackground)
        .overlay(
            Rectangle()
                .fill(DS.Colors.cardBorder)
                .frame(width: 0.5),
            alignment: .leading
        )
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            if let icon = summary.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DS.Colors.primaryAccent.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(String(summary.appName.prefix(1)))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(DS.Colors.primaryAccent)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.appName)
                    .font(DS.Fonts.cardTitle())
                    .foregroundColor(DS.Colors.primaryText)
                    .lineLimit(1)
                CategoryBadge(category: summary.category)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DS.Colors.secondaryText)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(DS.Colors.cardBorder.opacity(0.5)))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Hourly chart

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Usage Today")
                .font(DS.Fonts.caption())
                .foregroundColor(DS.Colors.secondaryText)

            Chart(Array(summary.hourlyUsage.enumerated()), id: \.offset) { hour, seconds in
                if seconds > 0 {
                    BarMark(
                        x: .value("Hour", hour),
                        y: .value("Seconds", seconds / 60)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DS.Colors.primaryAccent, DS.Colors.secondaryAccent],
                            startPoint: .bottom, endPoint: .top
                        )
                    )
                    .cornerRadius(3)
                }
            }
            .chartXAxis {
                AxisMarks(values: [0, 6, 12, 18, 23]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(DS.Colors.cardBorder)
                    if let h = val.as(Int.self) {
                        AxisValueLabel {
                            Text(h == 0 ? "12a" : h < 12 ? "\(h)a" : h == 12 ? "12p" : "\(h-12)p")
                                .font(DS.Fonts.micro()).foregroundStyle(DS.Colors.tertiaryText)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(DS.Colors.cardBorder)
                    if let m = val.as(Double.self), m > 0 {
                        AxisValueLabel {
                            Text("\(Int(m))m").font(DS.Fonts.micro()).foregroundStyle(DS.Colors.tertiaryText)
                        }
                    }
                }
            }
            .chartPlotStyle { $0.background(.clear) }
            .frame(height: 100)
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Layout.cardCornerRadius).fill(DS.Colors.primaryBackground))
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
            statCell(icon: "clock",            label: "Total Today",      value: Formatters.durationLong(summary.totalDuration))
            statCell(icon: "arrow.triangle.2.circlepath", label: "Sessions", value: "\(summary.sessionCount)")
            statCell(icon: "clock.arrow.circlepath",      label: "First Used",  value: Formatters.relative(summary.firstUsed))
            statCell(icon: "clock.badge.checkmark",       label: "Last Used",   value: Formatters.relative(summary.lastUsed))
        }
    }

    private func statCell(icon: String, label: String, value: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(DS.Colors.primaryAccent)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(DS.Fonts.micro())
                    .foregroundColor(DS.Colors.tertiaryText)
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(DS.Colors.primaryBackground))
    }

    // MARK: - 7-day comparison (mock weekly data)

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("7-Day Trend")
                .font(DS.Fonts.caption())
                .foregroundColor(DS.Colors.secondaryText)

            let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            let usage = (0..<7).map { _ in Double.random(in: 0...summary.totalDuration) }

            Chart(Array(zip(days, usage)), id: \.0) { day, dur in
                BarMark(
                    x: .value("Day", day),
                    y: .value("Minutes", dur / 60)
                )
                .foregroundStyle(DS.Colors.primaryAccent.opacity(0.7))
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks { val in
                    if let d = val.as(String.self) {
                        AxisValueLabel {
                            Text(d).font(DS.Fonts.micro()).foregroundStyle(DS.Colors.tertiaryText)
                        }
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartPlotStyle { $0.background(.clear) }
            .frame(height: 80)
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Layout.cardCornerRadius).fill(DS.Colors.primaryBackground))
    }
}
