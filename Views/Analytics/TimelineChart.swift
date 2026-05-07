import SwiftUI
import Charts

// MARK: - TimelineChart
// Shows up to 7 days of real CPU + Memory data from AnalyticsRecorder.
// Battery and Network toggles are hidden when no historical data is available.

struct TimelineChart: View {
    let recorder:       AnalyticsRecorder
    let enabledMetrics: Set<MetricType>

    // Pinned X domain: midnight 6 days ago → end of today.
    // Explicit bounds stop catmullRom interpolation from overshooting the edges.
    private var xDomain: ClosedRange<Date> {
        let cal   = Calendar.current
        let start = cal.date(byAdding: .day, value: -6,
                             to: cal.startOfDay(for: Date())) ?? Date()
        let end   = cal.date(byAdding: .day, value: 1,
                             to: cal.startOfDay(for: Date())) ?? Date()
        return start...end
    }

    // Aggregate recorder samples into hourly averages for the chart.
    private var chartData: [MetricDataPoint] {
        let start  = xDomain.lowerBound
        let all    = recorder.samples.filter { $0.timestamp >= start }
        guard !all.isEmpty else { return [] }

        // Bucket key = hours since Unix epoch (stable, Int)
        var cpuBuckets: [Int: [Double]] = [:]
        var memBuckets: [Int: [Double]] = [:]

        for s in all {
            let key = Int(s.timestamp.timeIntervalSince1970 / 3600)
            cpuBuckets[key, default: []].append(s.cpu)
            memBuckets[key, default: []].append(s.memory)
        }

        var points = [MetricDataPoint]()

        if enabledMetrics.contains(.cpu) {
            for (key, vals) in cpuBuckets {
                let t = Date(timeIntervalSince1970: Double(key) * 3600)
                guard t >= start else { continue }
                let avg = vals.reduce(0, +) / Double(vals.count)
                points.append(MetricDataPoint(timestamp: t, value: avg, metric: .cpu))
            }
        }
        if enabledMetrics.contains(.memory) {
            for (key, vals) in memBuckets {
                let t = Date(timeIntervalSince1970: Double(key) * 3600)
                guard t >= start else { continue }
                let avg = vals.reduce(0, +) / Double(vals.count)
                points.append(MetricDataPoint(timestamp: t, value: avg, metric: .memory))
            }
        }

        return points.sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        if chartData.isEmpty {
            emptyState
        } else {
            chart
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart(chartData) { point in
            LineMark(
                x: .value("Time",  point.timestamp),
                y: .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Metric", point.metric.rawValue))
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 1.8))

            AreaMark(
                x: .value("Time",  point.timestamp),
                yStart: .value("Zero", 0),          // always fill down to 0
                yEnd:   .value("Value", point.value)
            )
            .foregroundStyle(by: .value("Metric", point.metric.rawValue))
            .opacity(0.08)
            .interpolationMethod(.catmullRom)
        }
        .chartForegroundStyleScale([
            MetricType.cpu.rawValue:    DS.Colors.secondaryAccent,
            MetricType.memory.rawValue: DS.Colors.pinkAccent,
        ])
        // Pin X axis to exactly 7 days — prevents edge overshoot
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(DS.Colors.cardBorder)
                if let date = val.as(Date.self) {
                    AxisValueLabel {
                        Text(Formatters.shortDate(date))
                            .font(DS.Fonts.micro())
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                }
            }
        }
        // Pin Y axis to 0–100 so nothing can draw above the chart frame
        .chartYScale(domain: 0...100)
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
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.background(.clear)
                .clipped()          // hard-clip inside the plot area
        }
        .clipped()                  // also clip the full chart view (axes + plot)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 28))
                    .foregroundColor(DS.Colors.cardBorder)
                Text("Data builds up over time — check back after using the app for a while")
                    .font(DS.Fonts.caption())
                    .foregroundColor(DS.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, DS.Spacing.xl)
            Spacer()
        }
    }
}
