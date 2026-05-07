import AppKit
import SwiftUI
import Combine

// MARK: - AppDelegate
// Owns the NSStatusItem + NSPopover so we have full control over
// the status-bar width — SwiftUI's MenuBarExtra label never resizes
// correctly when multiple metrics are toggled on/off.

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Set by moniqApp.onAppear before configure() is called
    var dashVM:     DashboardViewModel?
    var settingsVM: SettingsViewModel?
    var theme:      AppTheme?

    private var statusItem:  NSStatusItem?
    private var hostingView: NSHostingView<MenuBarStatusView>?
    private var popover:     NSPopover?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false   // keep running in the menu bar after the window is closed
    }

    // MARK: - Configure (called from moniqApp once @StateObjects are ready)

    func configure() {
        guard let dashVM, let settingsVM, let theme else { return }
        guard statusItem == nil else { return }   // only once

        setupStatusItem(dashVM: dashVM, settingsVM: settingsVM)
        setupPopover(dashVM: dashVM, theme: theme)
    }

    // MARK: - Status Item

    private func setupStatusItem(dashVM: DashboardViewModel,
                                 settingsVM: SettingsViewModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        let view = MenuBarStatusView(vm: dashVM, settings: settingsVM)
        let hv   = NSHostingView(rootView: view)
        hv.translatesAutoresizingMaskIntoConstraints = false
        // Force dark appearance so SwiftUI colour literals (white, accent, etc.)
        // render correctly — the menu bar button inherits a "vibrant light"
        // appearance by default which makes our colours render black.
        hv.appearance = NSAppearance(named: .darkAqua)
        button.addSubview(hv)
        NSLayoutConstraint.activate([
            hv.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 4),
            hv.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        self.hostingView = hv

        button.action = #selector(handleClick)
        button.target  = self

        // Re-measure whenever any menu-bar toggle or colour mode changes
        Publishers.Merge(
            Publishers.Merge4(
                settingsVM.$menuBarShowCPU.map     { _ in () },
                settingsVM.$menuBarShowMemory.map  { _ in () },
                settingsVM.$menuBarShowBattery.map { _ in () },
                settingsVM.$menuBarShowNetwork.map { _ in () }
            ),
            settingsVM.$menuBarColoured.map { _ in () }
        )
        .debounce(for: .milliseconds(80), scheduler: RunLoop.main)
        .sink { [weak self] _ in self?.resizeStatusItem() }
        .store(in: &cancellables)

        // Initial sizing — defer so the hosting view has been laid out
        DispatchQueue.main.async { self.resizeStatusItem() }
    }

    private func resizeStatusItem() {
        guard let hv = hostingView, let button = statusItem?.button else { return }
        hv.layoutSubtreeIfNeeded()
        let fit = hv.fittingSize
        let w   = max(fit.width + 20, 30)
        statusItem?.length = w
        hv.frame = NSRect(x: 4,
                          y: ((button.frame.height - fit.height) / 2).rounded(),
                          width: fit.width,
                          height: fit.height)
    }

    // MARK: - Popover

    private func setupPopover(dashVM: DashboardViewModel, theme: AppTheme) {
        let content = MenuBarPopoverView(dashVM: dashVM) { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows
                .first { $0.identifier?.rawValue == "main" }?
                .makeKeyAndOrderFront(nil)
            self?.popover?.close()
        }
        .environmentObject(theme)

        let pop = NSPopover()
        pop.contentSize           = NSSize(width: 320, height: 380)
        pop.behavior              = .transient
        pop.animates              = true
        pop.contentViewController = NSHostingController(rootView: content)
        self.popover = pop
    }

    @objc private func handleClick() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.close()
        } else {
            NSApp.activate(ignoringOtherApps: false)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
