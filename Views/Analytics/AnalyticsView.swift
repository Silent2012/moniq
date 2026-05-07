import SwiftUI
import Charts

// MARK: - AnalyticsView

struct AnalyticsView: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var enabledMetrics: Set<MetricType> = [.cpu, .memory]
    private let historyMetrics: [MetricType] = [.cpu, .memory]
    @State private var dayOffset = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Layout.sectionGap) {
                // 7-day timeline
                timelineSection
                    .slideUpOnAppear(delay: 0)

                // Heatmap
                heatmapSection
                    .slideUpOnAppear(delay: 0.1)

                // Insight cards
                insightsSection
                    .slideUpOnAppear(delay: 0.15)
            }
            .padding(DS.Layout.contentPadding)
        }
        .background(DS.Colors.primaryBackground)
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        GlowingCard(accentColor: DS.Colors.primaryAccent) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    Text("7-Day Overview")
                        .font(DS.Fonts.cardTitle())
                        .foregroundColor(DS.Colors.primaryText)
                    Spacer()
                    // Metric toggles (only metrics with real recorded history)
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(historyMetrics, id: \.self) { metric in
                            metricToggle(metric)
                        }
                    }
                }

                TimelineChart(recorder: vm.analyticsRecorder,
                             enabledMetrics: enabledMetrics)
                    .frame(height: 180)
                    .clipped()
            }
        }
    }

    private func metricToggle(_ metric: MetricType) -> some View {
        let enabled = enabledMetrics.contains(metric)
        return Button {
            withAnimation(DS.Animations.spring) {
                if enabled { enabledMetrics.remove(metric) }
                else { enabledMetrics.insert(metric) }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(enabled ? Color(hex: metric.color) : DS.Colors.cardBorder)
                    .frame(width: 6, height: 6)
                Text(metric.rawValue)
                    .font(DS.Fonts.micro())
                    .foregroundColor(enabled ? DS.Colors.primaryText : DS.Colors.tertiaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(enabled ? Color(hex: metric.color).opacity(0.12) : DS.Colors.cardBorder.opacity(0.3))
            )
            .overlay(
                Capsule()
                    .strokeBorder(enabled ? Color(hex: metric.color).opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day History

    private var heatmapSection: some View {
        GlowingCard(accentColor: DS.Colors.primaryAccent) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Day History")
                            .font(DS.Fonts.cardTitle())
                            .foregroundColor(DS.Colors.primaryText)
                        Text("CPU & Memory — recorded every 30 s")
                            .font(DS.Fonts.micro())
                            .foregroundColor(DS.Colors.tertiaryText)
                    }
                    Spacer()
                    // Day navigation
                    HStack(spacing: DS.Spacing.xs) {
                        navButton(symbol: "chevron.left",
                                  disabled: !canGoBack) { dayOffset -= 1 }
                        Text(dayLabel)
                            .font(DS.Fonts.caption())
                            .foregroundColor(DS.Colors.secondaryText)
                            .frame(minWidth: 90, alignment: .center)
                        navButton(symbol: "chevron.right",
                                  disabled: dayOffset >= 0) { dayOffset += 1 }
                    }
                }

                DayHistoryView(recorder: vm.analyticsRecorder, dayOffset: $dayOffset)
            }
        }
    }

    private var dayLabel: String {
        switch dayOffset {
        case  0: return "Today"
        case -1: return "Yesterday"
        default:
            let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
            let fmt  = DateFormatter()
            fmt.dateFormat = "EEE, MMM d"
            return fmt.string(from: date)
        }
    }

    private var canGoBack: Bool {
        guard let oldest = vm.analyticsRecorder.oldestDate else { return false }
        let target = Calendar.current.date(byAdding: .day, value: dayOffset - 1, to: Date()) ?? Date()
        return Calendar.current.startOfDay(for: oldest) <= Calendar.current.startOfDay(for: target)
    }

    private func navButton(symbol: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(disabled ? DS.Colors.tertiaryText : DS.Colors.secondaryText)
                .frame(width: 24, height: 24)
                .background(Circle().fill(DS.Colors.cardBorder.opacity(0.4)))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Insights")
                .font(DS.Fonts.sectionTitle())
                .foregroundColor(DS.Colors.primaryText)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: DS.Layout.cardGap
            ) {
                ForEach(generatedInsights) { insight in
                    InsightCardView(insight: insight)
                }
            }
        }
    }

    private var generatedInsights: [InsightCard] {
        var cards = [InsightCard]()

        let maxCPU = vm.cpuHistory.max() ?? 0
        if maxCPU > 0 {
            cards.append(InsightCard(
                title: "CPU Peak",
                description: "Your CPU peaked at \(String(format: "%.0f%%", maxCPU)) today",
                highlight: String(format: "%.0f%%", maxCPU),
                type: .cpuPeak,
                timestamp: Date()
            ))
        }

        let avgCPU = vm.cpuHistory.average
        cards.append(InsightCard(
            title: "Avg CPU Today",
            description: "Average CPU usage is \(String(format: "%.0f%%", avgCPU))",
            highlight: String(format: "%.0f%%", avgCPU),
            type: .cpuPeak,
            timestamp: Date()
        ))

        let memPct = vm.memoryData.usagePercent
        cards.append(InsightCard(
            title: "Memory Pressure",
            description: "Memory is \(String(format: "%.0f%%", memPct)) full — \(vm.memoryData.pressure.rawValue)",
            highlight: vm.memoryData.pressure.rawValue,
            type: .memoryPressure,
            timestamp: Date()
        ))

        let dl = Formatters.bytesShort(vm.networkData.totalDownload)
        cards.append(InsightCard(
            title: "Data Today",
            description: "You've downloaded \(dl) this session",
            highlight: dl,
            type: .networkSpike,
            timestamp: Date()
        ))

        return cards
    }
}

// MARK: - InsightCardView

private struct InsightCardView: View {
    let insight: InsightCard

    private var accentColor: Color { Color(hex: insight.type.color) }

    var body: some View {
        GlowingCard(accentColor: accentColor, padding: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                // Left accent border + icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(insight.title)
                        .font(DS.Fonts.caption())
                        .foregroundColor(DS.Colors.secondaryText)

                    Text(insight.description)
                        .font(DS.Fonts.metricLabel())
                        .foregroundColor(DS.Colors.primaryText)
                        .lineLimit(2)
                }
            }
        }
        .overlay(
            HStack {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)
                    .clipShape(
                        .rect(cornerRadii: .init(topLeading: DS.Layout.cardCornerRadius,
                                                  bottomLeading: DS.Layout.cardCornerRadius))
                    )
                Spacer()
            }
        )
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView(vm: DashboardViewModel())
        .frame(width: 900, height: 700)
}
