import SwiftUI
import Charts

/// A contiguous run of snapshots sharing the same usage zone color.
struct ColorSegment: Identifiable {
    let id = UUID()
    let zone: UsageZone
    let snapshots: [UsageSnapshot]
}

/// Burn-up chart showing usage progression over a time window.
/// Displayed on the back face of flipped SmartUsageCard instances.
struct BurnUpChartView: View {
    let snapshots: [UsageSnapshot]
    let isPrimary: Bool
    let windowStart: Date
    let windowEnd: Date
    let statusColor: Color
    var isStale: Bool = false
    var chartColorMode: ChartColorMode = .uniform
    var showGreyZone: Bool = false
    var greyThreshold: Double = Constants.greyThresholdDefault

    /// Downsample to at most this many points for rendering performance
    private static let maxPoints = 200

    // MARK: - Filter Thresholds

    /// Minimum percentage-point drop to qualify as a spike or reset.
    static let glitchThreshold: Double = 30.0

    /// Maximum seconds between a spike and its revert to be considered transient.
    static let spikeRevertWindow: TimeInterval = 300

    /// How far below the pre-drop level post-reset values must stay to confirm
    /// the drop is a real reset (not a transient). Applied as: `< preDrop - margin`.
    static let resetConfirmationMargin: Double = 20.0

    /// Chart data with a synthetic origin at windowStart.
    /// Carries forward the last pre-window percentage (anchor) so graphs
    /// don't drop to zero after app updates or data gaps.
    /// Appends a synthetic "now" point so the line extends to the current time
    /// even when the percentage hasn't changed between polls.
    private var displaySnapshots: [UsageSnapshot] {
        Self.chartDisplaySnapshots(
            from: snapshots,
            windowStart: windowStart,
            windowEnd: windowEnd,
            maxPoints: Self.maxPoints,
            now: now
        )
    }

    /// Testable computation of display snapshots for the chart.
    /// Separated from the view property so unit tests can verify the logic.
    static func chartDisplaySnapshots(
        from snapshots: [UsageSnapshot],
        windowStart: Date,
        windowEnd: Date,
        maxPoints: Int = 200,
        now: Date = Date()
    ) -> [UsageSnapshot] {
        // Find the last snapshot before windowStart to use as the carry-forward
        // anchor. This prevents artificial zero-drops after app updates.
        let preWindowSnapshots = snapshots.filter { $0.date < windowStart }
        let anchorPercentage = preWindowSnapshots.last?.percentage ?? 0.0

        var windowSnapshots = despike(snapshots.filter { $0.date >= windowStart })

        // Detect the last major reset (drop ≥30 points that persists) within
        // the window. Everything before it is stale previous-period data.
        if let resetIndex = lastResetIndex(in: windowSnapshots) {
            windowSnapshots = Array(windowSnapshots[resetIndex...])
        }

        // Only carry forward the anchor if no reset occurred — a reset means
        // the period started fresh at 0%.
        let originPercentage: Double
        if windowSnapshots.isEmpty {
            originPercentage = anchorPercentage
        } else if windowSnapshots.first!.percentage < anchorPercentage - Self.glitchThreshold {
            originPercentage = 0.0
        } else {
            originPercentage = anchorPercentage
        }

        let origin = UsageSnapshot(date: windowStart, percentage: originPercentage)
        var points = [origin] + windowSnapshots

        // Downsample if needed (skip origin when counting)
        if points.count > maxPoints {
            let stride = max(points.count / maxPoints, 1)
            points = Swift.stride(from: 0, to: points.count, by: stride).map { points[$0] }
        }

        // Extend the line to "now" — appended after downsampling so it's never dropped.
        if let last = windowSnapshots.last, now < windowEnd {
            points.append(UsageSnapshot(date: now, percentage: last.percentage))
        }

        return points
    }

    // MARK: - Reset Detection

    /// Finds the index of the last major reset (drop ≥30 points) in the snapshots
    /// where the value stays low (doesn't revert). Returns nil if no reset found.
    static func lastResetIndex(in snapshots: [UsageSnapshot]) -> Int? {
        guard snapshots.count >= 2 else { return nil }

        var lastReset: Int?
        for i in 1..<snapshots.count {
            let drop = snapshots[i - 1].percentage - snapshots[i].percentage
            // A real reset: big drop AND value stays below the pre-drop level
            if drop >= glitchThreshold {
                // Check it's not a transient — value should stay low
                let postValues = snapshots[i...].prefix(3)
                let staysLow = postValues.allSatisfy { $0.percentage < snapshots[i - 1].percentage - resetConfirmationMargin }
                if staysLow {
                    lastReset = i
                }
            }
        }
        return lastReset
    }

    // MARK: - Spike Removal

    /// Removes transient API glitches: a snapshot that jumps ≥30 percentage points
    /// from its neighbours and reverts within 5 minutes is dropped.
    /// Runs iteratively to handle chained glitches (e.g. 38→0→39→0→39).
    static func despike(_ snapshots: [UsageSnapshot]) -> [UsageSnapshot] {
        let spikeThreshold = glitchThreshold
        let revertWindow = spikeRevertWindow

        var current = snapshots
        while current.count >= 3 {
            var result = [current[0]]
            var removed = false

            for i in 1..<(current.count - 1) {
                let prev = result.last!  // compare against last kept point
                let curr = current[i]
                let next = current[i + 1]

                let jumpFromPrev = abs(curr.percentage - prev.percentage)
                let jumpToNext = abs(next.percentage - curr.percentage)
                let prevToNext = abs(next.percentage - prev.percentage)
                // Measure spike duration: how quickly does it revert?
                let spikeDuration = next.date.timeIntervalSince(curr.date)

                let isSpike = jumpFromPrev >= spikeThreshold
                    && jumpToNext >= spikeThreshold
                    && prevToNext < spikeThreshold
                    && spikeDuration < revertWindow

                if isSpike {
                    removed = true
                } else {
                    result.append(curr)
                }
            }

            result.append(current.last!)
            current = result
            if !removed { break }
        }
        return current
    }

    // MARK: - Zone Calculation

    /// Maps a snapshot to a zone using the same pacing-projected thresholds
    /// as `UsageStatusCalculator`. The elapsed fraction is derived from the
    /// snapshot's position within the chart window.
    ///
    /// Projection = `(percentage / 100) / elapsedFraction`, then:
    /// ```
    ///   green   projected < 0.9
    ///   yellow  0.9–1.1
    ///   orange  1.1–1.5
    ///   red     > 1.5
    /// ```
    static func zone(forPercentage percentage: Double, elapsedFraction: Double? = nil) -> UsageZone {
        let status = UsageStatusCalculator.calculateStatus(
            usedPercentage: percentage,
            showRemaining: false,
            elapsedFraction: elapsedFraction
        )
        return status.zone
    }

    /// Compute elapsed fraction for a date within a time window.
    static func elapsedFraction(for date: Date, windowStart: Date, windowEnd: Date) -> Double? {
        let duration = windowEnd.timeIntervalSince(windowStart)
        guard duration > 0 else { return nil }
        let elapsed = date.timeIntervalSince(windowStart)
        return min(max(elapsed / duration, 0), 1)
    }

    /// Color for a given usage zone, using Apple system colors.
    static func color(for zone: UsageZone) -> Color {
        switch zone {
        case .grey:   return Color(nsColor: .systemGray)
        case .green:  return Color(nsColor: .systemGreen)
        case .yellow: return Color("UsageYellow")
        case .orange: return Color(nsColor: .systemOrange)
        case .red:    return Color(nsColor: .systemRed)
        }
    }

    // MARK: - Segment Computation

    /// Splits snapshots into contiguous segments by usage zone.
    /// Adjacent segments share a boundary point for visual continuity.
    /// Uses pacing-projected zones (matching UsageStatusCalculator) when
    /// window bounds are provided.
    static func colorSegments(
        from snapshots: [UsageSnapshot],
        windowStart: Date? = nil,
        windowEnd: Date? = nil,
        showGrey: Bool = false,
        greyThreshold: Double = Constants.greyThresholdDefault
    ) -> [ColorSegment] {
        guard let first = snapshots.first else { return [] }

        func zoneFor(_ snapshot: UsageSnapshot) -> UsageZone {
            let elapsed: Double?
            if let ws = windowStart, let we = windowEnd {
                elapsed = elapsedFraction(for: snapshot.date, windowStart: ws, windowEnd: we)
            } else {
                elapsed = nil
            }
            let status = UsageStatusCalculator.calculateStatus(
                usedPercentage: snapshot.percentage,
                showRemaining: false,
                elapsedFraction: elapsed,
                showGrey: showGrey,
                greyThreshold: greyThreshold
            )
            return status.zone
        }

        var segments: [ColorSegment] = []
        var currentZone = zoneFor(first)
        var currentPoints = [first]

        for snapshot in snapshots.dropFirst() {
            let snapshotZone = zoneFor(snapshot)
            if snapshotZone != currentZone {
                // Close current segment — include this point as bridge
                currentPoints.append(snapshot)
                segments.append(ColorSegment(zone: currentZone, snapshots: currentPoints))

                // Start new segment from this bridge point
                currentZone = snapshotZone
                currentPoints = [snapshot]
            } else {
                currentPoints.append(snapshot)
            }
        }

        // Close final segment
        if !currentPoints.isEmpty {
            segments.append(ColorSegment(zone: currentZone, snapshots: currentPoints))
        }

        return segments
    }

    /// Whether this chart covers a weekly (multi-day) window vs a session window
    private var isWeeklyWindow: Bool {
        windowEnd.timeIntervalSince(windowStart) > Constants.sessionWindow * 2
    }

    private var chartHeight: CGFloat {
        isPrimary ? 80 : 50
    }

    var body: some View {
        if snapshots.isEmpty {
            emptyState
        } else {
            // TimelineView forces a re-render every 60 s so `now` stays current
            // even when usage data hasn't changed (common for the weekly chart).
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                chart
            }
        }
    }

    // MARK: - Chart

    private var startLabel: String {
        if isWeeklyWindow {
            return windowStart.formatted(.dateTime.month(.abbreviated).day())
        }
        return windowStart.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
    }

    private var endLabel: String {
        if isWeeklyWindow {
            return windowEnd.formatted(.dateTime.month(.abbreviated).day())
        }
        return windowEnd.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).minute())
    }

    private var chart: some View {
        VStack(spacing: 2) {
            chartContent
            // Start / End labels below chart
            HStack {
                Text(startLabel)
                Spacer()
                Text(endLabel)
            }
            .font(.system(size: isPrimary ? 7 : 6))
            .foregroundStyle(.secondary)
        }
    }

    /// Pinned once per render to avoid Date() re-evaluation inside the chart body
    private var now: Date { Date() }

    private var chartContent: some View {
        Chart {
            if chartColorMode == .historical {
                historicalMarks
            } else {
                uniformMarks
            }

            // Pace line: even consumption from 0% to 100%
            let paceStart: Double = 0.0
            let paceEnd: Double = 100.0

            LineMark(
                x: .value("Time", windowStart),
                y: .value("Pace", paceStart),
                series: .value("Series", "pace")
            )
            .foregroundStyle(Color(nsColor: .labelColor).opacity(0.3))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            LineMark(
                x: .value("Time", windowEnd),
                y: .value("Pace", paceEnd),
                series: .value("Series", "pace")
            )
            .foregroundStyle(Color(nsColor: .labelColor).opacity(0.3))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))

            // "Now" marker
            RuleMark(x: .value("Now", now))
                .foregroundStyle(Color(nsColor: .labelColor).opacity(0.25))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
        .chartXScale(domain: windowStart ... windowEnd)
        .chartYScale(domain: 0 ... 100)
        .chartXAxis {
            if isPrimary {
                AxisMarks { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                }
            } else if isWeeklyWindow {
                AxisMarks(values: .stride(by: .day, count: 1)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.secondary.opacity(0.2))
                }
            }
        }
        .chartYAxis {
            if isPrimary {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisValueLabel {
                        if let v = value.as(Int.self) {
                            Text("\(v)")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(height: chartHeight)
    }

    // MARK: - Uniform Rendering (existing behavior)

    @ChartContentBuilder
    private var uniformMarks: some ChartContent {
        ForEach(displaySnapshots) { snapshot in
            let yValue = snapshot.percentage

            AreaMark(
                x: .value("Time", snapshot.date),
                y: .value("Usage", yValue)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [statusColor.opacity(0.4), statusColor.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Time", snapshot.date),
                y: .value("Usage", yValue)
            )
            .foregroundStyle(statusColor)
            .lineStyle(StrokeStyle(lineWidth: 1.5))
            .interpolationMethod(.monotone)
        }
    }

    // MARK: - Historical Rendering (per-segment colors)

    @ChartContentBuilder
    private var historicalMarks: some ChartContent {
        let segments = Self.colorSegments(
            from: displaySnapshots,
            windowStart: windowStart,
            windowEnd: windowEnd,
            showGrey: showGreyZone,
            greyThreshold: greyThreshold
        )

        ForEach(segments) { segment in
            let segmentColor = Self.color(for: segment.zone)

            ForEach(segment.snapshots) { snapshot in
                AreaMark(
                    x: .value("Time", snapshot.date),
                    y: .value("Usage", snapshot.percentage),
                    series: .value("Segment", segment.id.uuidString)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [segmentColor.opacity(0.4), segmentColor.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", snapshot.date),
                    y: .value("Usage", snapshot.percentage),
                    series: .value("Segment", segment.id.uuidString)
                )
                .foregroundStyle(segmentColor)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.monotone)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: isPrimary ? 20 : 14))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("Collecting data...")
                .font(.system(size: isPrimary ? 10 : 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(height: chartHeight)
        .frame(maxWidth: .infinity)
    }
}
