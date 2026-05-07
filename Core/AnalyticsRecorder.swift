import Foundation
import Combine

// MARK: - AnalyticsSample

struct AnalyticsSample: Codable, Identifiable {
    let id:        UUID
    let timestamp: Date
    let cpu:       Double   // 0–100
    let memory:    Double   // 0–100

    init(cpu: Double, memory: Double) {
        self.id        = UUID()
        self.timestamp = Date()
        self.cpu       = cpu
        self.memory    = memory
    }
}

// MARK: - AnalyticsRecorder
// Snapshots CPU + memory every 30 s and persists up to 3 days of samples.

@MainActor
final class AnalyticsRecorder: ObservableObject {

    @Published private(set) var samples: [AnalyticsSample] = []

    private var cancellables = Set<AnyCancellable>()
    private let maxDays    = 3
    private let storageKey = "analyticsRecorderSamples"

    init() { load() }

    // MARK: - Start (call once DashboardViewModel is ready)

    func start(cpuPublisher:    AnyPublisher<Double, Never>,
               memoryPublisher: AnyPublisher<Double, Never>) {

        Publishers.CombineLatest(cpuPublisher, memoryPublisher)
            .throttle(for: .seconds(30), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] cpu, mem in
                guard let self else { return }
                self.samples.append(AnalyticsSample(cpu: cpu, memory: mem))
                self.trim()
                self.save()
            }
            .store(in: &cancellables)
    }

    // MARK: - Queries

    /// All samples whose timestamp falls within the calendar day of `date`.
    func samples(for date: Date) -> [AnalyticsSample] {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        return samples.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    /// Earliest date for which we have at least one sample.
    var oldestDate: Date? { samples.map(\.timestamp).min() }

    // MARK: - Private

    private func trim() {
        let cutoff = Date().addingTimeInterval(-Double(maxDays) * 86_400)
        if let first = samples.first, first.timestamp < cutoff {
            samples = samples.filter { $0.timestamp > cutoff }
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data    = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([AnalyticsSample].self, from: data) else { return }
        let cutoff = Date().addingTimeInterval(-Double(maxDays) * 86_400)
        samples = decoded.filter { $0.timestamp > cutoff }
    }
}
