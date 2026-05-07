import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Layout.sectionGap) {
                // Section 1: Hero metrics row
                HeroMetricsRow(vm: vm)
                    .frame(maxWidth: .infinity)
                    .slideUpOnAppear(delay: 0)

                // Section 2: CPU detail full-width
                CPUDetailCard(vm: vm)
                    .slideUpOnAppear(delay: 0.1)

                // Section 3: Memory ring
                MemoryRingCard(vm: vm)
                    .slideUpOnAppear(delay: 0.15)

                // Section 4: Network + Disk side by side
                HStack(spacing: DS.Layout.cardGap) {
                    NetworkCard(vm: vm)
                    DiskCard(vm: vm)
                }
                .slideUpOnAppear(delay: 0.2)

                // Section 5: Top processes
                TopProcessesTable(vm: vm)
                    .slideUpOnAppear(delay: 0.25)
            }
            .padding(DS.Layout.contentPadding)
        }
        .background(DS.Colors.primaryBackground)
    }
}

// MARK: - Preview

#Preview {
    DashboardView(vm: DashboardViewModel())
        .frame(width: 960, height: 800)
}
