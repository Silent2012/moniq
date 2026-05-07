import SwiftUI

// MARK: - MenuBarPopoverView
// Compact mini-dashboard shown when clicking the menu bar item

struct MenuBarPopoverView: View {
    @ObservedObject var dashVM: DashboardViewModel
    @EnvironmentObject var theme: AppTheme
    var openMainWindow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            popoverHeader

            // Gauge row
            gaugeRow
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)

            // Network + sparklines
            networkRow
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.md)

            Divider()
                .background(DS.Colors.cardBorder)

            // Bottom stats
            bottomStats
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)

            Divider()
                .background(DS.Colors.cardBorder)

            // Open button
            openButton
        }
        .background(DS.Colors.primaryBackground)
        .frame(width: 320)
    }

    // MARK: - Header

    private var popoverHeader: some View {
        ZStack(alignment: .bottom) {
            // Subtle gradient wash behind the header
            LinearGradient(
                colors: [theme.primaryAccent.opacity(0.18), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 56)

            HStack(spacing: DS.Spacing.sm) {
                // App icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [theme.primaryAccent, DS.Colors.secondaryAccent],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                        .shadow(color: theme.primaryAccent.opacity(0.5), radius: 6, x: 0, y: 2)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("moniq")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .gradientForeground(theme.heroGradient)

                Spacer()

                LiveBadge()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)
        }
    }

    // MARK: - Gauge row (CPU · Memory · Battery)

    private var gaugeRow: some View {
        HStack(spacing: 0) {
            let cpuColor  = DS.Colors.forCPU(dashVM.cpuData.usage)
            let memColor  = DS.Colors.pinkAccent
            let batPct    = Double(dashVM.batteryData.currentCapacity)
            let batColor  = DS.Colors.forBattery(batPct)

            gaugeCell(
                value: dashVM.cpuData.usage / 100,
                label: "CPU",
                display: String(format: "%.0f%%", dashVM.cpuData.usage),
                icon: "cpu",
                color: cpuColor
            )

            gaugeDivider

            gaugeCell(
                value: dashVM.memoryData.usagePercent / 100,
                label: "RAM",
                display: String(format: "%.0f%%", dashVM.memoryData.usagePercent),
                icon: "memorychip",
                color: memColor
            )

            gaugeDivider

            gaugeCell(
                value: batPct / 100,
                label: "Battery",
                display: "\(dashVM.batteryData.currentCapacity)%",
                icon: dashVM.batteryData.isCharging ? "bolt.fill" : "battery.75percent",
                color: batColor
            )
        }
        .padding(.vertical, DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(DS.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(DS.Colors.cardBorder, lineWidth: 1)
                )
        )
    }

    private var gaugeDivider: some View {
        Rectangle()
            .fill(DS.Colors.cardBorder)
            .frame(width: 1, height: 60)
    }

    private func gaugeCell(value: Double, label: String, display: String,
                           icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            AnimatedRing(value: value, color: color, lineWidth: 5, size: 52, glowEnabled: false) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
            }
            Text(display)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(label)
                .font(DS.Fonts.micro())
                .foregroundColor(DS.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Network row

    private var networkRow: some View {
        let net     = dashVM.networkData
        let dlSpeed = Formatters.networkSpeedCompact(net.downloadSpeed)
        let ulSpeed = Formatters.networkSpeedCompact(net.uploadSpeed)

        return HStack(spacing: DS.Spacing.sm) {
            // Download
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.successGreen)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Download")
                        .font(DS.Fonts.micro())
                        .foregroundColor(DS.Colors.tertiaryText)
                    Text("\(dlSpeed.value) \(dlSpeed.unit)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Colors.successGreen)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(DS.Colors.cardBorder)
                .frame(width: 1, height: 28)

            // Sparkline
            SparklineView(data: dashVM.cpuHistory, color: DS.Colors.successGreen.opacity(0.7),
                          height: 22, showDot: false)
                .frame(width: 60)

            Rectangle()
                .fill(DS.Colors.cardBorder)
                .frame(width: 1, height: 28)

            // Upload
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(DS.Colors.secondaryAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Upload")
                        .font(DS.Fonts.micro())
                        .foregroundColor(DS.Colors.tertiaryText)
                    Text("\(ulSpeed.value) \(ulSpeed.unit)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.Colors.secondaryAccent)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(DS.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(DS.Colors.cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Bottom stats

    private var bottomStats: some View {
        HStack(spacing: 0) {
            bottomStatCell(
                icon: "clock",
                iconColor: DS.Colors.secondaryAccent,
                label: "Uptime",
                value: dashVM.uptimeString
            )

            Rectangle()
                .fill(DS.Colors.cardBorder)
                .frame(width: 1, height: 30)

            bottomStatCell(
                icon: "app.fill",
                iconColor: DS.Colors.warningAmber,
                label: "Top App",
                value: dashVM.processes.first?.name ?? "—"
            )
        }
    }

    private func bottomStatCell(icon: String, iconColor: Color,
                                label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(iconColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(DS.Fonts.micro())
                    .foregroundColor(DS.Colors.tertiaryText)
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.Colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Open button

    private var openButton: some View {
        Button(action: openMainWindow) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 10, weight: .semibold))
                Text("Open moniq")
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundColor(.white)
            .background(
                LinearGradient(
                    colors: [theme.primaryAccent, DS.Colors.secondaryAccent],
                    startPoint: .leading, endPoint: .trailing
                )
                .opacity(0.85)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MenuBarStatusView
// The small view rendered in the menu bar itself.
// Observes SettingsViewModel directly so toggling a metric in Settings →
// Menu Bar immediately updates what's visible here.

struct MenuBarStatusView: View {
    @ObservedObject var vm:       DashboardViewModel
    @ObservedObject var settings: SettingsViewModel

    // Build an explicit array so the HStack has a single concrete collection
    // to measure — this prevents items from overlapping in the MenuBarExtra label.
    private struct StatusItem: Identifiable {
        let id: String
        let icon: String
        let value: String
        let color: Color
    }

    // When coloured is off every item uses plain white so it blends with
    // other native menu bar items (e.g. Wi-Fi, battery, clock).
    private func resolvedColor(_ accent: Color) -> Color {
        settings.menuBarColoured ? accent : .white
    }

    private var activeItems: [StatusItem] {
        var items: [StatusItem] = []
        if settings.menuBarShowCPU {
            items.append(StatusItem(
                id: "cpu", icon: "cpu",
                value: String(format: "%.0f%%", vm.cpuData.usage),
                color: resolvedColor(DS.Colors.forCPU(vm.cpuData.usage))))
        }
        if settings.menuBarShowMemory {
            items.append(StatusItem(
                id: "mem", icon: "memorychip",
                value: String(format: "%.0f%%", vm.memoryData.usagePercent),
                color: resolvedColor(DS.Colors.pinkAccent)))
        }
        if settings.menuBarShowBattery {
            let pct = vm.batteryData.currentCapacity
            items.append(StatusItem(
                id: "bat", icon: batteryIcon(pct: pct, charging: vm.batteryData.isCharging),
                value: "\(pct)%",
                color: resolvedColor(DS.Colors.forBattery(Double(pct)))))
        }
        if settings.menuBarShowNetwork {
            items.append(StatusItem(
                id: "net", icon: "arrow.down",
                value: Formatters.networkSpeedMenuBar(vm.networkData.downloadSpeed),
                color: resolvedColor(DS.Colors.successGreen)))
        }
        return items
    }

    var body: some View {
        HStack(spacing: 8) {
            if activeItems.isEmpty {
                // Nothing enabled — keep a clickable icon so the popover still opens.
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.Colors.secondaryText)
            } else {
                ForEach(activeItems) { item in
                    menuItem(icon: item.icon, value: item.value, color: item.color)
                }
            }
        }
        .fixedSize()
    }

    private func menuItem(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
                // Gentle opacity crossfade — unobtrusive in the menu bar
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: value)
        }
    }

    private func batteryIcon(pct: Int, charging: Bool) -> String {
        if charging { return "battery.100percent.bolt" }
        if pct > 75 { return "battery.100percent" }
        if pct > 50 { return "battery.75percent" }
        if pct > 25 { return "battery.50percent" }
        return "battery.25percent"
    }
}

// MARK: - Preview

#Preview {
    MenuBarPopoverView(dashVM: DashboardViewModel(), openMainWindow: {})
        .background(DS.Colors.primaryBackground)
}
