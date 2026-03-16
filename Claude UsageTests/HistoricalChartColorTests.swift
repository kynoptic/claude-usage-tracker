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

    // MARK: - Zone Calculation (no elapsed fraction → raw thresholds)
    //
    // Without elapsed fraction, UsageStatusCalculator uses raw u = percentage/100:
    //   green   < 0.9   (i.e., < 90%)
    //   yellow  0.9–1.1 (i.e., 90–110%)
    //   orange  1.1–1.5 (i.e., 110–150%)
    //   red     > 1.5   (i.e., > 150%)

    func testZoneForPercentageLow() {
        let zone = BurnUpChartView.zone(forPercentage: 20.0)
        XCTAssertEqual(zone, .green, "Low usage should be green")
    }

    func testZoneForPercentageMidGreen() {
        let zone = BurnUpChartView.zone(forPercentage: 65.0)
        XCTAssertEqual(zone, .green, "65% should be green")
    }

    func testZoneForPercentageHighGreen() {
        let zone = BurnUpChartView.zone(forPercentage: 85.0)
        XCTAssertEqual(zone, .green, "85% should still be green (threshold is 90%)")
    }

    func testZoneForPercentageAtYellowBoundary() {
        let zone = BurnUpChartView.zone(forPercentage: 90.0)
        XCTAssertEqual(zone, .yellow, "90% should be yellow")
    }

    func testZoneForPercentageYellow() {
        let zone = BurnUpChartView.zone(forPercentage: 100.0)
        XCTAssertEqual(zone, .yellow, "100% should be yellow")
    }

    func testZoneForPercentageAtOrangeBoundary() {
        let zone = BurnUpChartView.zone(forPercentage: 110.0)
        XCTAssertEqual(zone, .orange, "110% should be orange")
    }

    func testZoneForPercentageOrange() {
        let zone = BurnUpChartView.zone(forPercentage: 130.0)
        XCTAssertEqual(zone, .orange, "130% should be orange")
    }

    func testZoneForPercentageRed() {
        let zone = BurnUpChartView.zone(forPercentage: 160.0)
        XCTAssertEqual(zone, .red, "Over 150% should be red")
    }

    func testZoneForPercentageZero() {
        let zone = BurnUpChartView.zone(forPercentage: 0.0)
        XCTAssertEqual(zone, .green, "0% should be green")
    }

    // MARK: - Zone Calculation with Elapsed Fraction (pacing-projected)

    func testZoneWithElapsedFraction_OnPace() {
        // 50% used at 50% elapsed → projected 1.0 → yellow
        let zone = BurnUpChartView.zone(forPercentage: 50.0, elapsedFraction: 0.5)
        XCTAssertEqual(zone, .yellow, "On-pace projection (1.0) should be yellow")
    }

    func testZoneWithElapsedFraction_UnderPace() {
        // 20% used at 50% elapsed → projected 0.4 → green
        let zone = BurnUpChartView.zone(forPercentage: 20.0, elapsedFraction: 0.5)
        XCTAssertEqual(zone, .green, "Under-pace should be green")
    }

    func testZoneWithElapsedFraction_OverPace() {
        // 80% used at 30% elapsed → projected 2.67 → red
        let zone = BurnUpChartView.zone(forPercentage: 80.0, elapsedFraction: 0.3)
        XCTAssertEqual(zone, .red, "Heavy overshoot should be red")
    }

    // MARK: - Grey Zone

    func testZoneWithGreyEnabled() {
        // Grey zone uses UsageStatusCalculator's showGrey + greyThreshold
        // 10% used, no elapsed → projected 0.1 < 0.5 (default grey threshold)
        let status = UsageStatusCalculator.calculateStatus(
            usedPercentage: 10.0,
            showRemaining: false,
            elapsedFraction: nil,
            showGrey: true,
            greyThreshold: 0.5
        )
        XCTAssertEqual(status.zone, .grey, "Low usage with grey enabled should be grey")
    }

    // MARK: - Elapsed Fraction Calculation

    func testElapsedFractionMidWindow() {
        let start = Date()
        let end = start.addingTimeInterval(3600) // 1 hour window
        let mid = start.addingTimeInterval(1800) // 30 minutes in
        let fraction = BurnUpChartView.elapsedFraction(for: mid, windowStart: start, windowEnd: end)
        XCTAssertEqual(fraction!, 0.5, accuracy: 0.001)
    }

    func testElapsedFractionAtStart() {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let fraction = BurnUpChartView.elapsedFraction(for: start, windowStart: start, windowEnd: end)
        XCTAssertEqual(fraction!, 0.0, accuracy: 0.001)
    }

    func testElapsedFractionAtEnd() {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let fraction = BurnUpChartView.elapsedFraction(for: end, windowStart: start, windowEnd: end)
        XCTAssertEqual(fraction!, 1.0, accuracy: 0.001)
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
        // Without window bounds, uses raw thresholds: green <90, yellow 90-110, orange 110-150
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-180), percentage: 30.0),
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 60.0),
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 95.0),
            UsageSnapshot(date: Date(), percentage: 120.0),
        ]

        let segments = BurnUpChartView.colorSegments(from: snapshots)

        // 30% green, 60% green, 95% yellow, 120% orange → 3 segments
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].zone, .green)
        XCTAssertEqual(segments[1].zone, .yellow)
        XCTAssertEqual(segments[2].zone, .orange)
    }

    func testSegmentsWithWindowBoundsUseProjection() {
        let start = Date().addingTimeInterval(-3600) // 1 hour ago
        let end = Date().addingTimeInterval(3600)    // 1 hour from now
        // At midpoint (now), 50% elapsed. 50% used → projected 1.0 → yellow
        let snapshots = [
            UsageSnapshot(date: start, percentage: 0.0),
            UsageSnapshot(date: Date(), percentage: 50.0),
        ]

        let segments = BurnUpChartView.colorSegments(
            from: snapshots,
            windowStart: start,
            windowEnd: end
        )

        // First point at start: 0% at 0 elapsed → projected 0.0 → green
        // Second point at midpoint: 50% at 0.5 elapsed → projected 1.0 → yellow
        XCTAssertGreaterThanOrEqual(segments.count, 2)
        XCTAssertEqual(segments[0].zone, .green)
        XCTAssertEqual(segments[1].zone, .yellow)
    }

    func testSegmentsWithGreyZone() {
        let start = Date().addingTimeInterval(-3600)
        let end = Date().addingTimeInterval(3600)
        // 5% used at 50% elapsed → projected 0.1 → grey (below 0.5 threshold)
        let snapshots = [
            UsageSnapshot(date: Date(), percentage: 5.0),
        ]

        let segments = BurnUpChartView.colorSegments(
            from: snapshots,
            windowStart: start,
            windowEnd: end,
            showGrey: true,
            greyThreshold: 0.5
        )

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.zone, .grey)
    }

    func testSegmentBridging() {
        // Adjacent segments should share a boundary point for continuous rendering
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 60.0),
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 95.0),
            UsageSnapshot(date: Date(), percentage: 120.0),
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
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 95.0),
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 100.0),
            UsageSnapshot(date: Date(), percentage: 40.0),
        ]

        let segments = BurnUpChartView.colorSegments(from: snapshots)

        // 30% green, 95% yellow, 100% yellow, 40% green → green, yellow, green
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

    // MARK: - Despike Filter

    func testDespikeRemovesSingleSpike() {
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 50.0),
            UsageSnapshot(date: Date().addingTimeInterval(-2), percentage: 0.0),
            UsageSnapshot(date: Date(), percentage: 51.0),
        ]
        let result = BurnUpChartView.despike(snapshots)
        XCTAssertEqual(result.count, 2, "Transient 0% spike should be removed")
        XCTAssertEqual(result[0].percentage, 50.0)
        XCTAssertEqual(result[1].percentage, 51.0)
    }

    func testDespikeRemovesChainedSpikes() {
        // 38→0→39→0→39 pattern (real data from sonnet)
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 38.0),
            UsageSnapshot(date: Date().addingTimeInterval(-4), percentage: 0.0),
            UsageSnapshot(date: Date().addingTimeInterval(-2), percentage: 39.0),
            UsageSnapshot(date: Date().addingTimeInterval(-1), percentage: 0.0),
            UsageSnapshot(date: Date(), percentage: 39.0),
        ]
        let result = BurnUpChartView.despike(snapshots)
        XCTAssertEqual(result.count, 3, "Both transient 0% spikes should be removed")
        XCTAssertTrue(result.allSatisfy { $0.percentage > 0 }, "No zero-spikes should remain")
    }

    func testDespikeKeepsSpikeExceedingRevertWindow() {
        // Spike that takes longer than 5 minutes to revert — kept as real data
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-600), percentage: 50.0),
            UsageSnapshot(date: Date().addingTimeInterval(-400), percentage: 0.0),
            UsageSnapshot(date: Date(), percentage: 51.0), // 400s between spike and revert > 300s
        ]
        let result = BurnUpChartView.despike(snapshots)
        XCTAssertEqual(result.count, 3, "Slow revert should be kept")
    }

    func testDespikeKeepsSmallFluctuations() {
        // Below threshold — 10-point jump is not a spike
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 50.0),
            UsageSnapshot(date: Date().addingTimeInterval(-2), percentage: 40.0),
            UsageSnapshot(date: Date(), percentage: 51.0),
        ]
        let result = BurnUpChartView.despike(snapshots)
        XCTAssertEqual(result.count, 3, "Small fluctuation should be preserved")
    }

    func testDespikeEmptyInput() {
        XCTAssertEqual(BurnUpChartView.despike([]).count, 0)
    }

    func testDespikeSinglePoint() {
        let snap = [UsageSnapshot(date: Date(), percentage: 50.0)]
        XCTAssertEqual(BurnUpChartView.despike(snap).count, 1)
    }

    func testDespikeTwoPoints() {
        let snaps = [
            UsageSnapshot(date: Date().addingTimeInterval(-1), percentage: 50.0),
            UsageSnapshot(date: Date(), percentage: 0.0),
        ]
        XCTAssertEqual(BurnUpChartView.despike(snaps).count, 2, "Two points can't form a spike")
    }

    // MARK: - Reset Detection

    func testLastResetIndexDetectsRealReset() {
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-300), percentage: 98.0),
            UsageSnapshot(date: Date().addingTimeInterval(-200), percentage: 0.0),
            UsageSnapshot(date: Date().addingTimeInterval(-100), percentage: 2.0),
            UsageSnapshot(date: Date(), percentage: 4.0),
        ]
        let idx = BurnUpChartView.lastResetIndex(in: snapshots)
        XCTAssertEqual(idx, 1, "Should find reset at the 0% point")
    }

    func testLastResetIndexIgnoresTransient() {
        // 50→0→51: looks like a reset but reverts immediately (doesn't stay low)
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 50.0),
            UsageSnapshot(date: Date().addingTimeInterval(-2), percentage: 0.0),
            UsageSnapshot(date: Date(), percentage: 51.0),
        ]
        let idx = BurnUpChartView.lastResetIndex(in: snapshots)
        XCTAssertNil(idx, "Transient drop should not be detected as reset")
    }

    func testLastResetIndexFindsLastReset() {
        // Two resets — should return the later one
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-500), percentage: 90.0),
            UsageSnapshot(date: Date().addingTimeInterval(-400), percentage: 0.0),
            UsageSnapshot(date: Date().addingTimeInterval(-300), percentage: 5.0),
            UsageSnapshot(date: Date().addingTimeInterval(-200), percentage: 60.0),
            UsageSnapshot(date: Date().addingTimeInterval(-100), percentage: 0.0),
            UsageSnapshot(date: Date().addingTimeInterval(-50), percentage: 3.0),
            UsageSnapshot(date: Date(), percentage: 5.0),
        ]
        let idx = BurnUpChartView.lastResetIndex(in: snapshots)
        XCTAssertEqual(idx, 4, "Should return the later reset")
    }

    func testLastResetIndexNoResetInCleanData() {
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-120), percentage: 10.0),
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 20.0),
            UsageSnapshot(date: Date(), percentage: 30.0),
        ]
        XCTAssertNil(BurnUpChartView.lastResetIndex(in: snapshots))
    }

    func testLastResetIndexSmallDrop() {
        // 25-point drop is below the 30-point threshold
        let snapshots = [
            UsageSnapshot(date: Date().addingTimeInterval(-60), percentage: 50.0),
            UsageSnapshot(date: Date().addingTimeInterval(-30), percentage: 25.0),
            UsageSnapshot(date: Date(), percentage: 26.0),
        ]
        XCTAssertNil(BurnUpChartView.lastResetIndex(in: snapshots))
    }

    // MARK: - Anchor Logic (chartDisplaySnapshots)

    func testAnchorCarriedForwardWhenNoReset() {
        let windowStart = Date().addingTimeInterval(-3600)
        let windowEnd = Date()
        // Pre-window value is 50%, first in-window is 52% — no reset
        let snapshots = [
            UsageSnapshot(date: windowStart.addingTimeInterval(-60), percentage: 50.0),
            UsageSnapshot(date: windowStart.addingTimeInterval(60), percentage: 52.0),
        ]
        let result = BurnUpChartView.chartDisplaySnapshots(
            from: snapshots, windowStart: windowStart, windowEnd: windowEnd, now: Date()
        )
        // Origin should carry forward 50%
        XCTAssertEqual(result.first?.percentage, 50.0, "Anchor should carry forward pre-window value")
    }

    func testAnchorDroppedAfterReset() {
        let windowStart = Date().addingTimeInterval(-3600)
        let windowEnd = Date()
        // Pre-window value is 90%, in-window starts at 0% (reset) then ramps
        let snapshots = [
            UsageSnapshot(date: windowStart.addingTimeInterval(-60), percentage: 90.0),
            UsageSnapshot(date: windowStart.addingTimeInterval(60), percentage: 0.0),
            UsageSnapshot(date: windowStart.addingTimeInterval(120), percentage: 2.0),
            UsageSnapshot(date: windowStart.addingTimeInterval(180), percentage: 4.0),
        ]
        let result = BurnUpChartView.chartDisplaySnapshots(
            from: snapshots, windowStart: windowStart, windowEnd: windowEnd, now: Date()
        )
        // Origin should be 0% (not 90%) because a reset occurred
        XCTAssertEqual(result.first?.percentage, 0.0, "Anchor should be 0% after reset")
    }

    func testAnchorDefaultsToZeroWithNoPreWindowData() {
        let windowStart = Date().addingTimeInterval(-3600)
        let windowEnd = Date()
        let snapshots = [
            UsageSnapshot(date: windowStart.addingTimeInterval(60), percentage: 5.0),
        ]
        let result = BurnUpChartView.chartDisplaySnapshots(
            from: snapshots, windowStart: windowStart, windowEnd: windowEnd, now: Date()
        )
        XCTAssertEqual(result.first?.percentage, 0.0, "No pre-window data should default to 0%")
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
