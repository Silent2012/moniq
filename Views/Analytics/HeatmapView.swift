import SwiftUI
import Charts

// MARK: - DayHistoryView
// Shows real CPU + Memory samples for a chosen calendar day.
// Replaces the old fake heatmap.

struct DayHistoryView: View {
    let recorder: AnalyticsRecorder
    /// 0 = today, -1 = yesterday, -2 = two days ago, …
    @Binding var dayOffset: Int

    private var targetDate: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
    }

    private var daySamples: [AnalyticsSample] {
        recorder.samples(for: targetDate)
    }

    // Downsample to 5-minute buckets for a clean chart
    private var chartPoints: [ChartPoint] {
        guard !daySamples.isEmpty else { return [] }
        let bucketSize: TimeInterval = 300   // 5 minutes
        var buckets = [Int: (sumCPU: Double, sumMem: Double, count: Int)]()

        let dayStart = Calendar.current.startOfDay(for: targetDate)
        for s in daySamples {
            let bucket = Int(s.timestamp.timeIntervalSince(dayStart) / bucketSize)
            let existing = buckets[bucket] ?? (0, 0, 0)
            buckets[bucket] = (existing.sumCPU + s.cpu,
                               existing.sumMem + s.memory,
                               existing.count  + 1)
        }

        return buckets.sorted { $0.key < $1.key }.flatMap { key, val -> [ChartPoint] in
            let t    = dayStart.addingTimeInterval(Double(key) * bucketSize)
            let cpu  = val.sumCPU / Double(val.count)
            let mem  = val.sumMem / Double(val.count)
            return [
                ChartPoint(timestamp: t, value: cpu, metric: "CPU"),
                ChartPoint(timestamp: t, value: mem, metric: "Memory"),
            ]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if daySamples.isEmpty {
                emptyState
            } else {
                chart
                sampleCount
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(chartPoints) { point in
            LineMark(
                x: .value("Time",  point.timestamp),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Metric", point.metric))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 1.8))

            AreaMark(
                x: .value("Time",  point.timestamp),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Metric", point.metric))
            .opacity(0.08)
            .interpolationMethod(.catmullRom)
        }
        .chartForegroundStyleScale([
            "CPU":    DS.Colors.secondaryAccent,
            "Memory": DS.Colors.pinkAccent,
        ])
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(DS.Colors.cardBorder)
                if let date = val.as(Date.self) {
                    AxisValueLabel {
                        Text(hourLabel(date))
                            .font(DS.Fonts.micro())
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(DS.Colors.cardBorder)
                if let v = val.as(Int.self) {
                    AxisValueLabel {
                        Text("\(v)%")
                            .font(DS.Fonts.micro())
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                }
            }
        }
        .chartYScale(domain: 0...105)
        .chartLegend(position: .top, alignment: .trailing) {
            HStack(spacing: DS.Spacing.sm) {
                legendDot(color: DS.Colors.secondaryAccent, label: "CPU")
                legendDot(color: DS.Colors.pinkAccent,      label: "Memory")
            }
        }
        .chartPlotStyle { $0.background(.clear) }
        .frame(height: 180)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(DS.Fonts.micro()).foregroundColor(DS.Colors.secondaryText)
        }
    }

    private var sampleCount: some View {
        Text("\(daySamples.count) samples recorded · one every 30 s")
            .font(DS.Fonts.micro())
            .foregroundColor(DS.Colors.tertiaryText)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundColor(DS.Colors.cardBorder)
                Text(dayOffset == 0
                     ? "No samples yet — data appears after 30 s"
                     : "No data recorded for this day")
                    .font(DS.Fonts.caption())
                    .foregroundColor(DS.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, DS.Spacing.xl)
            Spacer()
        }
    }

    // MARK: - Helpers

    private func hourLabel(_ date: Date) -> String {
        let h = Calendar.current.component(.hour, from: date)
        if h == 0  { return "12a" }
        if h < 12  { return "\(h)a" }
        if h == 12 { return "12p" }
        return "\(h - 12)p"
    }
}

// MARK: - ChartPoint

private struct ChartPoint: Identifiable {
    let id        = UUID()
    let timestamp: Date
    let value:     Double
    let metric:    String
}
