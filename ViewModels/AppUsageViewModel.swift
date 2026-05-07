import Foundation
import Combine
import SwiftUI
import AppKit

// MARK: - Time Range

enum TimeRange: String, CaseIterable, Identifiable {
    case today     = "Today"
    case thisWeek  = "This Week"
    case thisMonth = "This Month"

    var id: String { rawValue }

    var startDate: Date {
        let cal = Calendar.current
        let now = Date()
        switch self {
        case .today:     return cal.startOfDay(for: now)
        case .thisWeek:  return cal.date(byAdding: .day, value: -7, to: now) ?? now
        case .thisMonth: return cal.date(byAdding: .month, value: -1, to: now) ?? now
        }
    }
}

// MARK: - AppUsageViewModel

@MainActor
final class AppUsageViewModel: ObservableObject {

    // MARK: - Published
    @Published var selectedRange: TimeRange = .today
    @Published var summaries:    [AppUsageSummary] = []
    @Published var selectedApp:  AppUsageSummary?
    @Published var productivityScore: Double = 0
    @Published var isLoading = false

    private let tracker: AppUsageTracker
    private var cancellables = Set<AnyCancellable>()

    init(tracker: AppUsageTracker) {
        self.tracker = tracker
        reload()

        $selectedRange
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        // Reload when a session completes (app switch)
        tracker.$sessions
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)

        // Live-refresh every 30 s so the active app's elapsed time stays current
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }

    // MARK: - Reload
    func reload() {
        // Only show skeleton on the very first load (no data yet).
        // Background refreshes update data in-place so the list doesn't flash.
        if summaries.isEmpty { isLoading = true }
        let range = selectedRange
        let startDate = range.startDate

        Task { @MainActor in
            let data = tracker.appUsageSummaries(since: startDate)
            let score = tracker.productivityScore(since: startDate)
            self.summaries = data
            self.productivityScore = score
            self.isLoading = false
        }
    }

    // MARK: - Productivity breakdown
    var productiveDuration: TimeInterval {
        summaries
            .filter { $0.category.scoreWeight > 0 }
            .reduce(0) { $0 + $1.totalDuration }
    }

    var neutralDuration: TimeInterval {
        summaries
            .filter { $0.category.scoreWeight == 0 }
            .reduce(0) { $0 + $1.totalDuration }
    }

    var distractingDuration: TimeInterval {
        summaries
            .filter { $0.category.scoreWeight < 0 }
            .reduce(0) { $0 + $1.totalDuration }
    }

    var totalTrackedDuration: TimeInterval {
        summaries.reduce(0) { $0 + $1.totalDuration }
    }

    // MARK: - Chart helpers
    var topAppsForChart: [AppUsageSummary] {
        Array(summaries.prefix(8))
    }

    // MARK: - Color for app at index
    func color(for index: Int) -> String {
        DS.Colors.chartPalette[index % DS.Colors.chartPalette.count].description
    }

    // MARK: - Select app
    func selectApp(_ summary: AppUsageSummary?) {
        withAnimation(DS.Animations.spring) {
            selectedApp = summary
        }
    }

    // MARK: - Insights
    var insights: [InsightCard] {
        var cards = [InsightCard]()

        if let top = summaries.first {
            cards.append(InsightCard(
                title: "Top App",
                description: "\(top.appName) was your most-used app",
                highlight: Formatters.durationShort(top.totalDuration),
                type: .appUsage,
                timestamp: Date()
            ))
        }

        if productivityScore > 70 {
            cards.append(InsightCard(
                title: "Productive Day",
                description: "You spent most of your time on productive tasks",
                highlight: "\(Int(productivityScore))% productive",
                type: .appUsage,
                timestamp: Date()
            ))
        } else if productivityScore < 40 {
            cards.append(InsightCard(
                title: "Distraction Alert",
                description: "A large portion of time went to entertainment",
                highlight: Formatters.durationShort(distractingDuration),
                type: .appUsage,
                timestamp: Date()
            ))
        }

        return cards
    }
}
