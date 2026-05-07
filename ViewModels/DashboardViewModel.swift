import Foundation
import Combine
import AppKit

// MARK: - DashboardViewModel

@MainActor
final class DashboardViewModel: ObservableObject {

    // MARK: - Sub-monitors
    let systemMonitor     = SystemMonitor()
    let batteryMonitor    = BatteryMonitor()
    let networkMonitor    = NetworkMonitor()
    let diskMonitor       = DiskMonitor()
    let analyticsRecorder = AnalyticsRecorder()

    // MARK: - Passthrough Published (for convenience in views)
    @Published var cpuData:    CPUData    = .zero
    @Published var memoryData: MemoryData = .zero
    @Published var networkData:NetworkData = .zero
    @Published var diskData:   DiskData   = .zero
    @Published var batteryData:BatteryData = .zero
    @Published var processes:  [ProcessItem] = []

    @Published var cpuHistory:      [Double] = Array(repeating: 0, count: 60)
    @Published var memHistory:      [Double] = Array(repeating: 0, count: 60)
    @Published var downloadHistory: [Double] = Array(repeating: 0, count: 60)
    @Published var uploadHistory:   [Double] = Array(repeating: 0, count: 60)

    @Published var sortByMemory = false
    @Published var selectedProcess: ProcessItem?

    private var cancellables = Set<AnyCancellable>()

    init() {
        bindMonitors()
    }

    /// Call once from moniqApp.onAppear after both StateObjects are ready.
    func configure(settings: SettingsViewModel) {
        settings.$updateIntervalIndex
            .map { _ in settings.currentUpdateInterval }
            .removeDuplicates()
            .sink { [weak self] interval in
                guard let self else { return }
                self.systemMonitor.setInterval(interval)
                self.networkMonitor.setInterval(interval)
                self.diskMonitor.setInterval(interval)
            }
            .store(in: &cancellables)

        // Start 30-second analytics sampling
        analyticsRecorder.start(
            cpuPublisher:    $cpuData.map(\.usage).eraseToAnyPublisher(),
            memoryPublisher: $memoryData.map(\.usagePercent).eraseToAnyPublisher()
        )
    }

    private func bindMonitors() {
        systemMonitor.$cpuData
            .assign(to: &$cpuData)
        systemMonitor.$memoryData
            .assign(to: &$memoryData)
        systemMonitor.$processes
            .map { [weak self] procs -> [ProcessItem] in
                guard let self else { return procs }
                return self.sortByMemory
                    ? procs.sorted { $0.memoryBytes > $1.memoryBytes }
                    : procs.sorted { $0.cpuPercent  > $1.cpuPercent }
            }
            .assign(to: &$processes)
        systemMonitor.$cpuHistory
            .assign(to: &$cpuHistory)
        systemMonitor.$memHistory
            .assign(to: &$memHistory)

        batteryMonitor.$batteryData
            .assign(to: &$batteryData)
        networkMonitor.$networkData
            .assign(to: &$networkData)
        networkMonitor.$downloadHistory
            .assign(to: &$downloadHistory)
        networkMonitor.$uploadHistory
            .assign(to: &$uploadHistory)
        diskMonitor.$diskData
            .assign(to: &$diskData)

        $sortByMemory
            .sink { [weak self] _ in
                guard let self else { return }
                self.processes = self.sortByMemory
                    ? self.processes.sorted { $0.memoryBytes > $1.memoryBytes }
                    : self.processes.sorted { $0.cpuPercent  > $1.cpuPercent }
            }
            .store(in: &cancellables)
    }

    // MARK: - Process actions
    func killProcess(_ item: ProcessItem) {
        let pid = item.id
        kill(pid, SIGKILL)
    }

    // MARK: - CPU chart data
    var cpuChartPoints: [(index: Int, value: Double)] {
        cpuHistory.enumerated().map { ($0.offset, $0.element) }
    }

    // MARK: - Uptime
    var uptimeString: String {
        Formatters.uptime(ProcessInfo.processInfo.systemUptime)
    }

    // MARK: - CPU status pills
    var cpuPills: [(label: String, value: Double, color: String)] {
        [
            ("User",   cpuData.userPercent,   "#00D4FF"),
            ("System", cpuData.systemPercent, "#FF6B9D"),
            ("Idle",   cpuData.idlePercent,   "#00FF88")
        ]
    }
}
