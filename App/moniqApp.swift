import SwiftUI

// MARK: - moniqApp

@main
struct moniqApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Shared across main window and menu bar
    @StateObject private var dashVM     = DashboardViewModel()
    @StateObject private var theme      = AppTheme()
    @StateObject private var settingsVM = SettingsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(dashVM: dashVM, settingsVM: settingsVM)
                .environmentObject(theme)
                .onAppear {
                    // Hand the shared objects to AppDelegate so it can
                    // build the NSStatusItem + NSPopover with real data.
                    appDelegate.dashVM     = dashVM
                    appDelegate.settingsVM = settingsVM
                    appDelegate.theme      = theme
                    appDelegate.configure()
                    dashVM.configure(settings: settingsVM)
                    configureMainWindow()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        // No MenuBarExtra — the status item is owned by AppDelegate so we
        // control its width directly when metrics are added/removed.
    }

    private func configureMainWindow() {
        guard let window = NSApp.windows.first(where: {
            !($0.identifier?.rawValue.contains("menuBar") ?? false)
        }) else { return }
        window.identifier                 = NSUserInterfaceItemIdentifier("main")
        window.titlebarAppearsTransparent = true
        window.titleVisibility            = .hidden
        window.backgroundColor            = NSColor(DS.Colors.primaryBackground)
        window.isMovableByWindowBackground = false
        window.minSize = CGSize(width: DS.Layout.minWindowWidth,
                                height: DS.Layout.minWindowHeight)
        window.setContentSize(CGSize(width: DS.Layout.defaultWindowWidth,
                                     height: DS.Layout.defaultWindowHeight))
        window.center()
        window.styleMask.insert(.fullSizeContentView)
    }
}
