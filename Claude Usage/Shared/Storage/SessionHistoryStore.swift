import Foundation

/// Persists session and weekly boundary records (dormant -- reserved for future history display).
/// Architecture mirrors UsageHistoryStore: file-based JSON, testable via `init(storageDirectory:)`.
@MainActor
final class SessionHistoryStore {

    static let shared = SessionHistoryStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private var sessionCache: [SessionRecord] = []
    private var weeklyCache: [WeeklyRecord] = []
    private var loaded = false

    private let storageDirectory: URL

    private enum Kind { case sessions, weeklies }

    // MARK: - Initialization

    init() {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            LoggingService.shared.logError("SessionHistoryStore: applicationSupportDirectory unavailable; falling back to temporary directory")
            self.storageDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Claude Usage")
                .appendingPathComponent("History")
            return
        }
        self.storageDirectory = appSupport
            .appendingPathComponent("Claude Usage")
            .appendingPathComponent("History")
    }

    /// Testable initializer that uses an isolated storage directory.
    init(storageDirectory: URL) {
        self.storageDirectory = storageDirectory
    }

    nonisolated deinit {}

    // MARK: - Public Methods

    /// Record a completed session, pruning to 20 entries.
    func record(session: SessionRecord) {
        ensureLoaded()
        sessionCache.append(session)
        if sessionCache.count > 20 {
            sessionCache.removeFirst(sessionCache.count - 20)
        }
        persist(.sessions)
    }

    /// Record a completed weekly period, pruning to 8 entries.
    func record(weekly: WeeklyRecord) {
        ensureLoaded()
        weeklyCache.append(weekly)
        if weeklyCache.count > 8 {
            weeklyCache.removeFirst(weeklyCache.count - 8)
        }
        persist(.weeklies)
    }

    /// Returns all stored session records in insertion order.
    func sessions() -> [SessionRecord] {
        ensureLoaded()
        return sessionCache
    }

    /// Returns all stored weekly records in insertion order.
    func weeklies() -> [WeeklyRecord] {
        ensureLoaded()
        return weeklyCache
    }

    /// Returns the most recent weekly utilisation fraction that passes the plan-stability filter.
    ///
    /// A record is included only when the absolute limit delta relative to `currentLimit` is < 10%.
    /// Returns nil when no matching records exist.
    func weeklyProjected(currentLimit: Int) -> Double? {
        ensureLoaded()
        guard currentLimit > 0 else { return nil }
        let filtered = weeklyCache.filter { record in
            let delta = abs(Double(record.weeklyLimit) - Double(currentLimit)) / Double(currentLimit)
            return delta < 0.10
        }
        guard let last = filtered.last else { return nil }
        return last.finalPercentage / 100.0
    }

    /// No-op: retained for API compatibility. @MainActor serialises all access and
    /// persistence is now synchronous, so there is nothing to flush.
    func flush() {}

    /// Remove all records and delete persisted files (for testing or user reset).
    func clearAll() {
        sessionCache = []
        weeklyCache = []
        loaded = true
        try? fileManager.removeItem(at: fileURL(.sessions))
        try? fileManager.removeItem(at: fileURL(.weeklies))
    }

    // MARK: - Private

    private func fileURL(_ kind: Kind) -> URL {
        let name: String
        switch kind {
        case .sessions: name = "session_records.json"
        case .weeklies: name = "weekly_records.json"
        }
        return storageDirectory.appendingPathComponent(name)
    }

    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true
        sessionCache = loadSessions()
        weeklyCache  = loadWeeklies()
    }

    private func loadSessions() -> [SessionRecord] {
        let url = fileURL(.sessions)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([SessionRecord].self, from: data)) ?? []
    }

    private func loadWeeklies() -> [WeeklyRecord] {
        let url = fileURL(.weeklies)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([WeeklyRecord].self, from: data)) ?? []
    }

    /// Persist the current cache for the given kind synchronously.
    /// @MainActor isolation serialises all access; no queue is needed.
    private func persist(_ kind: Kind) {
        do {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let url = fileURL(kind)
            switch kind {
            case .sessions:
                let data = try encoder.encode(sessionCache)
                try data.write(to: url, options: .atomic)
            case .weeklies:
                let data = try encoder.encode(weeklyCache)
                try data.write(to: url, options: .atomic)
            }
        } catch {
            LoggingService.shared.logError("SessionHistoryStore: Failed to persist \(kind): \(error)")
        }
    }
}
