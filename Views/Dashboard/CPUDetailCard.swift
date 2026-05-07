import SwiftUI
import Charts

// MARK: - CPUDetailCard

struct CPUDetailCard: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        GlowingCard(accentColor: DS.Colors.secondaryAccent) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                HStack {
                    Label("CPU Performance", systemImage: "cpu")
                        .font(DS.Fonts.cardTitle())
                        .foregroundColor(DS.Colors.primaryText)
                        .labelStyle(.titleAndIcon)
                    Spacer()
                    // Status pills
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(vm.cpuPills, id: \.label) { pill in
                            MetricBadge(
                                value: String(format: "%.0f%%", pill.value),
                                label: pill.label,
                                color: Color(hex: pill.color)
                            )
                        }
                    }
                }

                // Main chart
                cpuHistoryChart
                    .frame(height: 120)

                // Per-core breakdown
                if !vm.cpuData.coreUsages.isEmpty {
                    coreBreakdown
                }
            }
        }
    }

    // MARK: - History chart (Swift Charts)

    private var cpuHistoryChart: some View {
        let points = vm.cpuHistory.enumerated().map { (i, v) in
            (x: Double(i), y: v)
        }

        return Chart {
            // Warning threshold line at 80%
            RuleMark(y: .value("Threshold", 80))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .foregroundStyle(DS.Colors.dangerRed.opacity(0.5))
                .annotation(position: .trailing) {
                    Text("80%")
                        .font(DS.Fonts.micro())
                        .foregroundColor(DS.Colors.dangerRed.opacity(0.7))
                }

            // Area fill
            ForEach(points, id: \.x) { pt in
                AreaMark(
                    x: .value("Time", pt.x),
                    y: .value("CPU%", pt.y)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [DS.Colors.secondaryAccent.opacity(0.35), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Line on top
            ForEach(points, id: \.x) { pt in
                LineMark(
                    x: .value("Time", pt.x),
                    y: .value("CPU%", pt.y)
                )
                .foregroundStyle(DS.Colors.secondaryAccent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(preset: .automatic, values: .stride(by: 10)) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                    .foregroundStyle(DS.Colors.cardBorder)
                if let i = val.as(Double.self) {
                    let ago = Int(Double(AppConstants.History.sparklinePoints) - i)
                    AxisValueLabel {
                        Text(ago == 0 ? "now" : "\(ago)s")
                            .font(DS.Fonts.micro())
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4))
                    .foregroundStyle(DS.Colors.cardBorder)
                AxisValueLabel {
                    if let v = val.as(Int.self) {
                        Text("\(v)%")
                            .font(DS.Fonts.micro())
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartPlotStyle { plot in
            plot.background(Color.clear)
        }
    }

    // MARK: - Per-core breakdown

    private var coreBreakdown: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Per-Core Usage")
                .font(DS.Fonts.caption())
                .foregroundColor(DS.Colors.secondaryText)
                .padding(.top, DS.Spacing.xs)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: 4),
                spacing: DS.Spacing.sm
            ) {
                ForEach(Array(vm.cpuData.coreUsages.enumerated()), id: \.offset) { idx, usage in
                    CoreBar(core: idx, usage: usage)
                }
            }
        }
    }
}

// MARK: - CoreBar

private struct CoreBar: View {
    let core: Int
    let usage: Double

    private var barColor: Color { DS.Colors.forCPU(usage) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("C\(core)")
                    .font(DS.Fonts.micro())
                    .foregroundColor(DS.Colors.tertiaryText)
                Spacer()
                Text(String(format: "%.0f%%", usage))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(barColor)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(DS.Colors.cardBorder)
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: geo.size.width * (usage / 100), height: 4)
                        .animation(DS.Animations.dataUpdate, value: usage)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Preview

#Preview {
    CPUDetailCard(vm: DashboardViewModel())
        .padding()
        .background(DS.Colors.primaryBackground)
        .frame(width: 800)
}
