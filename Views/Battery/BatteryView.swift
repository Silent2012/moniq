import SwiftUI
import Charts

// MARK: - BatteryView

struct BatteryView: View {
    @ObservedObject var monitor: BatteryMonitor

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Layout.sectionGap) {
                // Hero section
                heroSection
                    .slideUpOnAppear(delay: 0)

                // Stats grid
                statsGrid
                    .slideUpOnAppear(delay: 0.08)

                // Charge history chart
                chargeHistorySection
                    .slideUpOnAppear(delay: 0.12)

                // Tips card
                batteryTipsCard
                    .slideUpOnAppear(delay: 0.16)
            }
            .padding(DS.Layout.contentPadding)
        }
        .background(DS.Colors.primaryBackground)
    }

    // MARK: - Hero section

    private var heroSection: some View {
        GlowingCard(accentColor: batteryColor) {
            HStack(spacing: DS.Layout.cardGap * 2) {
                // Animated battery icon
                batteryIconView
                    .frame(width: 140)

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Battery")
                            .font(DS.Fonts.cardTitle())
                            .foregroundColor(DS.Colors.secondaryText)

                        HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.sm) {
                            Text("\(monitor.batteryData.currentCapacity)")
                                .font(DS.Fonts.heroNumber())
                                .foregroundColor(batteryColor)
                                .monospacedDigit()

                            Text("%")
                                .font(DS.Fonts.largeNumber())
                                .foregroundColor(batteryColor.opacity(0.6))
                        }
                    }

                    // Status
                    statusRow

                    // Time remaining / to full
                    if monitor.batteryData.isCharging && monitor.batteryData.timeToFull > 0 {
                        timeRow(label: "Time to Full",
                                value: Formatters.batteryTime(minutes: monitor.batteryData.timeToFull),
                                icon: "bolt.fill",
                                color: DS.Colors.successGreen)
                    } else if !monitor.batteryData.isCharging && monitor.batteryData.timeToEmpty > 0 {
                        timeRow(label: "Time Remaining",
                                value: Formatters.batteryTime(minutes: monitor.batteryData.timeToEmpty),
                                icon: "clock",
                                color: batteryColor)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Animated battery icon

    private var batteryIconView: some View {
        let pct = Double(monitor.batteryData.currentCapacity) / 100.0

        return ZStack {
            // Outer shell
            RoundedRectangle(cornerRadius: 14)
                .stroke(batteryColor.opacity(0.5), lineWidth: 3)
                .frame(width: 100, height: 48)

            // Terminal nub
            RoundedRectangle(cornerRadius: 3)
                .fill(batteryColor.opacity(0.5))
                .frame(width: 8, height: 16)
                .offset(x: 54)

            // Fill
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [batteryColor, batteryColor.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: (geo.size.width - 8) * pct, height: geo.size.height - 8)
                    .offset(x: 4, y: 4)
                    .animation(DS.Animations.dataUpdate, value: pct)
                    .shadow(color: batteryColor.opacity(0.4), radius: 6)
            }
            .frame(width: 100, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Charging bolt
            if monitor.batteryData.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: batteryColor, radius: 4)
            }
        }
        .glowEffect(color: batteryColor, radius: 16, opacity: 0.25)
    }

    private var batteryColor: Color {
        DS.Colors.forBattery(Double(monitor.batteryData.currentCapacity))
    }

    // MARK: - Status row

    private var statusRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            StatusDot(status: monitor.batteryData.isCharging ? .good : .live,
                      label: monitor.batteryData.isCharging ? "Charging" : "On Battery",
                      showPulse: monitor.batteryData.isCharging)
            if monitor.batteryData.isPluggedIn && !monitor.batteryData.isCharging {
                Text("(Charged)")
                    .font(DS.Fonts.caption())
                    .foregroundColor(DS.Colors.tertiaryText)
            }
        }
    }

    private func timeRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(label + ": ")
                .font(DS.Fonts.metricLabel())
                .foregroundColor(DS.Colors.secondaryText)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
        }
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: DS.Layout.cardGap), count: 3),
            spacing: DS.Layout.cardGap
        ) {
            batteryStatCard(
                icon: "arrow.trianglehead.2.counterclockwise.rotate.90",
                label: "Cycle Count",
                value: "\(monitor.batteryData.cycleCount)",
                color: DS.Colors.primaryAccent
            )
            batteryStatCard(
                icon: "heart.fill",
                label: "Battery Health",
                value: String(format: "%.0f%%", monitor.batteryData.health),
                color: DS.Colors.forHealth(monitor.batteryData.health),
                subtitle: monitor.batteryData.healthStatus.rawValue
            )
            batteryStatCard(
                icon: "thermometer.medium",
                label: "Temperature",
                value: monitor.batteryData.temperature > 0
                    ? Formatters.temperature(monitor.batteryData.temperature)
                    : "N/A",
                color: DS.Colors.warningAmber
            )
            batteryStatCard(
                icon: "bolt.circle",
                label: "Voltage",
                value: monitor.batteryData.voltage > 0
                    ? String(format: "%.2f V", monitor.batteryData.voltage)
                    : "N/A",
                color: DS.Colors.secondaryAccent
            )
            batteryStatCard(
                icon: "battery.100percent.bolt",
                label: "Design Capacity",
                value: "\(monitor.batteryData.designCapacity) mAh",
                color: DS.Colors.tertiaryText
            )
            batteryStatCard(
                icon: "battery.75percent",
                label: "Current Capacity",
                value: "\(monitor.batteryData.maxCapacity) mAh",
                color: DS.Colors.secondaryText
            )
        }
    }

    private func batteryStatCard(icon: String, label: String, value: String, color: Color, subtitle: String? = nil) -> some View {
        GlowingCard(accentColor: color, padding: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.4), radius: 4)

                Spacer()

                Text(value)
                    .font(DS.Fonts.smallNumber())
                    .foregroundColor(DS.Colors.primaryText)
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if let sub = subtitle {
                    Text(sub)
                        .font(DS.Fonts.micro())
                        .foregroundColor(color)
                } else {
                    Text(label)
                        .font(DS.Fonts.caption())
                        .foregroundColor(DS.Colors.tertiaryText)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 90)
        }
    }

    // MARK: - Charge history

    private var chargeHistorySection: some View {
        GlowingCard(accentColor: batteryColor) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Charge History (24h)")
                    .font(DS.Fonts.cardTitle())
                    .foregroundColor(DS.Colors.primaryText)

                if monitor.history.isEmpty {
                    Text("Collecting data…")
                        .font(DS.Fonts.caption())
                        .foregroundColor(DS.Colors.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .frame(height: 100)
                } else {
                    Chart(monitor.history) { point in
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Battery%", point.percentage)
                        )
                        .foregroundStyle(DS.Gradients.chartFill(color: batteryColor))
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("Battery%", point.percentage)
                        )
                        .foregroundStyle(batteryColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .hour, count: 4)) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(DS.Colors.cardBorder)
                            if let d = val.as(Date.self) {
                                AxisValueLabel {
                                    Text(Formatters.timeString(d).prefix(5).description)
                                        .font(DS.Fonts.micro()).foregroundStyle(DS.Colors.tertiaryText)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)).foregroundStyle(DS.Colors.cardBorder)
                            if let v = val.as(Int.self) {
                                AxisValueLabel {
                                    Text("\(v)%").font(DS.Fonts.micro()).foregroundStyle(DS.Colors.tertiaryText)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...105)
                    .chartPlotStyle { $0.background(.clear) }
                    .frame(height: 120)
                }
            }
        }
    }

    // MARK: - Tips

    private var batteryTipsCard: some View {
        GlowingCard(accentColor: DS.Colors.successGreen) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(DS.Colors.successGreen)
                    Text("Battery Saver Tips")
                        .font(DS.Fonts.cardTitle())
                        .foregroundColor(DS.Colors.primaryText)
                }

                ForEach(tips, id: \.title) { tip in
                    HStack(alignment: .top, spacing: DS.Spacing.sm) {
                        Image(systemName: tip.icon)
                            .font(.system(size: 11))
                            .foregroundColor(DS.Colors.successGreen)
                            .frame(width: 16)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tip.title)
                                .font(DS.Fonts.metricLabel())
                                .foregroundColor(DS.Colors.primaryText)
                            Text(tip.detail)
                                .font(DS.Fonts.caption())
                                .foregroundColor(DS.Colors.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private let tips = [
        (icon: "display",          title: "Reduce display brightness",  detail: "Screen is the biggest battery drain."),
        (icon: "wifi.slash",       title: "Disable unused wireless",    detail: "Turn off Bluetooth/Wi-Fi when not needed."),
        (icon: "app.badge.clock",  title: "Quit background apps",       detail: "Background processes consume CPU and battery."),
        (icon: "bolt.slash.fill",  title: "Enable Low Power Mode",      detail: "Reduces performance to extend battery life."),
    ]
}

// MARK: - Preview

#Preview {
    BatteryView(monitor: BatteryMonitor())
        .frame(width: 800, height: 700)
}
