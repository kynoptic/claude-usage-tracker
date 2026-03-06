import XCTest
import SwiftUI
@testable import Claude_Usage

/// Renders individual SwiftUI views to PNG files in `.screenshots/` for visual verification.
///
/// These tests do NOT assert pixels — they produce screenshots that a human (or Claude Code)
/// can inspect before and after UI changes. Run with:
///
/// ```
/// xcodebuild test -project "Claude Usage.xcodeproj" -scheme "Claude Usage" \
///   -only-testing:"Claude UsageTests/ScreenshotTests" \
///   -configuration Debug CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
/// ```
@MainActor
final class ScreenshotTests: XCTestCase {

    // MARK: - Properties

    /// Output directory: project root `.screenshots/`
    /// Searches upward from the source file for `Claude Usage.xcodeproj` to find the project root,
    /// which works regardless of whether `#file` resolves to the source tree or DerivedData.
    private static let outputDir: URL = {
        var dir = URL(fileURLWithPath: #file).deletingLastPathComponent()
        while dir.path != "/" {
            let marker = dir.appendingPathComponent("Claude Usage.xcodeproj")
            if FileManager.default.fileExists(atPath: marker.path) {
                return dir.appendingPathComponent(".screenshots")
            }
            dir = dir.deletingLastPathComponent()
        }
        // Fallback: write next to the test file
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent(".screenshots")
    }()

    /// Anchor date: 2025-01-15 12:00:00 UTC — deterministic across runs
    private static let anchorDate: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 1
        components.day = 15
        components.hour = 12
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: components)!
    }()

    private static let sessionResetTime = anchorDate.addingTimeInterval(Constants.sessionWindow)
    private static let weeklyResetTime = anchorDate.addingTimeInterval(Constants.weeklyWindow)

    // MARK: - Setup

    override func setUp() async throws {
        try await super.setUp()
        try FileManager.default.createDirectory(
            at: Self.outputDir,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Session Card Tests

    func testSessionCard_safe() throws {
        let view = SmartUsageCard(
            title: "Session Usage",
            subtitle: "5-hour window",
            usedPercentage: 25,
            showRemaining: false,
            resetTime: Self.sessionResetTime,
            isPrimary: true,
            periodDuration: Constants.sessionWindow,
            showTimeMarker: true,
            metric: nil,
            isStale: false
        )
        try renderToPNG(view, size: CGSize(width: 288, height: 120), name: "session_safe")
    }

    func testSessionCard_moderate() throws {
        let view = SmartUsageCard(
            title: "Session Usage",
            subtitle: "5-hour window",
            usedPercentage: 60,
            showRemaining: false,
            resetTime: Self.sessionResetTime,
            isPrimary: true,
            periodDuration: Constants.sessionWindow,
            showTimeMarker: true,
            metric: nil,
            isStale: false
        )
        try renderToPNG(view, size: CGSize(width: 288, height: 120), name: "session_moderate")
    }

    func testSessionCard_critical() throws {
        let view = SmartUsageCard(
            title: "Session Usage",
            subtitle: "5-hour window",
            usedPercentage: 90,
            showRemaining: false,
            resetTime: Self.sessionResetTime,
            isPrimary: true,
            periodDuration: Constants.sessionWindow,
            showTimeMarker: true,
            metric: nil,
            isStale: false
        )
        try renderToPNG(view, size: CGSize(width: 288, height: 120), name: "session_critical")
    }

    func testSessionCard_stale() throws {
        let view = SmartUsageCard(
            title: "Session Usage",
            subtitle: "5-hour window",
            usedPercentage: 45,
            showRemaining: false,
            resetTime: Self.sessionResetTime,
            isPrimary: true,
            periodDuration: Constants.sessionWindow,
            showTimeMarker: true,
            metric: nil,
            isStale: true
        )
        try renderToPNG(view, size: CGSize(width: 288, height: 120), name: "session_stale")
    }

    // MARK: - Weekly Card Test

    func testWeeklyCard_secondary() throws {
        let view = SmartUsageCard(
            title: "All Models",
            subtitle: "Weekly",
            usedPercentage: 40,
            showRemaining: false,
            resetTime: Self.weeklyResetTime,
            isPrimary: false,
            periodDuration: Constants.weeklyWindow,
            showTimeMarker: true,
            metric: nil,
            isStale: false
        )
        try renderToPNG(view, size: CGSize(width: 138, height: 100), name: "weekly_secondary")
    }

    // MARK: - BurnUpChart Tests

    func testBurnUpChart_withData() throws {
        let snapshots = makeSnapshots(count: 20, maxPct: 65)
        let view = BurnUpChartView(
            snapshots: snapshots,
            isPrimary: true,
            windowStart: Self.anchorDate,
            windowEnd: Self.sessionResetTime,
            statusColor: .green,
            isStale: false
        )
        try renderToPNG(view, size: CGSize(width: 288, height: 100), name: "chart_with_data")
    }

    func testBurnUpChart_empty() throws {
        let view = BurnUpChartView(
            snapshots: [],
            isPrimary: true,
            windowStart: Self.anchorDate,
            windowEnd: Self.sessionResetTime,
            statusColor: .green,
            isStale: false
        )
        try renderToPNG(view, size: CGSize(width: 288, height: 100), name: "chart_empty")
    }

    // MARK: - Composite Dashboard Approximation

    func testCompositeDashboard() throws {
        let sessionSnapshots = makeSnapshots(count: 15, maxPct: 50)
        let weeklySnapshots = makeSnapshots(count: 30, maxPct: 35)

        let view = VStack(spacing: 16) {
            // Primary session card
            SmartUsageCard(
                title: "Session Usage",
                subtitle: "5-hour window",
                usedPercentage: 50,
                showRemaining: false,
                resetTime: Self.sessionResetTime,
                isPrimary: true,
                periodDuration: Constants.sessionWindow,
                showTimeMarker: true,
                metric: nil,
                isStale: false
            )

            // Secondary cards side by side
            HStack(spacing: 12) {
                SmartUsageCard(
                    title: "All Models",
                    subtitle: "Weekly",
                    usedPercentage: 35,
                    showRemaining: false,
                    resetTime: Self.weeklyResetTime,
                    isPrimary: false,
                    periodDuration: Constants.weeklyWindow,
                    showTimeMarker: true,
                    metric: nil,
                    isStale: false
                )

                SmartUsageCard(
                    title: "Opus",
                    subtitle: "Weekly",
                    usedPercentage: 70,
                    showRemaining: false,
                    resetTime: Self.weeklyResetTime,
                    isPrimary: false,
                    periodDuration: Constants.weeklyWindow,
                    showTimeMarker: false,
                    metric: nil,
                    isStale: false
                )
            }
        }
        .padding(16)
        .background(.regularMaterial)

        try renderToPNG(view, size: CGSize(width: 320, height: 400), name: "composite_dashboard")
    }

    // MARK: - Helpers

    /// Render a SwiftUI view to a PNG file in `.screenshots/`
    private func renderToPNG<V: View>(_ view: V, size: CGSize, name: String) throws {
        let hosted = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: hosted)
        renderer.scale = 2.0 // Retina

        guard let nsImage = renderer.nsImage else {
            // ImageRenderer can return nil in headless CI environments without a display.
            // Skip gracefully rather than failing the build.
            try XCTSkipIf(true, "ImageRenderer returned nil for \(name) — likely headless environment")
            return
        }

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to convert image to PNG for \(name)")
            return
        }

        let url = Self.outputDir.appendingPathComponent("\(name).png")
        try pngData.write(to: url)

        // Verify file is non-empty
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attrs[.size] as? Int ?? 0
        XCTAssertGreaterThan(fileSize, 0, "Screenshot \(name).png is empty")
    }

    /// Generate deterministic chart snapshots spread across a time window
    private func makeSnapshots(
        count: Int,
        maxPct: Double,
        window: TimeInterval = Constants.sessionWindow
    ) -> [UsageSnapshot] {
        precondition(count >= 2, "makeSnapshots requires count >= 2")
        return (0..<count).map { i in
            let fraction = Double(i) / Double(count - 1)
            let date = Self.anchorDate.addingTimeInterval(fraction * window)
            // Gentle curve: percentage rises with slight acceleration
            let pct = maxPct * (fraction * fraction * 0.3 + fraction * 0.7)
            return UsageSnapshot(date: date, percentage: pct)
        }
    }
}
