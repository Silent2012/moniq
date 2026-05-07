import SwiftUI

// MARK: - ContentView
// Main layout: custom sidebar + content area with custom title bar

struct ContentView: View {
    @ObservedObject var dashVM:     DashboardViewModel
    @ObservedObject var settingsVM: SettingsViewModel
    @StateObject private var tracker = AppUsageTracker()
    @EnvironmentObject var theme: AppTheme

    @State private var selection: NavItem = .dashboard
    @State private var sidebarVisible = true

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            if sidebarVisible {
                SidebarView(selection: $selection, sidebarVisible: $sidebarVisible, vm: dashVM)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))
            }

            // Main content
            VStack(spacing: 0) {
                // Custom title bar
                CustomTitleBar(
                    title: selection.rawValue,
                    sidebarVisible: $sidebarVisible
                )

                // Page content
                ZStack {
                    DS.Colors.primaryBackground.ignoresSafeArea()
                    pageContent
                        .environmentObject(settingsVM)
                }
                .animation(DS.Animations.navCrossfade, value: selection)
            }
        }
        .background(DS.Colors.primaryBackground)
        .frame(
            minWidth:  DS.Layout.minWindowWidth,
            minHeight: DS.Layout.minWindowHeight
        )
        .preferredColorScheme(.dark)
        .accentColor(theme.primaryAccent)
    }

    // MARK: - Page routing

    @ViewBuilder
    private var pageContent: some View {
        switch selection {
        case .dashboard:
            DashboardView(vm: dashVM)
                .id(NavItem.dashboard)

        case .cpu:
            CPUMemoryView(vm: dashVM)
                .id(NavItem.cpu)

        case .appUsage:
            AppUsageView(tracker: tracker)
                .id(NavItem.appUsage)

        case .network:
            NetworkDetailView(vm: dashVM)
                .id(NavItem.network)

        case .battery:
            BatteryView(monitor: dashVM.batteryMonitor)
                .id(NavItem.battery)

        case .analytics:
            AnalyticsView(vm: dashVM)
                .id(NavItem.analytics)

        case .settings:
            SettingsView(vm: settingsVM)
                .id(NavItem.settings)

        case .alerts:
            AlertsView()
                .id(NavItem.alerts)
        }
    }
}

// MARK: - CustomTitleBar

struct CustomTitleBar: View {
    let title: String
    @Binding var sidebarVisible: Bool

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                // Sidebar is visible: no toggle here, just leave space for the
                // title bar divider to sit flush against the sidebar edge.
                Color.clear.frame(width: DS.Spacing.md)
            } else {
                // Traffic light zone (macOS overlays native buttons here)
                Color.clear.frame(width: 80)

                // Sidebar expand toggle — only shown when sidebar is hidden
                Button {
                    withAnimation(DS.Animations.spring) { sidebarVisible.toggle() }
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DS.Colors.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(DS.Colors.cardBorder.opacity(0.4)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.leading, DS.Spacing.sm)
                .help("Show sidebar")
            }

            Spacer()

            // Title
            Text(title)
                .font(DS.Fonts.cardTitle())
                .foregroundColor(DS.Colors.secondaryText)

            Spacer()

            // Right zone placeholder (balances the title)
            Color.clear
                .frame(width: sidebarVisible ? DS.Spacing.md : 120)
        }
        .frame(height: DS.Layout.titleBarHeight)
        .background(DS.Colors.primaryBackground)
        .overlay(
            Divider().background(DS.Colors.cardBorder),
            alignment: .bottom
        )
        // Make the title bar draggable
        .gesture(
            WindowDragGesture()
        )
    }
}

// MARK: - WindowDragGesture (AppKit bridge)

private struct WindowDragGesture: Gesture {
    var body: some Gesture {
        DragGesture()
            .onChanged { _ in
                NSApp.keyWindow?.performDrag(with: NSApp.currentEvent ?? NSEvent())
            }
    }
}

// MARK: - CPU + Memory combined view (for sidebar "CPU & Memory" item)

struct CPUMemoryView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Layout.sectionGap) {
                CPUDetailCard(vm: vm)
                    .slideUpOnAppear(delay: 0)
                MemoryRingCard(vm: vm)
                    .slideUpOnAppear(delay: 0.08)
                TopProcessesTable(vm: vm)
                    .slideUpOnAppear(delay: 0.14)
            }
            .padding(DS.Layout.contentPadding)
        }
        .background(DS.Colors.primaryBackground)
    }
}

// MARK: - Network detail view (for sidebar "Network" item)

struct NetworkDetailView: View {
    @ObservedObject var vm: DashboardViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Layout.sectionGap) {
                NetworkCard(vm: vm)
                    .slideUpOnAppear(delay: 0)
                DiskCard(vm: vm)
                    .slideUpOnAppear(delay: 0.08)
            }
            .padding(DS.Layout.contentPadding)
        }
        .background(DS.Colors.primaryBackground)
    }
}

// MARK: - Alerts view placeholder

struct AlertsView: View {
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundColor(DS.Colors.cardBorder)

            Text("No alerts")
                .font(DS.Fonts.sectionTitle())
                .foregroundColor(DS.Colors.secondaryText)

            Text("Configure thresholds in Settings to receive alerts when metrics exceed your limits.")
                .font(DS.Fonts.body())
                .foregroundColor(DS.Colors.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.primaryBackground)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .frame(width: DS.Layout.defaultWindowWidth, height: DS.Layout.defaultWindowHeight)
}
