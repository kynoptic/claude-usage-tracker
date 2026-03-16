import XCTest
@testable import Claude_Usage

@MainActor
final class UsageHistoryStoreTests: XCTestCase {

    private var store: UsageHistoryStore!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        store = UsageHistoryStore(storageDirectory: tempDir)
    }

    override func tearDown() {
        store = nil
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    // MARK: - UsageSnapshot Codable Tests

    func testSnapshotEncodeDecode() throws {
        let now = Date()
        let snapshot = UsageSnapshot(date: now, percentage: 42.5)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UsageSnapshot.self, from: data)

        XCTAssertEqual(decoded.percentage, 42.5)
        // ISO8601 loses sub-second precision, compare to nearest second
        XCTAssertEqual(decoded.date.timeIntervalSinceReferenceDate,
                       now.timeIntervalSinceReferenceDate, accuracy: 1.0)
    }

    func testSnapshotEquality() {
        let date = Date()
        let a = UsageSnapshot(date: date, percentage: 50.0)
        let b = UsageSnapshot(date: date, percentage: 50.0)
        let c = UsageSnapshot(date: date, percentage: 75.0)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Recording Tests

    func testRecordAndRetrieve() {
        store.record(25.0, for: .session)
        store.record(50.0, for: .session)

        let snapshots = store.snapshots(for: .session)
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots[0].percentage, 25.0)
        XCTAssertEqual(snapshots[1].percentage, 50.0)
    }

    func testRecordAllFromUsage() {
        let usage = ClaudeUsage(
            sessionTokensUsed: 500,
            sessionLimit: 1000,
            sessionPercentage: 50.0,
            sessionResetTime: Date().addingTimeInterval(3600),
            weeklyTokensUsed: 200,
            weeklyLimit: 1000,
            weeklyPercentage: 20.0,
            weeklyResetTime: Date().addingTimeInterval(86400),
            opusWeeklyTokensUsed: 100,
            opusWeeklyPercentage: 10.0,
            sonnetWeeklyTokensUsed: 50,
            sonnetWeeklyPercentage: 5.0,
            sonnetWeeklyResetTime: nil,
            costUsed: nil,
            costLimit: nil,
            costCurrency: nil,
            lastUpdated: Date(),
            userTimezone: .current
        )

        store.recordAll(from: usage)

        XCTAssertEqual(store.snapshots(for: .session).count, 1)
        XCTAssertEqual(store.snapshots(for: .session).first?.percentage, 50.0)
        XCTAssertEqual(store.snapshots(for: .weekly).first?.percentage, 20.0)
        XCTAssertEqual(store.snapshots(for: .opus).first?.percentage, 10.0)
        XCTAssertEqual(store.snapshots(for: .sonnet).first?.percentage, 5.0)
    }

    func testMetricsAreIsolated() {
        store.record(10.0, for: .session)
        store.record(90.0, for: .weekly)

        XCTAssertEqual(store.snapshots(for: .session).count, 1)
        XCTAssertEqual(store.snapshots(for: .session).first?.percentage, 10.0)
        XCTAssertEqual(store.snapshots(for: .weekly).count, 1)
        XCTAssertEqual(store.snapshots(for: .weekly).first?.percentage, 90.0)
        XCTAssertEqual(store.snapshots(for: .opus).count, 0)
    }

    // MARK: - Pruning Tests

    func testSessionPruningRemovesOldSnapshots() {
        let old = Date().addingTimeInterval(-(Constants.sessionWindow + 60))
        let recent = Date().addingTimeInterval(-60)

        store.record(10.0, for: .session, at: old)
        store.record(20.0, for: .session, at: recent)

        let snapshots = store.snapshots(for: .session)
        // The old snapshot is kept as an anchor (most recent pre-window point)
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots.first?.percentage, 10.0, "Anchor preserved")
        XCTAssertEqual(snapshots.last?.percentage, 20.0)
    }

    func testWeeklyPruningRemovesOldSnapshots() {
        let old = Date().addingTimeInterval(-(Constants.weeklyWindow + 60))
        let recent = Date().addingTimeInterval(-60)

        store.record(30.0, for: .weekly, at: old)
        store.record(60.0, for: .weekly, at: recent)

        let snapshots = store.snapshots(for: .weekly)
        // The old snapshot is kept as an anchor (most recent pre-window point)
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots.first?.percentage, 30.0, "Anchor preserved")
        XCTAssertEqual(snapshots.last?.percentage, 60.0)
    }

    func testBoundaryPruningKeepsExactEdge() {
        // Snapshot exactly at the window boundary should be kept
        let atBoundary = Date().addingTimeInterval(-Constants.sessionWindow + 1)
        store.record(15.0, for: .session, at: atBoundary)

        let snapshots = store.snapshots(for: .session)
        XCTAssertEqual(snapshots.count, 1)
    }

    func testBoundaryPruningKeepsJustPastAsAnchor() {
        // Snapshot just past the window should be kept as anchor
        // (the only pre-window snapshot becomes the anchor)
        let pastBoundary = Date().addingTimeInterval(-Constants.sessionWindow - 1)
        store.record(15.0, for: .session, at: pastBoundary)

        let snapshots = store.snapshots(for: .session)
        XCTAssertEqual(snapshots.count, 1, "Single pre-window snapshot kept as anchor")
        XCTAssertEqual(snapshots.first?.percentage, 15.0)
    }

    // MARK: - Persistence Tests

    func testPersistenceAcrossInstances() {
        // Record data and wait for async persist to complete
        store.record(33.0, for: .session)
        store.flush()

        // Verify it was persisted by reading the JSON file directly,
        // avoiding a second UsageHistoryStore instance (which triggers a
        // Swift runtime dealloc crash in the test host environment).
        let fileURL = tempDir.appendingPathComponent("session_history.json")
        let data = try? Data(contentsOf: fileURL)
        XCTAssertNotNil(data, "History file should exist on disk")

        if let data = data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshots = try? decoder.decode([UsageSnapshot].self, from: data)
            XCTAssertEqual(snapshots?.count, 1)
            XCTAssertEqual(snapshots?.first?.percentage, 33.0)
        }
    }

    // MARK: - Empty State Tests

    func testEmptyHistoryReturnsEmptyArray() {
        XCTAssertEqual(store.snapshots(for: .session), [])
        XCTAssertEqual(store.snapshots(for: .weekly), [])
        XCTAssertEqual(store.snapshots(for: .opus), [])
        XCTAssertEqual(store.snapshots(for: .sonnet), [])
    }

    func testClearAllRemovesEverything() {
        store.record(10.0, for: .session)
        store.record(20.0, for: .weekly)
        store.clearAll()

        XCTAssertEqual(store.snapshots(for: .session), [])
        XCTAssertEqual(store.snapshots(for: .weekly), [])
    }

    // MARK: - Edge Cases

    func testZeroPercentage() {
        store.record(0.0, for: .session)
        XCTAssertEqual(store.snapshots(for: .session).first?.percentage, 0.0)
    }

    func testHundredPercentage() {
        store.record(100.0, for: .session)
        XCTAssertEqual(store.snapshots(for: .session).first?.percentage, 100.0)
    }

    func testDeduplicationSkipsSamePercentage() {
        store.record(50.0, for: .session)
        store.record(50.0, for: .session)
        store.record(50.0, for: .session)

        XCTAssertEqual(store.snapshots(for: .session).count, 1)
    }

    func testDeduplicationRecordsDifferentPercentage() {
        store.record(50.0, for: .session)
        store.record(51.0, for: .session)
        store.record(51.0, for: .session)

        XCTAssertEqual(store.snapshots(for: .session).count, 2)
    }

    // MARK: - Consecutive Deduplication

    func testDeduplicateConsecutiveCollapsesIdentical() {
        let snapshots = (0..<10).map { i in
            UsageSnapshot(date: Date().addingTimeInterval(Double(i) * 30), percentage: 5.0)
        }

        let result = store.deduplicateConsecutive(snapshots)

        XCTAssertEqual(result.count, 1, "10 identical snapshots should collapse to 1")
        XCTAssertEqual(result.first?.percentage, 5.0)
    }

    func testDeduplicateConsecutivePreservesChanges() {
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 5.0),
            UsageSnapshot(date: Date().addingTimeInterval(-90), percentage: 5.0),
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 10.0),
            UsageSnapshot(date: Date().addingTimeInterval(-30), percentage: 10.0),
            UsageSnapshot(date: Date(), percentage: 15.0),
        ]

        let result = store.deduplicateConsecutive(snapshots)

        XCTAssertEqual(result.count, 3, "Should keep one entry per percentage change: 5, 10, 15")
        XCTAssertEqual(result.map(\.percentage), [5.0, 10.0, 15.0])
    }

    func testDeduplicateConsecutiveHandlesEmpty() {
        let result = store.deduplicateConsecutive([])
        XCTAssertEqual(result.count, 0)
    }

    func testDeduplicateConsecutiveHandlesSingle() {
        let snapshots = [UsageSnapshot(date: Date(), percentage: 42.0)]
        let result = store.deduplicateConsecutive(snapshots)
        XCTAssertEqual(result.count, 1)
    }

    // MARK: - Snapshot Identity

    func testSnapshotUUIDIsUniquePerInstance() {
        let date = Date()
        let a = UsageSnapshot(date: date, percentage: 50.0)
        let b = UsageSnapshot(date: date, percentage: 50.0)

        XCTAssertNotEqual(a.id, b.id, "Same-value snapshots must have unique IDs for ForEach")
        XCTAssertEqual(a, b, "Value equality should still hold")
    }

    func testSnapshotIdNotPersisted() throws {
        let snapshot = UsageSnapshot(date: Date(), percentage: 42.0)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNil(json["id"], "UUID id should not be in the JSON payload")
        XCTAssertNotNil(json["date"])
        XCTAssertNotNil(json["percentage"])
    }

    // MARK: - Anchor Snapshot Preservation (Issue #138)

    func testPruningPreservesAnchorSnapshot() {
        // Record a snapshot just outside the window, then one inside
        let outsideWindow = Date().addingTimeInterval(-(Constants.sessionWindow + 120))
        let justOutside = Date().addingTimeInterval(-(Constants.sessionWindow + 10))
        let insideWindow = Date().addingTimeInterval(-60)

        store.record(10.0, for: .session, at: outsideWindow)
        store.record(30.0, for: .session, at: justOutside)
        store.record(50.0, for: .session, at: insideWindow)

        let snapshots = store.snapshots(for: .session)
        // The most recent pre-window snapshot (30%) should be kept as anchor
        XCTAssertEqual(snapshots.count, 2, "Should keep anchor + in-window snapshot")
        XCTAssertEqual(snapshots.first?.percentage, 30.0,
                       "Anchor snapshot should be the last one before the window cutoff")
        XCTAssertEqual(snapshots.last?.percentage, 50.0)
    }

    func testPruningKeepsOnlyOneAnchor() {
        // Multiple pre-window snapshots: only the most recent should survive
        let veryOld = Date().addingTimeInterval(-(Constants.weeklyWindow + 3600))
        let old = Date().addingTimeInterval(-(Constants.weeklyWindow + 1800))
        let justOutside = Date().addingTimeInterval(-(Constants.weeklyWindow + 10))
        let inside = Date().addingTimeInterval(-60)

        store.record(10.0, for: .weekly, at: veryOld)
        store.record(20.0, for: .weekly, at: old)
        store.record(40.0, for: .weekly, at: justOutside)
        store.record(60.0, for: .weekly, at: inside)

        let snapshots = store.snapshots(for: .weekly)
        XCTAssertEqual(snapshots.count, 2, "Should keep 1 anchor + 1 in-window")
        XCTAssertEqual(snapshots.first?.percentage, 40.0, "Anchor should be the most recent pre-window")
    }

    func testNoAnchorWhenAllSnapshotsInWindow() {
        // All snapshots are within the window — no anchor needed
        let recent1 = Date().addingTimeInterval(-120)
        let recent2 = Date().addingTimeInterval(-60)

        store.record(25.0, for: .session, at: recent1)
        store.record(50.0, for: .session, at: recent2)

        let snapshots = store.snapshots(for: .session)
        XCTAssertEqual(snapshots.count, 2)
    }

    func testAnchorSurvivesReload() {
        // Anchor should be persisted and survive a reload from disk
        let justOutside = Date().addingTimeInterval(-(Constants.sessionWindow + 10))
        let inside = Date().addingTimeInterval(-60)

        store.record(35.0, for: .session, at: justOutside)
        store.record(70.0, for: .session, at: inside)
        store.flush()

        // Read persisted JSON directly to verify anchor is stored
        let fileURL = tempDir.appendingPathComponent("session_history.json")
        let data = try? Data(contentsOf: fileURL)
        XCTAssertNotNil(data)

        if let data = data {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let snapshots = try? decoder.decode([UsageSnapshot].self, from: data)
            XCTAssertEqual(snapshots?.count, 2)
            XCTAssertEqual(snapshots?.first?.percentage, 35.0,
                           "Anchor snapshot should be persisted to disk")
        }
    }

    // MARK: - Chart Origin Logic (Issue #138)

    func testChartSnapshotsCarryForwardFromAnchor() {
        // When there's a pre-window anchor, chart origin should use its percentage
        let anchor = UsageSnapshot(
            date: Date().addingTimeInterval(-(Constants.weeklyWindow + 10)),
            percentage: 40.0
        )
        let inWindow = UsageSnapshot(
            date: Date().addingTimeInterval(-3600),
            percentage: 55.0
        )
        let windowStart = Date().addingTimeInterval(-Constants.weeklyWindow)
        let windowEnd = Date().addingTimeInterval(3600)

        let display = BurnUpChartView.chartDisplaySnapshots(
            from: [anchor, inWindow],
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        // First point should be at windowStart with anchor's percentage (carry-forward)
        XCTAssertEqual(display.first?.date, windowStart)
        XCTAssertEqual(display.first?.percentage, 40.0,
                       "Origin should carry forward the anchor percentage, not drop to zero")
    }

    func testChartSnapshotsStartAtZeroWhenNoAnchor() {
        // When there's no pre-window data, origin should be 0% (genuine start)
        let inWindow = UsageSnapshot(
            date: Date().addingTimeInterval(-3600),
            percentage: 55.0
        )
        let windowStart = Date().addingTimeInterval(-Constants.weeklyWindow)
        let windowEnd = Date().addingTimeInterval(3600)

        let display = BurnUpChartView.chartDisplaySnapshots(
            from: [inWindow],
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        XCTAssertEqual(display.first?.percentage, 0.0,
                       "Without anchor data, origin should be 0%")
    }

    func testChartSnapshotsGenuineGapNotFilledWithZero() {
        // Pre-window anchor at 40%, then data resumes at 60%
        // The gap should show as a carry-forward at 40%, not a drop to zero
        let anchor = UsageSnapshot(
            date: Date().addingTimeInterval(-(Constants.weeklyWindow + 10)),
            percentage: 40.0
        )
        let resumePoint = UsageSnapshot(
            date: Date().addingTimeInterval(-1800),
            percentage: 60.0
        )
        let windowStart = Date().addingTimeInterval(-Constants.weeklyWindow)
        let windowEnd = Date().addingTimeInterval(3600)

        let display = BurnUpChartView.chartDisplaySnapshots(
            from: [anchor, resumePoint],
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        // No point in the display should have percentage 0.0
        // (the origin carries forward 40% from the anchor)
        let zeroPoints = display.filter { $0.percentage == 0.0 }
        XCTAssertTrue(zeroPoints.isEmpty,
                      "No artificial zero-drop should appear when anchor data exists")
    }

    func testChartSnapshotsAppendNowExtension() {
        // Verify the "now" extension point is appended
        let inWindow = UsageSnapshot(
            date: Date().addingTimeInterval(-3600),
            percentage: 45.0
        )
        let windowStart = Date().addingTimeInterval(-Constants.weeklyWindow)
        let windowEnd = Date().addingTimeInterval(3600)

        let display = BurnUpChartView.chartDisplaySnapshots(
            from: [inWindow],
            windowStart: windowStart,
            windowEnd: windowEnd
        )

        // Last point should be a "now" extension with the last real percentage
        XCTAssertEqual(display.last?.percentage, 45.0)
        // The "now" point should be after the real data point
        XCTAssertGreaterThan(display.last!.date, inWindow.date)
    }
}
