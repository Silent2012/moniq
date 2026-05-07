import SwiftUI

// MARK: - HeroMetricsRow

struct HeroMetricsRow: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var appeared = false

    var body: some View {
        HStack(spacing: DS.Layout.cardGap) {
            CPUHeroCard(vm: vm)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(DS.Animations.stagger(index: 0), value: appeared)

            MemoryHeroCard(vm: vm)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(DS.Animations.stagger(index: 1), value: appeared)

            NetworkHeroCard(vm: vm)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(DS.Animations.stagger(index: 2), value: appeared)

            BatteryHeroCard(vm: vm)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(DS.Animations.stagger(index: 3), value: appeared)
        }
        .onAppear { appeared = true }
    }
}

// MARK: - Pin button
// Shown in the top-right of each hero card; toggles whether the stat
// appears in the macOS menu bar.

private struct PinButton: View {
    @Binding var isPinned: Bool
    var color: Color

    @State private var isHovered = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                isPinned.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(isPinned
                          ? color.opacity(0.18)
                          : (isHovered ? DS.Colors.cardBorder.opacity(0.5) : Color.clear))
                    .frame(width: 22, height: 22)

                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isPinned ? color : DS.Colors.tertiaryText)
                    .rotationEffect(.degrees(isPinned ? 0 : 45))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(isPinned ? "Unpin from menu bar" : "Pin to menu bar")
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPinned)
    }
}

// MARK: - CPU Hero Card

private struct CPUHeroCard: View {
    @ObservedObject var vm: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    private var cpuColor: Color { DS.Colors.forCPU(vm.cpuData.usage) }

    var body: some View {
        GlowingCard(accentColor: cpuColor) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(cpuColor)
                        .shadow(color: cpuColor.opacity(0.6), radius: 6)
                    Spacer()
                    PinButton(isPinned: $settingsVM.menuBarShowCPU, color: cpuColor)
                    StatusDot(status: .live, showPulse: true)
                }

                HeroNumber(
                    value: vm.cpuData.usage,
                    format: .percent(decimals: 0),
                    useGradient: vm.cpuData.usage <= 80,
                    color: cpuColor
                )

                Text("CPU Usage")
                    .font(DS.Fonts.metricLabel())
                    .foregroundColor(DS.Colors.secondaryText)

                SparklineView(data: vm.cpuHistory, color: cpuColor, height: 28)
            }
        }
    }
}

// MARK: - Memory Hero Card

private struct MemoryHeroCard: View {
    @ObservedObject var vm: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    var body: some View {
        GlowingCard(accentColor: DS.Colors.pinkAccent) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: "memorychip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DS.Colors.pinkAccent)
                        .shadow(color: DS.Colors.pinkAccent.opacity(0.5), radius: 6)
                    Spacer()
                    PinButton(isPinned: $settingsVM.menuBarShowMemory, color: DS.Colors.pinkAccent)
                    metricPill
                }

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", Formatters.memoryGBValue(vm.memoryData.usedMemory)))
                        .font(DS.Fonts.heroNumber())
                        .gradientForeground(
                            LinearGradient(colors: [DS.Colors.pinkAccent, DS.Colors.primaryAccent],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                    Text("/ \(String(format: "%.0f", Formatters.memoryGBValue(vm.memoryData.totalMemory))) GB")
                        .font(DS.Fonts.metricLabel())
                        .foregroundColor(DS.Colors.secondaryText)
                }

                Text("Memory")
                    .font(DS.Fonts.metricLabel())
                    .foregroundColor(DS.Colors.secondaryText)

                memoryBar
            }
        }
    }

    private var metricPill: some View {
        Text(vm.memoryData.pressure.rawValue)
            .font(DS.Fonts.micro())
            .foregroundColor(Color(hex: vm.memoryData.pressure.color))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color(hex: vm.memoryData.pressure.color).opacity(0.15)))
    }

    private var memoryBar: some View {
        let total = Double(vm.memoryData.totalMemory)
        let appF  = total > 0 ? Double(vm.memoryData.appMemory)        / total : 0
        let wirF  = total > 0 ? Double(vm.memoryData.wiredMemory)      / total : 0
        let cmpF  = total > 0 ? Double(vm.memoryData.compressedMemory) / total : 0
        let cacF  = total > 0 ? Double(vm.memoryData.cachedFiles)      / total : 0

        return GeometryReader { geo in
            HStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 2).fill(DS.Colors.pinkAccent)
                    .frame(width: geo.size.width * appF)
                RoundedRectangle(cornerRadius: 2).fill(DS.Colors.primaryAccent)
                    .frame(width: geo.size.width * wirF)
                RoundedRectangle(cornerRadius: 2).fill(DS.Colors.secondaryAccent)
                    .frame(width: geo.size.width * cmpF)
                RoundedRectangle(cornerRadius: 2).fill(DS.Colors.warningAmber.opacity(0.6))
                    .frame(width: geo.size.width * cacF)
                RoundedRectangle(cornerRadius: 2).fill(DS.Colors.cardBorder)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(height: 6)
    }
}

// MARK: - Network Hero Card

private struct NetworkHeroCard: View {
    @ObservedObject var vm: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel
    @State private var arrowPulse = false

    var body: some View {
        GlowingCard(accentColor: DS.Colors.successGreen) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: vm.networkMonitor.isConnected ? "network" : "network.slash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DS.Colors.successGreen)
                        .shadow(color: DS.Colors.successGreen.opacity(0.5), radius: 6)
                    Spacer()
                    PinButton(isPinned: $settingsVM.menuBarShowNetwork, color: DS.Colors.successGreen)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    networkSpeed(symbol: "arrow.down.circle.fill",
                                 speed: vm.networkData.downloadSpeed,
                                 color: DS.Colors.successGreen)
                    networkSpeed(symbol: "arrow.up.circle.fill",
                                 speed: vm.networkData.uploadSpeed,
                                 color: DS.Colors.primaryAccent)
                }

                Text("Network")
                    .font(DS.Fonts.metricLabel())
                    .foregroundColor(DS.Colors.secondaryText)

                SparklineView(data: vm.downloadHistory, color: DS.Colors.successGreen, height: 28)
            }
        }
    }

    private func networkSpeed(symbol: String, speed: Double, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
                .scaleEffect(arrowPulse ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                           value: arrowPulse)
            Text(Formatters.networkSpeed(speed))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(DS.Colors.primaryText)
                .monospacedDigit()
        }
        .onAppear { arrowPulse = true }
    }
}

// MARK: - Battery Hero Card

private struct BatteryHeroCard: View {
    @ObservedObject var vm: DashboardViewModel
    @EnvironmentObject var settingsVM: SettingsViewModel

    private var batteryColor: Color {
        DS.Colors.forBattery(Double(vm.batteryData.currentCapacity))
    }

    var body: some View {
        GlowingCard(accentColor: batteryColor) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(batteryColor)
                        .shadow(color: batteryColor.opacity(0.5), radius: 6)
                    Spacer()
                    PinButton(isPinned: $settingsVM.menuBarShowBattery, color: batteryColor)
                }

                ZStack {
                    AnimatedRing(
                        value: Double(vm.batteryData.currentCapacity) / 100.0,
                        color: batteryColor,
                        lineWidth: 6,
                        size: 72
                    ) {
                        Text("\(vm.batteryData.currentCapacity)%")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(batteryColor)
                    }
                }

                Text(statusText)
                    .font(DS.Fonts.caption())
                    .foregroundColor(DS.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 140)
    }

    private var batteryIcon: String {
        if vm.batteryData.isCharging { return "battery.100.bolt" }
        let pct = vm.batteryData.currentCapacity
        if pct > 75 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 25 { return "battery.50" }
        return "battery.25"
    }

    private var statusText: String {
        if vm.batteryData.isCharging {
            if vm.batteryData.timeToFull > 0 {
                return "⚡ \(Formatters.batteryTime(minutes: vm.batteryData.timeToFull)) to full"
            }
            return "⚡ Charging"
        }
        if vm.batteryData.timeToEmpty > 0 {
            return "\(Formatters.batteryTime(minutes: vm.batteryData.timeToEmpty)) remaining"
        }
        return vm.batteryMonitor.isAvailable ? "Battery" : "No battery"
    }
}

// MARK: - Preview

#Preview {
    HeroMetricsRow(vm: DashboardViewModel())
        .padding()
        .background(DS.Colors.primaryBackground)
        .frame(width: 900, height: 160)
        .environmentObject(SettingsViewModel())
}
