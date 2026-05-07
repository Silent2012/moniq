import Foundation
import Combine
import AppKit

// MARK: - AppUsageTracker
// Tracks foreground app time via NSWorkspace activation notifications

@MainActor
final class AppUsageTracker: ObservableObject {

    // MARK: - Published
    @Published var sessions: [AppSession] = []
    @Published var currentApp: NSRunningApplication?

    // MARK: - Private
    private var activeSession: AppSession?
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter = NSWorkspace.shared.notificationCenter

    init() {
        loadSessions()
        observeWorkspace()
        // Capture currently active app
        if let front = NSWorkspace.shared.frontmostApplication {
            startSession(for: front)
        }
    }

    deinit {
        notificationCenter.removeObserver(self)
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Workspace Observers
    private func observeWorkspace() {
        notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.handleActivation(app)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: NSWorkspace.didDeactivateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.handleDeactivation(app)
            }
            .store(in: &cancellables)

        notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.handleTermination(app)
            }
            .store(in: &cancellables)

        // Periodic save
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.saveSessions() }
            .store(in: &cancellables)
    }

    private func handleActivation(_ app: NSRunningApplication) {
        // End previous session
        if let active = activeSession {
            endSession(active)
        }
        startSession(for: app)
        currentApp = app
    }

    private func handleDeactivation(_ app: NSRunningApplication) {
        guard let active = activeSession, active.bundleID == (app.bundleIdentifier ?? "") else { return }
        endSession(active)
        activeSession = nil
    }

    private func handleTermination(_ app: NSRunningApplication) {
        guard let active = activeSession, active.bundleID == (app.bundleIdentifier ?? "") else { return }
        endSession(active)
        activeSession = nil
    }

    private func startSession(for app: NSRunningApplication) {
        guard let bundleID = app.bundleIdentifier else { return }
        let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? bundleID
        activeSession = AppSession(bundleID: bundleID, appName: name)
    }

    private func endSession(_ session: AppSession) {
        var completed = session
        completed.endTime = Date()
        guard completed.duration > 1 else { return } // ignore < 1 sec flickers
        sessions.append(completed)
        trimOldSessions()
    }

    // MARK: - Query helpers

    func sessions(for bundleID: String, since date: Date) -> [AppSession] {
        sessions.filter { $0.bundleID == bundleID && $0.startTime >= date }
    }

    func totalDuration(for bundleID: String, since date: Date) -> TimeInterval {
        sessions(for: bundleID, since: date).reduce(0) { $0 + $1.duration }
    }

    func allAppBundleIDs(since date: Date) -> [String] {
        let filtered = sessions.filter { $0.startTime >= date }
        return Array(Set(filtered.map { $0.bundleID }))
    }

    /// Returns all unique apps used since a date, sorted by total usage (descending).
    /// Includes the currently-active (in-progress) session so the live app is counted.
    func appUsageSummaries(since date: Date) -> [AppUsageSummary] {
        // Merge completed sessions with the ongoing active session (if any)
        var allSessions = sessions
        if let active = activeSession, active.startTime >= date {
            // Synthesise a completed copy with endTime = now so duration is current
            var live = active
            live.endTime = Date()
            allSessions.append(live)
        }

        let filtered = allSessions.filter { $0.startTime >= date }
        guard !filtered.isEmpty else { return [] }

        var grouped = [String: [AppSession]]()
        for session in filtered {
            grouped[session.bundleID, default: []].append(session)
        }

        let totalTime = filtered.reduce(0.0) { $0 + $1.duration }

        var summaries = grouped.compactMap { bundleID, appSessions -> AppUsageSummary? in
            guard let first = appSessions.first else { return nil }

            let app = NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
            let icon = app?.icon ?? iconForBundleID(bundleID)

            let total = appSessions.reduce(0.0) { $0 + $1.duration }
            let firstUsed = appSessions.map { $0.startTime }.min() ?? Date()
            let lastUsed  = appSessions.compactMap { $0.endTime }.max() ?? Date()

            // Hourly breakdown (24 buckets)
            var hourly = [Double](repeating: 0, count: 24)
            for session in appSessions {
                let hour = Calendar.current.component(.hour, from: session.startTime)
                hourly[hour] += session.duration
            }

            let category = AppConstants.knownCategories[bundleID] ?? .other

            return AppUsageSummary(
                id:           bundleID,
                bundleID:     bundleID,
                appName:      first.appName,
                icon:         icon,
                category:     category,
                totalDuration: total,
                sessionCount: appSessions.count,
                firstUsed:    firstUsed,
                lastUsed:     lastUsed,
                hourlyUsage:  hourly
            )
        }

        summaries.sort { $0.totalDuration > $1.totalDuration }

        // Inject percent of total via direct struct mutation
        if totalTime > 0 {
            for i in summaries.indices {
                summaries[i].percentOfTotal = summaries[i].totalDuration / totalTime * 100
            }
        }

        return summaries
    }

    /// Productivity score 0-100
    func productivityScore(since date: Date) -> Double {
        let summaries = appUsageSummaries(since: date)
        guard !summaries.isEmpty else { return 50 }
        let total = summaries.reduce(0.0) { $0 + $1.totalDuration }
        guard total > 0 else { return 50 }
        let weighted = summaries.reduce(0.0) { acc, s in
            acc + s.totalDuration * s.category.scoreWeight
        }
        let normalized = (weighted / total + 1.0) / 2.0 * 100
        return max(0, min(100, normalized))
    }

    // MARK: - Icon helper
    private func iconForBundleID(_ bundleID: String) -> NSImage? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    // MARK: - Persistence
    private func trimOldSessions() {
        let cutoff = Date().addingTimeInterval(-Double(AppConstants.History.maxDaysRetention) * 86400)
        sessions = sessions.filter { $0.startTime > cutoff }
    }

    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: DefaultsKey.appUsageData)
        }
    }

    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: DefaultsKey.appUsageData),
              let decoded = try? JSONDecoder().decode([AppSession].self, from: data) else { return }
        let cutoff = Date().addingTimeInterval(-Double(AppConstants.History.maxDaysRetention) * 86400)
        sessions = decoded.filter { $0.startTime > cutoff }
    }
}
