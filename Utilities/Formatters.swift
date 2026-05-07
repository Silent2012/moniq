import Foundation

// MARK: - Formatters

enum Formatters {

    // MARK: - Bytes
    static func bytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1_024
        let mb = kb / 1_024
        let gb = mb / 1_024
        let tb = gb / 1_024
        if tb >= 1   { return String(format: "%.2f TB", tb) }
        if gb >= 1   { return String(format: "%.2f GB", gb) }
        if mb >= 0.1 { return String(format: "%.1f MB", mb) }
        if kb >= 0.1 { return String(format: "%.1f KB", kb) }
        return "\(bytes) B"
    }

    static func bytesShort(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1_024 * 1_024)
        let gb = mb / 1_024
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", mb)
    }

    static func networkSpeed(_ bytesPerSec: Double) -> String {
        let kbps = bytesPerSec / 1_024
        let mbps = kbps / 1_024
        let gbps = mbps / 1_024
        if gbps >= 1   { return String(format: "%.2f GB/s", gbps) }
        if mbps >= 0.1 { return String(format: "%.1f MB/s", mbps) }
        if kbps >= 0.1 { return String(format: "%.0f KB/s", kbps) }
        return "0 KB/s"
    }

    static func networkSpeedCompact(_ bytesPerSec: Double) -> (value: String, unit: String) {
        let kbps = bytesPerSec / 1_024
        let mbps = kbps / 1_024
        let gbps = mbps / 1_024
        if gbps >= 1   { return (String(format: "%.2f", gbps), "GB/s") }
        if mbps >= 0.1 { return (String(format: "%.1f", mbps), "MB/s") }
        return (String(format: "%.0f", kbps), "KB/s")
    }

    /// Ultra-compact form for the menu bar — e.g. "1.2M" or "123K"
    static func networkSpeedMenuBar(_ bytesPerSec: Double) -> String {
        let kbps = bytesPerSec / 1_024
        let mbps = kbps / 1_024
        if mbps >= 0.1 { return String(format: "%.1fM", mbps) }
        return String(format: "%.0fK", kbps)
    }

    // MARK: - Duration
    static func duration(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        let d = h / 24
        if d > 0  { return "\(d)d \(h % 24)h" }
        if h > 0  { return "\(h)h \(m % 60)m" }
        if m > 0  { return "\(m)m \(s % 60)s" }
        return "\(s)s"
    }

    static func durationShort(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        if h > 0  { return "\(h)h \(m % 60)m" }
        if m > 0  { return "\(m)m" }
        return "\(s)s"
    }

    static func durationLong(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        if h > 0  { return "\(h) hr \(m % 60) min" }
        if m > 0  { return "\(m) min \(s % 60) sec" }
        return "\(s) sec"
    }

    // MARK: - Battery time
    static func batteryTime(minutes: Int) -> String {
        guard minutes > 0 else { return "Calculating…" }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    // MARK: - Percentage
    static func percent(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", value)
    }

    static func percentInt(_ value: Double) -> String {
        String(format: "%d%%", Int(value.rounded()))
    }

    // MARK: - Temperature
    static func temperature(_ celsius: Double) -> String {
        String(format: "%.1f°C", celsius)
    }

    // MARK: - Date/Time
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func timeString(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func shortDate(_ date: Date) -> String { shortDateFormatter.string(from: date) }
    static func relative(_ date: Date) -> String { relativeFormatter.localizedString(for: date, relativeTo: Date()) }

    // MARK: - Uptime
    static func uptime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        let m = s / 60
        let h = m / 60
        let d = h / 24
        if d > 0 { return "\(d)d \(h % 24)h \(m % 60)m" }
        if h > 0 { return "\(h)h \(m % 60)m" }
        return "\(m)m \(s % 60)s"
    }

    // MARK: - Compact memory
    static func memoryGB(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / (1_024 * 1_024 * 1_024))
    }

    static func memoryGBValue(_ bytes: UInt64) -> Double {
        Double(bytes) / (1_024 * 1_024 * 1_024)
    }
}
