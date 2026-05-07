import SwiftUI
import Charts

// MARK: - NetworkCard

struct NetworkCard: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        GlowingCard(accentColor: DS.Colors.successGreen) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                HStack {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: vm.networkMonitor.isConnected ? "network" : "network.slash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DS.Colors.successGreen)
                        Text("Network")
                            .font(DS.Fonts.cardTitle())
                            .foregroundColor(DS.Colors.primaryText)
                    }
                    Spacer()
                    interfaceBadge
                }

                // Speed numbers
                HStack(spacing: DS.Layout.cardGap) {
                    speedBlock(
                        symbol: "arrow.down.circle.fill",
                        label: "Download",
                        speed: vm.networkData.downloadSpeed,
                        color: DS.Colors.successGreen
                    )
                    Divider()
                        .background(DS.Colors.cardBorder)
                        .frame(height: 36)
                    speedBlock(
                        symbol: "arrow.up.circle.fill",
                        label: "Upload",
                        speed: vm.networkData.uploadSpeed,
                        color: DS.Colors.primaryAccent
                    )
                }

                // Chart
                networkChart
                    .frame(height: 80)

                // Footer stats
                HStack(spacing: DS.Layout.cardGap) {
                    miniStat(label: "Downloaded Today", value: Formatters.bytesShort(vm.networkData.totalDownload))
                    Spacer()
                    miniStat(label: "Uploaded Today",   value: Formatters.bytesShort(vm.networkData.totalUpload))
                }
            }
        }
    }

    // MARK: - Speed block

    private func speedBlock(symbol: String, label: String, speed: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(label)
                    .font(DS.Fonts.caption())
                    .foregroundColor(DS.Colors.secondaryText)
            }
            Text(Formatters.networkSpeed(speed))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(DS.Colors.primaryText)
                .monospacedDigit()
        }
    }

    // MARK: - Network dual-line chart

    private var networkChart: some View {
        Chart {
            ForEach(Array(vm.networkMonitor.samples.enumerated()), id: \.element.id) { i, sample in
                LineMark(
                    x: .value("Time", i),
                    y: .value("Download", sample.download)
                )
                .foregroundStyle(DS.Colors.successGreen)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                AreaMark(
                    x: .value("Time", i),
                    y: .value("Download", sample.download)
                )
                .foregroundStyle(
                    LinearGradient(colors: [DS.Colors.successGreen.opacity(0.25), .clear],
                                   startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", i),
                    y: .value("Upload", sample.upload)
                )
                .foregroundStyle(DS.Colors.primaryAccent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing) { val in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    .foregroundStyle(DS.Colors.cardBorder)
                if let v = val.as(Double.self), v > 0 {
                    AxisValueLabel {
                        Text(Formatters.networkSpeed(v))
                            .font(DS.Fonts.micro())
                            .foregroundStyle(DS.Colors.tertiaryText)
                    }
                }
            }
        }
        .chartPlotStyle { $0.background(.clear) }
    }

    // MARK: - Interface badge

    private var interfaceBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: vm.networkMonitor.currentPath?.usesInterfaceType(.wifi) == true ? "wifi" : "cable.connector")
                .font(.system(size: 9))
                .foregroundColor(DS.Colors.secondaryText)
            Text(vm.networkMonitor.activeInterfaceName)
                .font(DS.Fonts.micro())
                .foregroundColor(DS.Colors.secondaryText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(DS.Colors.cardBorder.opacity(0.5)))
    }

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(DS.Fonts.micro())
                .foregroundColor(DS.Colors.tertiaryText)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.secondaryText)
                .monospacedDigit()
        }
    }
}

// MARK: - DiskCard

struct DiskCard: View {
    @ObservedObject var vm: DashboardViewModel

    private var diskColor: Color {
        vm.diskData.usagePercent > AppConstants.Threshold.diskWarning
            ? DS.Colors.warningAmber : DS.Colors.primaryAccent
    }

    var body: some View {
        GlowingCard(accentColor: diskColor) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                HStack {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "internaldrive")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(diskColor)
                        Text(vm.diskData.volumeName)
                            .font(DS.Fonts.cardTitle())
                            .foregroundColor(DS.Colors.primaryText)
                    }
                    Spacer()
                    Text(String(format: "%.1f%%", vm.diskData.usagePercent))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(diskColor)
                }

                // Usage bar
                diskUsageBar

                // Usage numbers
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Used")
                            .font(DS.Fonts.micro())
                            .foregroundColor(DS.Colors.tertiaryText)
                        Text(Formatters.bytes(vm.diskData.usedSpace))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Colors.primaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Free")
                            .font(DS.Fonts.micro())
                            .foregroundColor(DS.Colors.tertiaryText)
                        Text(Formatters.bytes(vm.diskData.freeSpace))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Colors.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Total")
                            .font(DS.Fonts.micro())
                            .foregroundColor(DS.Colors.tertiaryText)
                        Text(Formatters.bytes(vm.diskData.totalSpace))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(DS.Colors.secondaryText)
                    }
                }

                Divider().background(DS.Colors.cardBorder)

                // I/O speeds
                HStack(spacing: DS.Layout.cardGap) {
                    ioSpeed(symbol: "arrow.down.to.line.circle", label: "Read",  speed: vm.diskData.readSpeed,  color: DS.Colors.secondaryAccent)
                    Spacer()
                    ioSpeed(symbol: "arrow.up.to.line.circle",   label: "Write", speed: vm.diskData.writeSpeed, color: DS.Colors.pinkAccent)
                }
            }
        }
    }

    private var diskUsageBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(DS.Colors.cardBorder)
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [diskColor, diskColor.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geo.size.width * (vm.diskData.usagePercent / 100).clamped(to: 0...1),
                        height: 8
                    )
                    .animation(DS.Animations.dataUpdate, value: vm.diskData.usagePercent)
                    .shadow(color: diskColor.opacity(0.4), radius: 4)
            }
        }
        .frame(height: 8)
    }

    private func ioSpeed(symbol: String, label: String, speed: Double, color: Color) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(DS.Fonts.micro()).foregroundColor(DS.Colors.tertiaryText)
                Text(Formatters.networkSpeed(speed))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(DS.Colors.primaryText)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        NetworkCard(vm: DashboardViewModel()).frame(maxWidth: .infinity)
        DiskCard(vm: DashboardViewModel()).frame(maxWidth: .infinity)
    }
    .padding()
    .background(DS.Colors.primaryBackground)
    .frame(width: 800, height: 320)
}
