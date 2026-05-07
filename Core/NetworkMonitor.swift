import Foundation
import Combine
import Network
import Darwin

// MARK: - NetworkMonitor
// Tracks bandwidth by computing byte-count deltas from getifaddrs.
// getifaddrs runs on a background thread; only @Published updates touch the main actor.

@MainActor
final class NetworkMonitor: ObservableObject {

    // MARK: - Published
    @Published var networkData: NetworkData = .zero
    @Published var downloadHistory: [Double] = Array(repeating: 0, count: AppConstants.History.sparklinePoints)
    @Published var uploadHistory:   [Double] = Array(repeating: 0, count: AppConstants.History.sparklinePoints)
    @Published var samples: [NetworkSample] = []

    // MARK: - Private
    private var timerCancellable: AnyCancellable?
    private var previousBytesIn:  UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var lastReadTime: Date = Date()
    private var sessionDownload: UInt64 = 0
    private var sessionUpload:   UInt64 = 0

    private let pathMonitor = NWPathMonitor()
    var currentPath: NWPath?

    init() {
        setupPathMonitor()
        startMonitoring(interval: AppConstants.Interval.normal)
    }

    deinit {
        timerCancellable?.cancel()
        pathMonitor.cancel()
    }

    // MARK: - Path monitoring
    private func setupPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.currentPath = path }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .background))
    }

    func startMonitoring(interval: TimeInterval) {
        timerCancellable?.cancel()
        timerCancellable = Timer
            .publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        tick()
    }

    func setInterval(_ interval: TimeInterval) {
        startMonitoring(interval: interval)
    }

    // MARK: - Tick
    private func tick() {
        // Capture mutable counters on main before going to background
        let prevIn   = previousBytesIn
        let prevOut  = previousBytesOut
        let lastT    = lastReadTime
        let sessDL   = sessionDownload
        let sessUL   = sessionUpload

        Task.detached(priority: .utility) { [weak self] in
            let (bytesIn, bytesOut, iface, isWifi) = NetworkMonitor.getNetworkBytes()
            let now     = Date()
            let elapsed = now.timeIntervalSince(lastT)
            guard elapsed > 0 else { return }

            var dlSpeed: Double = 0
            var ulSpeed: Double = 0
            var newDL = sessDL
            var newUL = sessUL

            if prevIn > 0 && bytesIn >= prevIn {
                let delta = bytesIn - prevIn
                dlSpeed = Double(delta) / elapsed
                newDL  += delta
            }
            if prevOut > 0 && bytesOut >= prevOut {
                let delta = bytesOut - prevOut
                ulSpeed = Double(delta) / elapsed
                newUL  += delta
            }

            let data = NetworkData(
                downloadSpeed: max(0, dlSpeed),
                uploadSpeed:   max(0, ulSpeed),
                totalDownload: newDL,
                totalUpload:   newUL,
                interfaceName: iface,
                isWifi:        isWifi,
                timestamp:     now
            )
            let sample = NetworkSample(timestamp: now, download: dlSpeed, upload: ulSpeed)

            // Capture computed values as immutable lets before crossing actor boundary
            let finalDL = dlSpeed, finalUL = ulSpeed
            let finalNewDL = newDL, finalNewUL = newUL

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.previousBytesIn  = bytesIn
                self.previousBytesOut = bytesOut
                self.lastReadTime     = now
                self.sessionDownload  = finalNewDL
                self.sessionUpload    = finalNewUL
                self.networkData      = data

                self.downloadHistory.append(finalDL)
                self.uploadHistory.append(finalUL)
                if self.downloadHistory.count > AppConstants.History.sparklinePoints {
                    self.downloadHistory.removeFirst()
                }
                if self.uploadHistory.count > AppConstants.History.sparklinePoints {
                    self.uploadHistory.removeFirst()
                }

                let finalSample = sample
                self.samples.append(finalSample)
                if self.samples.count > AppConstants.History.chartPoints {
                    self.samples.removeFirst()
                }
            }
        }
    }

    // MARK: - getifaddrs byte counters (background-safe)

    nonisolated static func getNetworkBytes()
        -> (inBytes: UInt64, outBytes: UInt64, iface: String, isWifi: Bool)
    {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0 else { return (0, 0, "", false) }
        defer { freeifaddrs(ifaddrPtr) }

        var totalIn:  UInt64 = 0
        var totalOut: UInt64 = 0
        var primaryIface = ""
        var isWifi = false
        var en0In:  UInt64 = 0
        var en0Out: UInt64 = 0

        var ptr = ifaddrPtr
        while let current = ptr {
            let addr = current.pointee
            if addr.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: addr.ifa_name)
                guard name != "lo0" else { ptr = addr.ifa_next; continue }

                if let data = addr.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    let d = data.pointee
                    totalIn  += UInt64(d.ifi_ibytes)
                    totalOut += UInt64(d.ifi_obytes)

                    if name == "en0" {
                        en0In  = UInt64(d.ifi_ibytes)
                        en0Out = UInt64(d.ifi_obytes)
                        primaryIface = name
                        isWifi = true
                    } else if name.hasPrefix("en") && primaryIface.isEmpty {
                        primaryIface = name
                    }
                }
            }
            ptr = addr.ifa_next
        }

        if en0In > 0 || en0Out > 0 {
            return (en0In, en0Out, primaryIface, isWifi)
        }
        return (totalIn, totalOut, primaryIface, false)
    }

    // MARK: - Helpers
    var activeInterfaceName: String {
        if let path = currentPath, path.usesInterfaceType(.wifi)          { return "Wi-Fi"    }
        if let path = currentPath, path.usesInterfaceType(.wiredEthernet) { return "Ethernet" }
        return networkData.interfaceName.isEmpty ? "Unknown" : networkData.interfaceName
    }

    var isConnected: Bool { currentPath?.status == .satisfied }
}
