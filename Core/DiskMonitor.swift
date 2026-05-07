import Foundation
import Combine
import IOKit
import IOKit.storage

// MARK: - DiskMonitor
// Uses URLResourceValues for capacity and IOKit for read/write activity.
// IOKit traversal runs on a background thread; only @Published updates touch the main actor.

@MainActor
final class DiskMonitor: ObservableObject {

    // MARK: - Published
    @Published var diskData:     DiskData = .zero
    @Published var readHistory:  [Double] = Array(repeating: 0, count: AppConstants.History.sparklinePoints)
    @Published var writeHistory: [Double] = Array(repeating: 0, count: AppConstants.History.sparklinePoints)

    // MARK: - Private
    private var timerCancellable: AnyCancellable?
    private var prevReadBytes:  UInt64 = 0
    private var prevWriteBytes: UInt64 = 0
    private var lastTime: Date = Date()

    init() {
        // Disk I/O doesn't need sub-second resolution; 2 s is plenty.
        startMonitoring(interval: max(AppConstants.Interval.normal, 2.0))
    }

    deinit { timerCancellable?.cancel() }

    func startMonitoring(interval: TimeInterval) {
        timerCancellable?.cancel()
        // Disk never needs to run faster than 2 s
        let clamped = max(interval, 2.0)
        timerCancellable = Timer
            .publish(every: clamped, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        tick()
    }

    func setInterval(_ interval: TimeInterval) {
        startMonitoring(interval: interval)
    }

    // MARK: - Tick
    private func tick() {
        let prevR = prevReadBytes
        let prevW = prevWriteBytes
        let lastT = lastTime

        Task.detached(priority: .utility) { [weak self] in
            let (total, used, free, name) = DiskMonitor.collectStorage()
            let (readSpeed, writeSpeed, newR, newW, now) =
                DiskMonitor.collectIO(prevRead: prevR, prevWrite: prevW, lastTime: lastT)

            let data = DiskData(
                totalSpace:  total,
                usedSpace:   used,
                freeSpace:   free,
                readSpeed:   readSpeed,
                writeSpeed:  writeSpeed,
                volumeName:  name
            )

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.prevReadBytes  = newR
                self.prevWriteBytes = newW
                self.lastTime       = now
                self.diskData       = data

                self.readHistory.append(readSpeed)
                self.writeHistory.append(writeSpeed)
                if self.readHistory.count  > AppConstants.History.sparklinePoints { self.readHistory.removeFirst()  }
                if self.writeHistory.count > AppConstants.History.sparklinePoints { self.writeHistory.removeFirst() }
            }
        }
    }

    // MARK: - Storage (background-safe)

    nonisolated static func collectStorage()
        -> (total: UInt64, used: UInt64, free: UInt64, name: String)
    {
        let url  = URL(fileURLWithPath: "/")
        let keys: Set<URLResourceKey> = [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeNameKey,
        ]
        guard let res = try? url.resourceValues(forKeys: keys) else {
            return (0, 0, 0, "Macintosh HD")
        }
        let total     = UInt64(res.volumeTotalCapacity ?? 0)
        let available = UInt64(res.volumeAvailableCapacityForImportantUsage ?? 0)
        let used      = total > available ? total - available : 0
        return (total, used, available, res.volumeName ?? "Macintosh HD")
    }

    // MARK: - Disk I/O via IOKit (background-safe)

    nonisolated static func collectIO(
        prevRead: UInt64, prevWrite: UInt64, lastTime: Date
    ) -> (readSpeed: Double, writeSpeed: Double,
          newRead: UInt64, newWrite: UInt64, now: Date)
    {
        let now     = Date()
        let elapsed = now.timeIntervalSince(lastTime)
        guard elapsed > 0.1 else { return (0, 0, prevRead, prevWrite, now) }

        var totalRead:  UInt64 = 0
        var totalWrite: UInt64 = 0

        let matching = IOServiceMatching("IOBlockStorageDriver") as! [String: Any]
        var iter: io_iterator_t = IO_OBJECT_NULL
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault, matching as CFDictionary, &iter
        ) == kIOReturnSuccess else {
            return (0, 0, prevRead, prevWrite, now)
        }
        defer { IOObjectRelease(iter) }

        var service = IOIteratorNext(iter)
        while service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service); service = IOIteratorNext(iter) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                  let dict  = props?.takeRetainedValue() as? [String: Any],
                  let stats = dict["Statistics"] as? [String: Any] else { continue }
            totalRead  += (stats["Bytes (Read)"]  as? UInt64) ?? 0
            totalWrite += (stats["Bytes (Write)"] as? UInt64) ?? 0
        }

        var readSpeed:  Double = 0
        var writeSpeed: Double = 0
        if prevRead  > 0 && totalRead  >= prevRead  { readSpeed  = Double(totalRead  - prevRead)  / elapsed }
        if prevWrite > 0 && totalWrite >= prevWrite { writeSpeed = Double(totalWrite - prevWrite) / elapsed }

        return (max(0, readSpeed), max(0, writeSpeed), totalRead, totalWrite, now)
    }
}
