import SwiftUI

// MARK: - MemoryRingCard

struct MemoryRingCard: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        GlowingCard(accentColor: DS.Colors.pinkAccent) {
            HStack(spacing: DS.Layout.cardGap * 2) {
                // Ring + center label
                ringView
                    .frame(width: 160, height: 160)

                // Legend + details
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Memory Usage")
                            .font(DS.Fonts.cardTitle())
                            .foregroundColor(DS.Colors.primaryText)

                        HStack(spacing: DS.Spacing.sm) {
                            pressureBadge
                        }
                    }

                    legendGrid

                    Spacer()

                    totalMemRow
                }
            }
        }
    }

    // MARK: - Ring

    private var ringView: some View {
        let total = Double(vm.memoryData.totalMemory)
        guard total > 0 else {
            return SegmentedRing(segments: [], lineWidth: 20, size: 150,
                                 centerContent: AnyView(ringCenter))
        }
        let appF = Double(vm.memoryData.appMemory)        / total
        let wirF = Double(vm.memoryData.wiredMemory)      / total
        let cmpF = Double(vm.memoryData.compressedMemory) / total
        let cacF = Double(vm.memoryData.cachedFiles)      / total
        // Free = everything else (guarantees segments sum to exactly 1.0)
        let freeF = max(0, 1 - appF - wirF - cmpF - cacF)

        let segments: [SegmentedRing.Segment] = [
            .init(value: appF,  color: DS.Colors.pinkAccent,                  label: "App"),
            .init(value: wirF,  color: DS.Colors.primaryAccent,               label: "Wired"),
            .init(value: cmpF,  color: DS.Colors.secondaryAccent,             label: "Compressed"),
            .init(value: cacF,  color: DS.Colors.warningAmber.opacity(0.6),   label: "Cached"),
            .init(value: freeF, color: DS.Colors.cardBorder,                  label: "Free"),
        ]

        return SegmentedRing(
            segments: segments,
            lineWidth: 20,
            size: 150,
            centerContent: AnyView(ringCenter)
        )
    }

    private var ringCenter: some View {
        VStack(spacing: 2) {
            Text(Formatters.memoryGB(vm.memoryData.usedMemory))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(DS.Colors.primaryText)
                .monospacedDigit()
            Text("used")
                .font(DS.Fonts.micro())
                .foregroundColor(DS.Colors.secondaryText)
        }
    }

    // MARK: - Legend

    private var legendGrid: some View {
        VStack(spacing: DS.Spacing.sm) {
            legendRow(color: DS.Colors.pinkAccent,                label: "App Memory",  bytes: vm.memoryData.appMemory)
            legendRow(color: DS.Colors.primaryAccent,             label: "Wired",       bytes: vm.memoryData.wiredMemory)
            legendRow(color: DS.Colors.secondaryAccent,           label: "Compressed",  bytes: vm.memoryData.compressedMemory)
            legendRow(color: DS.Colors.warningAmber.opacity(0.7), label: "Cached Files",bytes: vm.memoryData.cachedFiles)
            legendRow(color: DS.Colors.cardBorder,                label: "Free",        bytes: vm.memoryData.freeMemory)

            if vm.memoryData.swapTotal > 0 {
                Divider().background(DS.Colors.cardBorder.opacity(0.5))
                swapRow
            }
        }
    }

    private var swapRow: some View {
        let used  = vm.memoryData.swapUsed
        let total = vm.memoryData.swapTotal
        let pct   = total > 0 ? Double(used) / Double(total) * 100 : 0
        let color = pct > 75 ? DS.Colors.dangerRed : (pct > 40 ? DS.Colors.warningAmber : DS.Colors.tertiaryText)

        return HStack(spacing: DS.Spacing.sm) {
            // Swap icon
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(color)
                .frame(width: 8)

            Text("Swap Used")
                .font(DS.Fonts.metricLabel())
                .foregroundColor(DS.Colors.secondaryText)

            Spacer()

            // Mini bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(DS.Colors.cardBorder)
                    RoundedRectangle(cornerRadius: 2).fill(color)
                        .frame(width: geo.size.width * CGFloat(pct / 100))
                }
            }
            .frame(width: 50, height: 4)

            Text(Formatters.memoryGB(used))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
                .frame(minWidth: 44, alignment: .trailing)
        }
    }

    private func legendRow(color: Color, label: String, bytes: UInt64) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .shadow(color: color.opacity(0.5), radius: 3)

            Text(label)
                .font(DS.Fonts.metricLabel())
                .foregroundColor(DS.Colors.secondaryText)

            Spacer()

            Text(Formatters.memoryGB(bytes))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.primaryText)
                .monospacedDigit()
        }
    }

    // MARK: - Total row

    private var totalMemRow: some View {
        HStack {
            Text("Total")
                .font(DS.Fonts.metricLabel())
                .foregroundColor(DS.Colors.secondaryText)
            Spacer()
            Text(Formatters.memoryGB(vm.memoryData.totalMemory))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(DS.Colors.primaryText)
                .monospacedDigit()
        }
        .padding(.top, DS.Spacing.xs)
        .overlay(
            Rectangle()
                .fill(DS.Colors.cardBorder)
                .frame(height: 0.5),
            alignment: .top
        )
    }

    // MARK: - Pressure badge

    private var pressureBadge: some View {
        let p = vm.memoryData.pressure
        return HStack(spacing: 4) {
            Circle().fill(Color(hex: p.color)).frame(width: 6, height: 6)
            Text(p.rawValue)
                .font(DS.Fonts.micro())
                .foregroundColor(Color(hex: p.color))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(hex: p.color).opacity(0.12)))
    }
}

// MARK: - Preview

#Preview {
    MemoryRingCard(vm: DashboardViewModel())
        .padding()
        .background(DS.Colors.primaryBackground)
        .frame(width: 600, height: 260)
}
