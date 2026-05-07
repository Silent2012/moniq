import Foundation
import Combine
import SwiftUI
import ServiceManagement

// MARK: - Chart Style
enum ChartStyle: String, CaseIterable, Identifiable {
    case filled  = "Filled"
    case line    = "Line"
    case stepped = "Stepped"
    var id: String { rawValue }
}

// MARK: - Animation Speed
enum AnimSpeed: String, CaseIterable, Identifiable {
    case reduced = "Reduced"
    case normal  = "Normal"
    case full    = "Full"
    var id: String { rawValue }
}

// MARK: - SettingsViewModel

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - General
    @Published var launchAtLogin: Bool = false {
        didSet { applyLaunchAtLogin(); save(launchAtLogin, key: DefaultsKey.launchAtLogin) }
    }
    @Published var updateIntervalIndex: Int = 1 {   // default 2 s
        didSet { save(updateIntervalIndex, key: DefaultsKey.updateInterval) }
    }
    @Published var showInMenuBar: Bool = true {
        didSet { save(showInMenuBar, key: DefaultsKey.showInMenuBar) }
    }
    @Published var showInDock: Bool = true {
        didSet { save(showInDock, key: DefaultsKey.showInDock) }
    }

    // MARK: - Alerts
    @Published var cpuAlertThreshold: Double = 80 {
        didSet { save(cpuAlertThreshold, key: DefaultsKey.cpuAlertThreshold) }
    }
    @Published var memAlertThreshold: Double = 85 {
        didSet { save(memAlertThreshold, key: DefaultsKey.memAlertThreshold) }
    }
    @Published var batteryAlertLevel: Double = 20 {
        didSet { save(batteryAlertLevel, key: DefaultsKey.batteryAlertLevel) }
    }
    @Published var networkSpikeAlert: Bool = true {
        didSet { save(networkSpikeAlert, key: DefaultsKey.networkSpikeAlert) }
    }

    // MARK: - Menu Bar Display
    @Published var menuBarShowCPU: Bool = true {
        didSet { save(menuBarShowCPU, key: DefaultsKey.menuBarShowCPU) }
    }
    @Published var menuBarShowMemory: Bool = false {
        didSet { save(menuBarShowMemory, key: DefaultsKey.menuBarShowMemory) }
    }
    @Published var menuBarShowBattery: Bool = true {
        didSet { save(menuBarShowBattery, key: DefaultsKey.menuBarShowBattery) }
    }
    @Published var menuBarShowNetwork: Bool = false {
        didSet { save(menuBarShowNetwork, key: DefaultsKey.menuBarShowNetwork) }
    }
    @Published var menuBarColoured: Bool = true {
        didSet { save(menuBarColoured, key: DefaultsKey.menuBarColoured) }
    }

    // MARK: - Data
    @Published var dataRetentionDays: Int = 30 {
        didSet { save(dataRetentionDays, key: DefaultsKey.dataRetentionDays) }
    }
    @Published var showClearConfirmation = false
    @Published var exportSuccessMessage: String?

    let updateIntervalOptions: [(label: String, value: TimeInterval)] = [
        ("1 second", 1), ("2 seconds", 2), ("5 seconds", 5)
    ]

    var currentUpdateInterval: TimeInterval {
        updateIntervalOptions[updateIntervalIndex].value
    }

    // MARK: - Init
    init() { load() }

    // MARK: - Load / Save
    private func load() {
        let d = UserDefaults.standard
        launchAtLogin       = d.bool(forKey: DefaultsKey.launchAtLogin)
        updateIntervalIndex = d.object(forKey: DefaultsKey.updateInterval) as? Int ?? 1
        showInMenuBar       = d.object(forKey: DefaultsKey.showInMenuBar) as? Bool ?? true
        showInDock          = d.object(forKey: DefaultsKey.showInDock)    as? Bool ?? true
        cpuAlertThreshold   = d.object(forKey: DefaultsKey.cpuAlertThreshold) as? Double ?? 80
        memAlertThreshold   = d.object(forKey: DefaultsKey.memAlertThreshold) as? Double ?? 85
        batteryAlertLevel   = d.object(forKey: DefaultsKey.batteryAlertLevel) as? Double ?? 20
        networkSpikeAlert   = d.object(forKey: DefaultsKey.networkSpikeAlert) as? Bool ?? true
        dataRetentionDays   = d.object(forKey: DefaultsKey.dataRetentionDays) as? Int ?? 30
        menuBarShowCPU      = d.object(forKey: DefaultsKey.menuBarShowCPU)     as? Bool ?? true
        menuBarShowMemory   = d.object(forKey: DefaultsKey.menuBarShowMemory)  as? Bool ?? false
        menuBarShowBattery  = d.object(forKey: DefaultsKey.menuBarShowBattery) as? Bool ?? true
        menuBarShowNetwork  = d.object(forKey: DefaultsKey.menuBarShowNetwork) as? Bool ?? false
        menuBarColoured     = d.object(forKey: DefaultsKey.menuBarColoured)    as? Bool ?? true
    }

    private func save<T>(_ value: T, key: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    // MARK: - Launch at login
    private func applyLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Silently fail — user might not have granted permission
            }
        }
    }

    // MARK: - Export
    func exportData(format: ExportFormat) {
        guard let url = buildExportURL(format: format) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "moniq-export.\(format.rawValue)"
        panel.allowedContentTypes = [format == .csv ? .commaSeparatedText : .json]
        panel.begin { [weak self] response in
            guard response == .OK, let dest = panel.url else { return }
            do {
                try FileManager.default.copyItem(at: url, to: dest)
                self?.exportSuccessMessage = "Exported successfully!"
            } catch {
                self?.exportSuccessMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func buildExportURL(format: ExportFormat) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let file = tempDir.appendingPathComponent("moniq-export.\(format.rawValue)")
        let content = "# moniq export\n# Generated: \(Date())\n"
        try? content.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    // MARK: - Clear history
    func clearAllHistory() {
        UserDefaults.standard.removeObject(forKey: DefaultsKey.appUsageData)
        UserDefaults.standard.removeObject(forKey: "batteryHistory")
        showClearConfirmation = false
    }
}

enum ExportFormat: String {
    case csv, json
}
