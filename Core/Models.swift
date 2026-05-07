import Foundation
import AppKit

// MARK: - CPU Models

struct CPUData {
    let usage: Double           // 0-100
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
    let coreUsages: [Double]    // per-core 0-100
    let timestamp: Date

    static let zero = CPUData(usage: 0, userPercent: 0, systemPercent: 0,
                               idlePercent: 100, coreUsages: [], timestamp: Date())
}

// MARK: - Memory Models

struct MemoryData {
    let appMemory:        UInt64  // bytes — anonymous pages (Activity Monitor "App Memory")
    let wiredMemory:      UInt64  // kernel/driver pages that can't be paged out
    let compressedMemory: UInt64  // physical footprint inside the memory compressor
    let cachedFiles:      UInt64  // file-backed pages (Activity Monitor "Cached Files")
    let freeMemory:       UInt64  // truly unallocated pages
    let totalMemory:      UInt64
    let swapUsed:         UInt64  // bytes currently written to swap file
    let swapTotal:        UInt64  // total size of the swap file (0 if swap is off)

    /// Matches Activity Monitor "Memory Used" = App + Wired + Compressed
    var usedMemory: UInt64 { appMemory + wiredMemory + compressedMemory }

    var usagePercent: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory) * 100
    }

    var pressure: MemoryPressure {
        if usagePercent > 90 { return .critical }
        if usagePercent > 75 { return .warning }
        return .normal
    }

    static let zero = MemoryData(appMemory: 0, wiredMemory: 0, compressedMemory: 0,
                                  cachedFiles: 0, freeMemory: 0, totalMemory: 0,
                                  swapUsed: 0, swapTotal: 0)
}

enum MemoryPressure: String {
    case normal   = "Normal"
    case warning  = "Warning"
    case critical = "Critical"

    var color: String {
        switch self {
        case .normal:   return "#00FF88"
        case .warning:  return "#FFB830"
        case .critical: return "#FF4757"
        }
    }
}

// MARK: - Network Models

struct NetworkData {
    let downloadSpeed: Double  // bytes/sec
    let uploadSpeed:   Double  // bytes/sec
    let totalDownload: UInt64  // total bytes today
    let totalUpload:   UInt64
    let interfaceName: String
    let isWifi:        Bool
    let timestamp:     Date

    static let zero = NetworkData(downloadSpeed: 0, uploadSpeed: 0, totalDownload: 0,
                                   totalUpload: 0, interfaceName: "", isWifi: false, timestamp: Date())
}

struct NetworkSample: Identifiable {
    let id = UUID()
    let timestamp: Date
    let download: Double
    let upload: Double
}

// MARK: - Disk Models

struct DiskData {
    let totalSpace:    UInt64
    let usedSpace:     UInt64
    let freeSpace:     UInt64
    let readSpeed:     Double   // bytes/sec
    let writeSpeed:    Double   // bytes/sec
    let volumeName:    String

    var usagePercent: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace) * 100
    }

    static let zero = DiskData(totalSpace: 0, usedSpace: 0, freeSpace: 0,
                                readSpeed: 0, writeSpeed: 0, volumeName: "Macintosh HD")
}

// MARK: - Battery Models

struct BatteryData {
    let currentCapacity:  Int     // percentage 0-100
    let maxCapacity:      Int     // mAh or percentage
    let designCapacity:   Int
    let cycleCount:       Int
    let isCharging:       Bool
    let isPluggedIn:      Bool
    let timeToEmpty:      Int     // minutes, -1 if unknown
    let timeToFull:       Int     // minutes, -1 if charging or full
    let temperature:      Double  // Celsius
    let voltage:          Double  // mV
    let amperage:         Int     // mA (positive = charging)
    let health:           Double  // 0-100%

    var healthStatus: BatteryHealth {
        if health >= AppConstants.Threshold.batteryHealthGood { return .good }
        if health >= AppConstants.Threshold.batteryHealthFair { return .fair }
        return .poor
    }

    static let zero = BatteryData(currentCapacity: 0, maxCapacity: 100, designCapacity: 100,
                                   cycleCount: 0, isCharging: false, isPluggedIn: false,
                                   timeToEmpty: -1, timeToFull: -1, temperature: 0,
                                   voltage: 0, amperage: 0, health: 100)
}

enum BatteryHealth: String {
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
}

struct BatteryHistoryPoint: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let percentage: Double
    let isCharging: Bool

    init(percentage: Double, isCharging: Bool) {
        self.id = UUID()
        self.timestamp = Date()
        self.percentage = percentage
        self.isCharging = isCharging
    }
}

// MARK: - Process Models

struct ProcessItem: Identifiable {
    let id: Int32        // PID
    let name: String
    let bundleID: String?
    let cpuPercent: Double
    let memoryBytes: UInt64
    let status: ProcessStatus
    let icon: NSImage?

    var isSystemProcess: Bool { bundleID == nil }
}

enum ProcessStatus: String {
    case running  = "Running"
    case sleeping = "Sleeping"
    case stopped  = "Stopped"
    case zombie   = "Zombie"
}

// MARK: - App Usage Models

struct AppSession: Identifiable, Codable {
    let id: UUID
    let bundleID: String
    let appName: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval { (endTime ?? Date()).timeIntervalSince(startTime) }

    init(bundleID: String, appName: String) {
        self.id = UUID()
        self.bundleID = bundleID
        self.appName = appName
        self.startTime = Date()
    }
}

struct AppUsageSummary: Identifiable {
    let id: String             // bundleID
    let bundleID: String
    let appName: String
    let icon: NSImage?
    let category: AppConstants.AppCategory
    let totalDuration: TimeInterval
    let sessionCount: Int
    let firstUsed: Date
    let lastUsed: Date
    let hourlyUsage: [Double]  // 24 values, seconds per hour

    var percentOfTotal: Double = 0
    var sparklineData: [Double] { hourlyUsage }
}

// MARK: - Analytics Models

struct MetricDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let metric: MetricType
}

enum MetricType: String, CaseIterable {
    case cpu     = "CPU"
    case memory  = "Memory"
    case network = "Network"
    case battery = "Battery"

    var color: String {
        switch self {
        case .cpu:     return "#00D4FF"
        case .memory:  return "#FF6B9D"
        case .network: return "#00FF88"
        case .battery: return "#6C63FF"
        }
    }
}

struct HeatmapCell: Identifiable {
    let id = UUID()
    let hour: Int         // 0-23
    let weekday: Int      // 1-7 (Sun-Sat)
    let value: Double     // 0-1 intensity
}

struct InsightCard: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let highlight: String     // key stat to bold
    let type: InsightType
    let timestamp: Date
}

enum InsightType {
    case cpuPeak, memoryPressure, appUsage, networkSpike, battery

    var color: String {
        switch self {
        case .cpuPeak:        return "#00D4FF"
        case .memoryPressure: return "#FF6B9D"
        case .appUsage:       return "#6C63FF"
        case .networkSpike:   return "#00FF88"
        case .battery:        return "#FFB830"
        }
    }
}

// MARK: - Navigation

enum NavItem: String, CaseIterable, Identifiable {
    case dashboard  = "Dashboard"
    case cpu        = "CPU & Memory"
    case appUsage   = "App Usage"
    case network    = "Network"
    case battery    = "Battery"
    case analytics  = "Analytics"
    case settings   = "Settings"
    case alerts     = "Alerts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .cpu:       return "cpu"
        case .appUsage:  return "square.stack.3d.up"
        case .network:   return "network"
        case .battery:   return "battery.100.bolt"
        case .analytics: return "chart.xyaxis.line"
        case .settings:  return "gearshape.fill"
        case .alerts:    return "bell.badge.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .dashboard: return "#6C63FF"
        case .cpu:       return "#00D4FF"
        case .appUsage:  return "#6C63FF"
        case .network:   return "#00FF88"
        case .battery:   return "#FFB830"
        case .analytics: return "#6C63FF"
        case .settings:  return "#8B8BA7"
        case .alerts:    return "#FF4757"
        }
    }

    var isTopGroup: Bool {
        switch self {
        case .dashboard, .cpu, .appUsage, .network, .battery, .analytics: return true
        case .settings, .alerts: return false
        }
    }
}
