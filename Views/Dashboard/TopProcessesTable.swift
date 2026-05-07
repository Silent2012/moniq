import SwiftUI

// MARK: - TopProcessesTable

struct TopProcessesTable: View {
    @ObservedObject var vm: DashboardViewModel
    @State private var expandedPID: Int32?
    @State private var showKillConfirm: ProcessItem?

    var body: some View {
        GlowingCard(accentColor: DS.Colors.primaryAccent) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header row
                HStack {
                    Text("Top Processes")
                        .font(DS.Fonts.cardTitle())
                        .foregroundColor(DS.Colors.primaryText)
                    Spacer()
                    sortToggle
                }

                // Column headers
                columnHeaders

                Divider().background(DS.Colors.cardBorder)

                // Process rows
                LazyVStack(spacing: 0) {
                    ForEach(Array(vm.processes.prefix(8).enumerated()), id: \.element.id) { idx, proc in
                        ProcessRow(
                            process: proc,
                            index: idx,
                            isExpanded: expandedPID == proc.id,
                            totalMem: vm.memoryData.totalMemory
                        ) {
                            withAnimation(DS.Animations.spring) {
                                expandedPID = expandedPID == proc.id ? nil : proc.id
                            }
                        } onKill: {
                            showKillConfirm = proc
                        }

                        if idx < vm.processes.prefix(8).count - 1 {
                            Divider()
                                .background(DS.Colors.cardBorder.opacity(0.5))
                                .padding(.leading, DS.Spacing.xxl)
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Kill \(showKillConfirm?.name ?? "process")?",
            isPresented: Binding(
                get: { showKillConfirm != nil },
                set: { if !$0 { showKillConfirm = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Force Quit", role: .destructive) {
                if let p = showKillConfirm { vm.killProcess(p) }
                showKillConfirm = nil
            }
            Button("Cancel", role: .cancel) { showKillConfirm = nil }
        } message: {
            Text("This will immediately terminate the process.")
        }
    }

    // MARK: - Sort toggle

    private var sortToggle: some View {
        HStack(spacing: 0) {
            sortButton("CPU", active: !vm.sortByMemory) { vm.sortByMemory = false }
            sortButton("Memory", active: vm.sortByMemory)  { vm.sortByMemory = true  }
        }
        .background(DS.Colors.cardBorder.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DS.Colors.cardBorder, lineWidth: 0.5))
    }

    private func sortButton(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(DS.Fonts.caption())
                .foregroundColor(active ? DS.Colors.primaryText : DS.Colors.secondaryText)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 4)
                .background(
                    Group {
                        if active {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(DS.Colors.primaryAccent.opacity(0.25))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .animation(DS.Animations.spring, value: active)
    }

    // MARK: - Column headers

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            Text("Process")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU")
                .frame(width: 80, alignment: .trailing)
            Text("Memory")
                .frame(width: 100, alignment: .trailing)
            Text("PID")
                .frame(width: 70, alignment: .trailing)
            Text("Status")
                .frame(width: 80, alignment: .center)
        }
        .font(DS.Fonts.micro())
        .foregroundColor(DS.Colors.tertiaryText)
        .padding(.horizontal, DS.Spacing.xs)
    }
}

// MARK: - ProcessRow

private struct ProcessRow: View {
    let process: ProcessItem
    let index: Int
    let isExpanded: Bool
    let totalMem: UInt64
    let onTap: () -> Void
    let onKill: () -> Void

    @State private var appeared = false

    private var memPercent: Double {
        guard totalMem > 0 else { return 0 }
        return Double(process.memoryBytes) / Double(totalMem) * 100
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: onTap) {
                HStack(spacing: 0) {
                    // App name + icon
                    HStack(spacing: DS.Spacing.sm) {
                        if let icon = process.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 16))
                                .foregroundColor(DS.Colors.tertiaryText)
                                .frame(width: 24, height: 24)
                        }
                        Text(process.name)
                            .font(DS.Fonts.metricLabel())
                            .foregroundColor(DS.Colors.primaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // CPU
                    HStack(spacing: DS.Spacing.xs) {
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DS.Colors.forCPU(process.cpuPercent).opacity(0.3))
                                .frame(height: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(DS.Colors.forCPU(process.cpuPercent))
                                        .frame(
                                            width: geo.size.width * (process.cpuPercent / 100).clamped(to: 0...1),
                                            height: 4
                                        ),
                                    alignment: .leading
                                )
                        }
                        .frame(width: 36, height: 4)

                        Text(String(format: "%.1f%%", process.cpuPercent))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(DS.Colors.forCPU(process.cpuPercent))
                            .monospacedDigit()
                            .frame(width: 38, alignment: .trailing)
                    }
                    .frame(width: 80, alignment: .trailing)

                    // Memory
                    Text(Formatters.bytes(process.memoryBytes))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(DS.Colors.secondaryText)
                        .monospacedDigit()
                        .frame(width: 100, alignment: .trailing)

                    // PID
                    Text("\(process.id)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(DS.Colors.tertiaryText)
                        .frame(width: 70, alignment: .trailing)

                    // Status
                    statusDot
                        .frame(width: 80, alignment: .center)
                }
                .padding(.vertical, DS.Spacing.sm)
                .padding(.horizontal, DS.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isExpanded ? DS.Colors.hoverState : Color.clear)
                )
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isExpanded {
                processDetail
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.sm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -10)
        .onAppear {
            withAnimation(DS.Animations.stagger(index: index)) { appeared = true }
        }
    }

    private var statusDot: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
            Text(process.status.rawValue)
                .font(DS.Fonts.micro())
                .foregroundColor(DS.Colors.secondaryText)
        }
    }

    private var statusColor: Color {
        switch process.status {
        case .running:  return DS.Colors.successGreen
        case .sleeping: return DS.Colors.secondaryText
        case .stopped:  return DS.Colors.warningAmber
        case .zombie:   return DS.Colors.dangerRed
        }
    }

    private var processDetail: some View {
        HStack(spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                detailRow("PID",    "\(process.id)")
                detailRow("Memory", Formatters.bytes(process.memoryBytes))
                detailRow("CPU",    String(format: "%.2f%%", process.cpuPercent))
            }

            Spacer()

            Button(action: onKill) {
                Label("Force Quit", systemImage: "xmark.circle.fill")
                    .font(DS.Fonts.caption())
                    .foregroundColor(DS.Colors.dangerRed)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(Capsule().fill(DS.Colors.dangerRed.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(DS.Colors.dangerRed.opacity(0.3), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.sm)
        .background(RoundedRectangle(cornerRadius: 8).fill(DS.Colors.primaryBackground))
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(DS.Fonts.micro())
                .foregroundColor(DS.Colors.tertiaryText)
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(DS.Colors.secondaryText)
                .monospacedDigit()
        }
    }
}

// MARK: - Preview

#Preview {
    TopProcessesTable(vm: DashboardViewModel())
        .padding()
        .background(DS.Colors.primaryBackground)
        .frame(width: 800)
}
