import SwiftUI
import Charts

/// Burn-up chart showing usage progression over a time window.
/// Displayed on the back face of flipped SmartUsageCard instances.
@available(macOS 14.0, *)
struct BurnUpChartView: View {
    let snapshots: [UsageSnapshot]
    let isPrimary: Bool
    let windowStart: Date
    let windowEnd: Date
    let statusColor: Color
    let showRemaining: Bool

    /// Downsample to at most this many points for rendering performance
    private static let maxPoints = 200

    private var displaySnapshots: [UsageSnapshot] {
        guard snapshots.count > Self.maxPoints else { return snapshots }
        let stride = max(snapshots.count / Self.maxPoints, 1)
        return Swift.stride(from: 0, to: snapshots.count, by: stride).map { snapshots[$0] }
    }

    private var chartHeight: CGFloat {
        isPrimary ? 80 : 50
    }

    var body: some View {
        if snapshots.isEmpty {
            emptyState
        } else {
            chart
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            // Burn-up area + line
            ForEach(displaySnapshots) { snapshot in
                let yValue = showRemaining ? 100.0 - snapshot.percentage : snapshot.percentage

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

            // Pace line: even consumption from 0% to 100% (or inverted)
            let paceStart: Double = showRemaining ? 100.0 : 0.0
            let paceEnd: Double = showRemaining ? 0.0 : 100.0

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
            RuleMark(x: .value("Now", Date()))
                .foregroundStyle(Color(nsColor: .labelColor).opacity(0.25))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
        }
        .chartXScale(domain: windowStart ... windowEnd)
        .chartYScale(domain: 0 ... 100)
        .chartXAxis(isPrimary ? .automatic : .hidden)
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
