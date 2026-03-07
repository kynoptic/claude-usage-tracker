import XCTest
@testable import Claude_Usage

final class SessionHistoryStoreTests: XCTestCase {

    // MARK: - Helpers

    private func makeStore() -> SessionHistoryStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionHistoryStoreTests_\(UUID().uuidString)")
        return SessionHistoryStore(storageDirectory: dir)
    }

    private func session(percentage: Double = 80.0, limit: Int = 100_000, daysAgo: Double = 0) -> SessionRecord {
        SessionRecord(
            endedAt: Date().addingTimeInterval(-daysAgo * 86_400),
            finalPercentage: percentage,
            sessionLimit: limit
        )
    }

    private func weekly(percentage: Double = 70.0, limit: Int = 1_000_000, daysAgo: Double = 0) -> WeeklyRecord {
        WeeklyRecord(
            endedAt: Date().addingTimeInterval(-daysAgo * 86_400),
            finalPercentage: percentage,
            weeklyLimit: limit,
            planChangedDuringPeriod: false
        )
    }

    // MARK: - Session: Record and Retrieve

    func testSession_RecordAndRetrieve() {
        let store = makeStore()
        store.record(session: session(percentage: 75.0))
        let sessions = store.sessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].finalPercentage, 75.0)
    }

    func testSession_MultipleRecords_InOrder() {
        let store = makeStore()
        store.record(session: session(percentage: 60.0))
        store.record(session: session(percentage: 80.0))
        store.record(session: session(percentage: 95.0))
        let sessions = store.sessions()
        XCTAssertEqual(sessions.count, 3)
        XCTAssertEqual(sessions[2].finalPercentage, 95.0)
    }

    // MARK: - Session: Prune at 21

    func testSession_PruneAt21() {
        let store = makeStore()
        for i in 0..<21 {
            store.record(session: session(percentage: Double(i)))
        }
        let sessions = store.sessions()
        XCTAssertEqual(sessions.count, 20)
        // Oldest (percentage 0) should have been pruned
        XCTAssertEqual(sessions[0].finalPercentage, 1.0)
    }

    // MARK: - Weekly: Record and Retrieve

    func testWeekly_RecordAndRetrieve() {
        let store = makeStore()
        store.record(weekly: weekly(percentage: 65.0))
        let weeklies = store.weeklies()
        XCTAssertEqual(weeklies.count, 1)
        XCTAssertEqual(weeklies[0].finalPercentage, 65.0)
    }

    func testWeekly_PruneAt9() {
        let store = makeStore()
        for i in 0..<9 {
            store.record(weekly: weekly(percentage: Double(i * 10)))
        }
        let weeklies = store.weeklies()
        XCTAssertEqual(weeklies.count, 8)
        // Oldest (0.0%) should have been pruned
        XCTAssertEqual(weeklies[0].finalPercentage, 10.0)
    }

    // MARK: - weeklyProjected: plan-change filtering

    func testWeeklyProjected_ReturnsNilWhenEmpty() {
        let store = makeStore()
        XCTAssertNil(store.weeklyProjected(currentLimit: 1_000_000))
    }

    func testWeeklyProjected_MatchingLimit_ReturnsValue() {
        let store = makeStore()
        store.record(weekly: weekly(percentage: 80.0, limit: 1_000_000))
        let projected = store.weeklyProjected(currentLimit: 1_000_000)
        XCTAssertEqual(projected, 0.80, accuracy: 0.001)
    }

    func testWeeklyProjected_SmallDelta_Included() {
        // 5% delta — within 10% threshold, should be included
        let store = makeStore()
        store.record(weekly: weekly(percentage: 70.0, limit: 950_000))
        let projected = store.weeklyProjected(currentLimit: 1_000_000)
        XCTAssertNotNil(projected)
    }

    func testWeeklyProjected_LargeDelta_Excluded() {
        // 50% delta — plan changed, should be excluded
        let store = makeStore()
        store.record(weekly: weekly(percentage: 70.0, limit: 500_000))
        let projected = store.weeklyProjected(currentLimit: 1_000_000)
        XCTAssertNil(projected)
    }

    func testWeeklyProjected_MixedRecords_OnlyMatchingIncluded() {
        let store = makeStore()
        // Excluded (plan changed)
        store.record(weekly: weekly(percentage: 40.0, limit: 500_000))
        // Included
        store.record(weekly: weekly(percentage: 85.0, limit: 1_000_000))
        let projected = store.weeklyProjected(currentLimit: 1_000_000)
        // Should return the most recent matching record (85%)
        XCTAssertEqual(projected!, 0.85, accuracy: 0.001)
    }

    // MARK: - Persistence

    func testPersistence_SessionsRoundtrip() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionHistoryStorePersist_\(UUID().uuidString)")
        let store1 = SessionHistoryStore(storageDirectory: dir)
        store1.record(session: session(percentage: 77.0))
        store1.flush()

        let store2 = SessionHistoryStore(storageDirectory: dir)
        let sessions = store2.sessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].finalPercentage, 77.0)
    }

    func testPersistence_WeekliesRoundtrip() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionHistoryStorePersistW_\(UUID().uuidString)")
        let store1 = SessionHistoryStore(storageDirectory: dir)
        store1.record(weekly: weekly(percentage: 62.5))
        store1.flush()

        let store2 = SessionHistoryStore(storageDirectory: dir)
        let weeklies = store2.weeklies()
        XCTAssertEqual(weeklies.count, 1)
        XCTAssertEqual(weeklies[0].finalPercentage, 62.5)
    }

    // MARK: - clearAll

    func testClearAll_RemovesAllRecords() {
        let store = makeStore()
        store.record(session: session())
        store.record(weekly: weekly())
        store.clearAll()
        XCTAssertEqual(store.sessions().count, 0)
        XCTAssertEqual(store.weeklies().count, 0)
    }
}
