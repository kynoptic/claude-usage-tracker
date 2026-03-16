import XCTest
@testable import Claude_Usage

@MainActor
final class HistoricalChartColorTests: XCTestCase {

    // MARK: - ChartColorMode Enum

    func testChartColorModeRawValues() {
        XCTAssertEqual(ChartColorMode.uniform.rawValue, "uniform")
        XCTAssertEqual(ChartColorMode.historical.rawValue, "historical")
    }

    func testChartColorModeDefaultIsUniform() {
        XCTAssertEqual(ChartColorMode.uniform, ChartColorMode.uniform,
                       "Default should be uniform to preserve existing behavior")
    }

    // MARK: - Percentage-Based Zone Calculation

    func testZoneForPercentageLow() {
        let zone = BurnUpChartView.zone(forPercentage: 20.0)
        XCTAssertEqual(zone, .green, "Low usage should be green")
    }

    func testZoneForPercentageMidGreen() {
        let zone = BurnUpChartView.zone(forPercentage: 65.0)
        XCTAssertEqual(zone, .green, "65% should be green")
    }

    func testZoneForPercentageAtYellowBoundary() {
        let zone = BurnUpChartView.zone(forPercentage: 80.0)
        XCTAssertEqual(zone, .yellow, "80% should be yellow")
    }

    func testZoneForPercentageYellow() {
        let zone = BurnUpChartView.zone(forPercentage: 85.0)
        XCTAssertEqual(zone, .yellow, "85% should be yellow")
    }

    func testZoneForPercentageAtOrangeBoundary() {
        let zone = BurnUpChartView.zone(forPercentage: 95.0)
        XCTAssertEqual(zone, .orange, "95% should be orange")
    }

    func testZoneForPercentageOrange() {
        let zone = BurnUpChartView.zone(forPercentage: 98.0)
        XCTAssertEqual(zone, .orange, "98% should be orange")
    }

    func testZoneForPercentageRed() {
        let zone = BurnUpChartView.zone(forPercentage: 106.0)
        XCTAssertEqual(zone, .red, "Over 105% should be red")
    }

    func testZoneForPercentageZero() {
        let zone = BurnUpChartView.zone(forPercentage: 0.0)
        XCTAssertEqual(zone, .green, "0% should be green")
    }

    func testZoneForPercentageExactly100() {
        let zone = BurnUpChartView.zone(forPercentage: 100.0)
        XCTAssertEqual(zone, .orange, "Exactly 100% should be orange")
    }

    // MARK: - Chart Segment Computation

    func testSegmentsFromSingleZone() {
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 10.0),
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 20.0),
            UsageSnapshot(date: Date(), percentage: 30.0),
        ]

        let segments = BurnUpChartView.colorSegments(from: snapshots)

        XCTAssertEqual(segments.count, 1, "All green points should form one segment")
        XCTAssertEqual(segments.first?.zone, .green)
        XCTAssertEqual(segments.first?.snapshots.count, 3)
    }

    func testSegmentsFromMultipleZones() {
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-180), percentage: 30.0),
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 60.0),
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 85.0),
            UsageSnapshot(date: Date(), percentage: 98.0),
        ]

        let segments = BurnUpChartView.colorSegments(from: snapshots)

        // 30% green, 60% green, 85% yellow, 98% orange → 3 segments
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].zone, .green)
        XCTAssertEqual(segments[1].zone, .yellow)
        XCTAssertEqual(segments[2].zone, .orange)
    }

    func testSegmentBridging() {
        // Adjacent segments should share a boundary point for continuous rendering
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 60.0),
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 85.0),
            UsageSnapshot(date: Date(), percentage: 98.0),
        ]

        let segments = BurnUpChartView.colorSegments(from: snapshots)

        // Green→Yellow transition: last green point should be first yellow point
        XCTAssertGreaterThanOrEqual(segments.count, 2)
        if segments.count >= 2 {
            let lastOfFirst = segments[0].snapshots.last
            let firstOfSecond = segments[1].snapshots.first
            XCTAssertEqual(lastOfFirst?.date, firstOfSecond?.date,
                           "Segments should share boundary points for continuity")
            XCTAssertEqual(lastOfFirst?.percentage, firstOfSecond?.percentage)
        }
    }

    func testSegmentsEmpty() {
        let segments = BurnUpChartView.colorSegments(from: [])
        XCTAssertTrue(segments.isEmpty)
    }

    func testSegmentsSinglePoint() {
        let snapshots = [
            UsageSnapshot(date: Date(), percentage: 50.0),
        ]

        let segments = BurnUpChartView.colorSegments(from: snapshots)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.zone, .green)
        XCTAssertEqual(segments.first?.snapshots.count, 1)
    }

    func testSegmentsReturningToLowerZone() {
        // Usage goes up then comes back down (e.g., session reset)
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-180), percentage: 30.0),
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 85.0),
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 90.0),
            UsageSnapshot(date: Date(), percentage: 40.0),
        ]

        let segments = BurnUpChartView.colorSegments(from: snapshots)

        // 30% green, 85% yellow, 90% yellow, 40% green → green, yellow, green
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].zone, .green)
        XCTAssertEqual(segments[1].zone, .yellow)
        XCTAssertEqual(segments[2].zone, .green)
    }

    // MARK: - AppearanceStore Persistence

    func testChartColorModeDefaultsToUniform() {
        let store = AppearanceStore.shared
        // Clear any existing value
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.chartColorMode)
        let mode = store.loadChartColorMode()
        XCTAssertEqual(mode, .uniform)
    }

    func testChartColorModeSaveAndLoad() {
        let store = AppearanceStore.shared
        store.saveChartColorMode(.historical)
        XCTAssertEqual(store.loadChartColorMode(), .historical)

        store.saveChartColorMode(.uniform)
        XCTAssertEqual(store.loadChartColorMode(), .uniform)
    }

    // MARK: - UsageZone Codable

    func testUsageZoneEncodeDecode() throws {
        let zones: [UsageZone] = [.grey, .green, .yellow, .orange, .red]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for zone in zones {
            let data = try encoder.encode(zone)
            let decoded = try decoder.decode(UsageZone.self, from: data)
            XCTAssertEqual(decoded, zone)
        }
    }
}
