import Foundation

// MARK: - App Constants

enum AppConstants {
    static let appName          = "moniq"
    static let appVersion       = "1.0.0"
    static let bundleID         = "com.moniq.app"

    // MARK: - Update intervals
    enum Interval {
        static let fast: TimeInterval   = 1.0
        static let normal: TimeInterval = 2.0
        static let slow: TimeInterval   = 5.0
    }

    // MARK: - Thresholds
    enum Threshold {
        static let cpuWarning:    Double = 80.0
        static let cpuCritical:   Double = 95.0
        static let memoryWarning: Double = 80.0
        static let diskWarning:   Double = 80.0
        static let batteryLow:    Double = 20.0
        static let batteryCritical: Double = 10.0
        static let batteryHealthGood: Double = 80.0
        static let batteryHealthFair: Double = 60.0
    }

    // MARK: - History
    enum History {
        static let sparklinePoints  = 30    // halved — enough for smooth sparklines
        static let chartPoints      = 60    // halved — charts stay readable
        static let maxDaysRetention = 90
    }

    // MARK: - App categories
    enum AppCategory: String, CaseIterable, Codable {
        case productivity    = "Productivity"
        case communication   = "Communication"
        case creative        = "Creative"
        case development     = "Development"
        case entertainment   = "Entertainment"
        case system          = "System"
        case browser         = "Browser"
        case other           = "Other"

        var color: String {
            switch self {
            case .productivity:  return "#00FF88"
            case .communication: return "#00D4FF"
            case .creative:      return "#FF6B9D"
            case .development:   return "#6C63FF"
            case .entertainment: return "#FFB830"
            case .system:        return "#8B8BA7"
            case .browser:       return "#FF4757"
            case .other:         return "#4A4A6A"
            }
        }

        // Productivity score weight (positive = productive, negative = distracting)
        var scoreWeight: Double {
            switch self {
            case .productivity:  return  1.0
            case .development:   return  1.0
            case .communication: return  0.5
            case .creative:      return  0.8
            case .system:        return  0.2
            case .browser:       return -0.2
            case .entertainment: return -1.0
            case .other:         return  0.0
            }
        }
    }

    // MARK: - Known app categories
    static let knownCategories: [String: AppCategory] = [
        "com.apple.dt.Xcode":               .development,
        "com.microsoft.VSCode":             .development,
        "com.jetbrains.intellij":           .development,
        "com.apple.Terminal":               .development,
        "com.googlecode.iterm2":            .development,
        "com.figma.Desktop":                .creative,
        "com.bohemiancoding.sketch3":       .creative,
        "com.adobe.Photoshop":              .creative,
        "com.adobe.Illustrator":            .creative,
        "com.apple.Logic":                  .creative,
        "com.apple.FinalCut":               .creative,
        "com.microsoft.Word":               .productivity,
        "com.microsoft.Excel":              .productivity,
        "com.microsoft.Powerpoint":         .productivity,
        "com.apple.iWork.Pages":            .productivity,
        "com.apple.iWork.Numbers":          .productivity,
        "com.apple.iWork.Keynote":          .productivity,
        "com.notion.id":                    .productivity,
        "com.linear.app":                   .productivity,
        "com.apple.Notes":                  .productivity,
        "com.slack.Slack":                  .communication,
        "com.tinyspeck.slackmacgap":        .communication,
        "com.microsoft.teams":              .communication,
        "com.apple.FaceTime":               .communication,
        "com.apple.MobileSMS":              .communication,
        "com.hnc.Discord":                  .communication,
        "com.google.Chrome":                .browser,
        "com.apple.Safari":                 .browser,
        "org.mozilla.firefox":              .browser,
        "com.microsoft.edgemac":            .browser,
        "com.brave.Browser":                .browser,
        "com.apple.Music":                  .entertainment,
        "com.spotify.client":               .entertainment,
        "com.apple.TV":                     .entertainment,
        "com.netflix.Netflix":              .entertainment,
        "com.valvesoftware.steam":          .entertainment,
        "com.apple.systempreferences":      .system,
        "com.apple.ActivityMonitor":        .system,
        "com.apple.Finder":                 .system,
    ]
}

// MARK: - UserDefaults Keys
enum DefaultsKey {
    static let updateInterval      = "updateInterval"
    static let launchAtLogin       = "launchAtLogin"
    static let showInMenuBar       = "showInMenuBar"
    static let showInDock          = "showInDock"
    static let cpuAlertThreshold   = "cpuAlertThreshold"
    static let memAlertThreshold   = "memAlertThreshold"
    static let batteryAlertLevel   = "batteryAlertLevel"
    static let networkSpikeAlert   = "networkSpikeAlert"
    static let accentColorIndex    = "accentColorIndex"
    static let chartStyle          = "chartStyle"
    static let animationSpeed      = "animationSpeed"
    static let dataRetentionDays   = "dataRetentionDays"
    static let appUsageData        = "appUsageData"
    static let selectedNavItem     = "selectedNavItem"
    static let menuBarShowCPU      = "menuBarShowCPU"
    static let menuBarShowMemory   = "menuBarShowMemory"
    static let menuBarShowBattery  = "menuBarShowBattery"
    static let menuBarShowNetwork  = "menuBarShowNetwork"
    static let menuBarColoured     = "menuBarColoured"
}
