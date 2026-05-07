import Foundation
import Combine
import IOKit
import IOKit.ps

// MARK: - BatteryMonitor
// Reads battery data via IOKit registry (AppleSmartBattery + IOPMPowerSource)

@MainActor
final class BatteryMonitor: ObservableObject {

    // MARK: - Published
    @Published var batteryData: BatteryData = .zero
    @Published var history: [BatteryHistoryPoint] = []
    @Published var isAvailable = true

    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadHistory()
        update()
        startMonitoring()
    }

    deinit { cancellables.forEach { $0.cancel() } }

    // MARK: - Monitoring
    private func startMonitoring() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)
    }

    // MARK: - Update
    func update() {
        guard let data = readBatteryData() else {
            isAvailable = false
            return
        }
        isAvailable = true
        batteryData = data

        let point = BatteryHistoryPoint(
            percentage: Double(data.currentCapacity),
            isCharging: data.isCharging
        )
        history.append(point)

        let maxPoints = 2880
        if history.count > maxPoints { history = Array(history.suffix(maxPoints)) }
        saveHistory()
    }

    // MARK: - Read battery data
    // Uses IOPSCopyPowerSourcesInfo for the accurate percentage + charge state
    // (IOPMPowerSource's CurrentCapacity is raw mAh on Apple Silicon, not %)
    // Uses AppleSmartBattery for cycle count, health, temperature, voltage.

    private func readBatteryData() -> BatteryData? {
        // ── Percentage, charge state, time estimates (IOPowerSources) ──
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list     = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as [CFTypeRef]

        var currentPct   = 0
        var isCharging   = false
        var isPluggedIn  = false
        var timeToEmpty  = -1
        var timeToFull   = -1
        var foundBattery = false

        for psRef in list {
            guard let info = IOPSGetPowerSourceDescription(snapshot, psRef)?
                                 .takeUnretainedValue() as? [String: Any] else { continue }
            // Only consider internal battery sources
            guard (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }

            // kIOPSCurrentCapacityKey is always a percentage 0–100
            currentPct   = info[kIOPSCurrentCapacityKey]   as? Int  ?? 0
            isCharging   = info[kIOPSIsChargingKey]         as? Bool ?? false
            let state    = info[kIOPSPowerSourceStateKey]   as? String ?? ""
            isPluggedIn  = (state == kIOPSACPowerValue)
            timeToEmpty  = info[kIOPSTimeToEmptyKey]        as? Int  ?? -1
            timeToFull   = info[kIOPSTimeToFullChargeKey]   as? Int  ?? -1
            foundBattery = true
            break
        }

        guard foundBattery else { return nil }

        // ── Detailed stats from AppleSmartBattery (cycle count, health, temp) ──
        var cycleCount     = 0
        var designCapacity = 0
        var maxCapacitymAh = 0
        var temperature    = 0.0
        var voltage        = 0.0
        var amperage       = 0

        let smartSvc = IOServiceGetMatchingService(kIOMainPortDefault,
                                                  IOServiceMatching("AppleSmartBattery"))
        if smartSvc != IO_OBJECT_NULL {
            defer { IOObjectRelease(smartSvc) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(smartSvc, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
               let d = props?.takeRetainedValue() as? [String: Any] {
                cycleCount      = d["CycleCount"]          as? Int ?? 0
                designCapacity  = d["DesignCapacity"]     as? Int ?? 0
                // "MaxCapacity" on Apple Silicon is always 100 (a normalised %).
                // "AppleRawMaxCapacity" is the real full-charge capacity in mAh.
                maxCapacitymAh  = d["AppleRawMaxCapacity"] as? Int
                               ?? d["NominalChargeCapacity"] as? Int
                               ?? d["MaxCapacity"]           as? Int
                               ?? 0
                amperage        = d["Amperage"]       as? Int ?? 0
                voltage         = Double(d["Voltage"] as? Int ?? 0) / 1000.0
                if let rawTemp  = d["Temperature"]    as? Int {
                    // Stored as centi-Kelvin (×0.01 K); convert to Celsius
                    temperature = Double(rawTemp) / 100.0 - 273.15
                }
            }
        }

        let health: Double
        if designCapacity > 0, maxCapacitymAh > 0 {
            health = min(100.0, Double(maxCapacitymAh) / Double(designCapacity) * 100.0)
        } else {
            health = 100.0
        }

        return BatteryData(
            currentCapacity: currentPct,
            maxCapacity:     maxCapacitymAh,
            designCapacity:  designCapacity,
            cycleCount:      cycleCount,
            isCharging:      isCharging,
            isPluggedIn:     isPluggedIn,
            timeToEmpty:     timeToEmpty,
            timeToFull:      timeToFull,
            temperature:     temperature,
            voltage:         voltage,
            amperage:        amperage,
            health:          health
        )
    }

    // MARK: - Persistence
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "batteryHistory"),
              let decoded = try? JSONDecoder().decode([BatteryHistoryPoint].self, from: data) else { return }
        let cutoff = Date().addingTimeInterval(-86400)
        history = decoded.filter { $0.timestamp > cutoff }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "batteryHistory")
        }
    }

    // MARK: - 24-hour hourly chart data
    var hourlyHistory: [(hour: Int, average: Double)] {
        guard !history.isEmpty else { return [] }
        let now = Date()
        var buckets = [Int: [Double]]()
        for point in history {
            let hoursAgo = Int(-point.timestamp.timeIntervalSince(now) / 3600)
            if hoursAgo >= 0 && hoursAgo < 24 {
                buckets[hoursAgo, default: []].append(point.percentage)
            }
        }
        return (0..<24).compactMap { h -> (Int, Double)? in
            guard let vals = buckets[h], !vals.isEmpty else { return nil }
            return (h, vals.reduce(0, +) / Double(vals.count))
        }
    }
}
