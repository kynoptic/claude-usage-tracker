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

    /// Downsample to at most this many points for rendering performance
    private static let maxPoints = 200

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

        let origin = UsageSnapshot(date: windowStart, percentage: anchorPercentage)
        let windowSnapshots = snapshots.filter { $0.date >= windowStart }
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

    // MARK: - Zone Calculation

    /// Maps a raw usage percentage to a zone for historical chart coloring.
    ///
    /// Thresholds (raw percentage):
    /// ```
    ///   green   0–80%
    ///   yellow  80–95%
    ///   orange  95–105%
    ///   red     > 105%
    /// ```
    static func zone(forPercentage percentage: Double) -> UsageZone {
        switch percentage {
        case ..<80:
            return .green
        case 80..<95:
            return .yellow
        case 95...105:
            return .orange
        default:
            return .red
        }
    }

    /// Color for a given usage zone, using Apple system colors.
    static func color(for zone: UsageZone) -> Color {
        switch zone {
        case .grey:   return Color(nsColor: .systemGray)
        case .green:  return Color(nsColor: .systemGreen)
        case .yellow: return Color(nsColor: .systemYellow)
        case .orange: return Color(nsColor: .systemOrange)
        case .red:    return Color(nsColor: .systemRed)
        }
    }

    // MARK: - Segment Computation

    /// Splits snapshots into contiguous segments by usage zone.
    /// Adjacent segments share a boundary point for visual continuity.
    static func colorSegments(from snapshots: [UsageSnapshot]) -> [ColorSegment] {
        guard let first = snapshots.first else { return [] }

        var segments: [ColorSegment] = []
        var currentZone = zone(forPercentage: first.percentage)
        var currentPoints = [first]

        for snapshot in snapshots.dropFirst() {
            let snapshotZone = zone(forPercentage: snapshot.percentage)
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
        let segments = Self.colorSegments(from: displaySnapshots)

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
