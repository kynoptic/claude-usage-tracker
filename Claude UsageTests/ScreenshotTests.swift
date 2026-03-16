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
            metric: nil
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
            metric: nil
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
            metric: nil
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
            appearance: CardAppearance(isStale: true)
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
            metric: nil
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
        _ = makeSnapshots(count: 15, maxPct: 50)
        _ = makeSnapshots(count: 30, maxPct: 35)

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
                metric: nil
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
                    metric: nil
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
                    metric: nil
                )
            }
        }
        .padding(16)
        .background(.regularMaterial)

        try renderToPNG(view, size: CGSize(width: 320, height: 400), name: "composite_dashboard")
    }

    func testCompositeDashboard_lightMode() throws {
        _ = makeSnapshots(count: 15, maxPct: 50)
        _ = makeSnapshots(count: 30, maxPct: 35)

        let view = VStack(spacing: 16) {
            SmartUsageCard(
                title: "Session Usage",
                subtitle: "5-hour window",
                usedPercentage: 19,
                showRemaining: false,
                resetTime: Self.sessionResetTime,
                isPrimary: true,
                periodDuration: Constants.sessionWindow,
                showTimeMarker: true,
                metric: nil
            )

            HStack(spacing: 12) {
                SmartUsageCard(
                    title: "All Models",
                    subtitle: "Weekly",
                    usedPercentage: 67,
                    showRemaining: false,
                    resetTime: Self.weeklyResetTime,
                    isPrimary: false,
                    periodDuration: Constants.weeklyWindow,
                    showTimeMarker: true,
                    metric: nil
                )

                SmartUsageCard(
                    title: "Sonnet",
                    subtitle: "Weekly",
                    usedPercentage: 39,
                    showRemaining: false,
                    resetTime: Self.weeklyResetTime,
                    isPrimary: false,
                    periodDuration: Constants.weeklyWindow,
                    showTimeMarker: false,
                    metric: nil
                )
            }
        }
        .padding(16)
        .background(.regularMaterial)

        try renderToPNG(view, size: CGSize(width: 320, height: 400), name: "composite_dashboard_light", colorScheme: .light)
    }

    func testAccessibleColors_darkMode() throws {
        let zones: [(String, Double)] = [
            ("Green (on track)", 70),
            ("Yellow (maximizing)", 95),
            ("Orange (overshooting)", 120),
        ]
        let view = VStack(spacing: 10) {
            ForEach(zones, id: \.0) { label, pct in
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .padding(.leading, 4)
                    SmartUsageCard(
                        title: "All models",
                        subtitle: "Weekly",
                        usedPercentage: pct,
                        showRemaining: false,
                        resetTime: Self.weeklyResetTime,
                        isPrimary: false,
                        periodDuration: Constants.weeklyWindow,
                        showTimeMarker: false,
                        metric: nil
                    )
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
        try renderToPNG(view, size: CGSize(width: 260, height: 420), name: "accessible_colors_dark", colorScheme: .dark)
    }

    func testAccessibleColors_lightMode() throws {
        let zones: [(String, Double)] = [
            ("Green (on track)", 70),
            ("Yellow (maximizing)", 95),
            ("Orange (overshooting)", 120),
        ]
        let view = VStack(spacing: 10) {
            ForEach(zones, id: \.0) { label, pct in
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        .padding(.leading, 4)
                    SmartUsageCard(
                        title: "All models",
                        subtitle: "Weekly",
                        usedPercentage: pct,
                        showRemaining: false,
                        resetTime: Self.weeklyResetTime,
                        isPrimary: false,
                        periodDuration: Constants.weeklyWindow,
                        showTimeMarker: false,
                        metric: nil
                    )
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
        try renderToPNG(view, size: CGSize(width: 260, height: 420), name: "accessible_colors_light", colorScheme: .light)
    }

    func testSessionCard_yellow_lightMode() throws {
        let view = SmartUsageCard(
            title: "All models",
            subtitle: "Weekly",
            usedPercentage: 95,
            showRemaining: false,
            resetTime: Self.weeklyResetTime,
            isPrimary: false,
            periodDuration: Constants.weeklyWindow,
            showTimeMarker: true,
            metric: nil
        )
        try renderToPNG(view, size: CGSize(width: 200, height: 110), name: "yellow_light_mode", colorScheme: .light)
    }

    // MARK: - Yellow Contrast Prototypes (temporary — remove after decision)

    /// Renders all yellow contrast techniques side by side in light mode for comparison.
    func testYellowContrast_allVariants() throws {
        let yellow = Color(nsColor: .systemYellow)
        let resetLabel = "Resets Mar 18, 5:59PM"

        let cards = VStack(spacing: 10) {

            // A: Baseline — original yellow, no treatment
            YellowPrototypeCard(
                title: "All models", subtitle: "Weekly",
                percentage: 66, resetLabel: resetLabel,
                statusColor: yellow,
                cardBackground: Color(nsColor: .controlBackgroundColor).opacity(0.4),
                label: "A: Original yellow (baseline — hard to read)"
            ) { icon, pct in
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(yellow)
                    Text(pct).foregroundColor(yellow)
                }
            }

            // B: Text shadow — tight dark shadow, no hue change
            YellowPrototypeCard(
                title: "All models", subtitle: "Weekly",
                percentage: 66, resetLabel: resetLabel,
                statusColor: yellow,
                cardBackground: Color(nsColor: .controlBackgroundColor).opacity(0.4),
                label: "B: Text shadow (0.5px + 1.5px, black 40%/20%)"
            ) { icon, pct in
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(yellow)
                        .shadow(color: .black.opacity(0.4), radius: 0.5, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 0)
                    Text(pct).foregroundColor(yellow)
                        .shadow(color: .black.opacity(0.4), radius: 0.5, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.2), radius: 1.5, x: 0, y: 0)
                }
            }

            // C: Blur halo — blurred dark underlay + sharp yellow
            YellowPrototypeCard(
                title: "All models", subtitle: "Weekly",
                percentage: 66, resetLabel: resetLabel,
                statusColor: yellow,
                cardBackground: Color(nsColor: .controlBackgroundColor).opacity(0.4),
                label: "C: Blur halo (ZStack dark blur + yellow)"
            ) { icon, pct in
                HStack(spacing: 4) {
                    ZStack {
                        Image(systemName: "flame.fill").foregroundColor(.black.opacity(0.4)).blur(radius: 2)
                        Image(systemName: "flame.fill").foregroundColor(yellow)
                    }
                    ZStack {
                        Text(pct).foregroundColor(.black.opacity(0.4)).blur(radius: 2)
                        Text(pct).foregroundColor(yellow)
                    }
                }
            }

            // D: Local scrim — translucent dark backing behind indicator only
            YellowPrototypeCard(
                title: "All models", subtitle: "Weekly",
                percentage: 66, resetLabel: resetLabel,
                statusColor: yellow,
                cardBackground: Color(nsColor: .controlBackgroundColor).opacity(0.4),
                label: "D: Local scrim (black 8% behind indicator)"
            ) { icon, pct in
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(yellow)
                    Text(pct).foregroundColor(yellow)
                }
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.black.opacity(0.08).cornerRadius(5))
            }

            // E: Darker card background — card darkens in yellow zone
            YellowPrototypeCard(
                title: "All models", subtitle: "Weekly",
                percentage: 66, resetLabel: resetLabel,
                statusColor: yellow,
                cardBackground: Color(white: 0.78).opacity(0.65),
                label: "E: Darker card background (white 78%, 65%)"
            ) { icon, pct in
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(yellow)
                    Text(pct).foregroundColor(yellow)
                }
            }

            // F: Dark card (HUD style) — dark background, full yellow
            YellowPrototypeCard(
                title: "All models", subtitle: "Weekly",
                percentage: 66, resetLabel: resetLabel,
                statusColor: yellow,
                cardBackground: Color(white: 0.18),
                label: "F: Dark card / HUD style",
                invertText: true
            ) { icon, pct in
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundColor(yellow)
                    Text(pct).foregroundColor(yellow)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))

        try renderToPNG(cards,
                        size: CGSize(width: 340, height: 580),
                        name: "yellow_contrast_prototypes",
                        colorScheme: .light)
    }

    // MARK: - Helpers

    /// Render a SwiftUI view to a PNG file in `.screenshots/`
    private func renderToPNG<V: View>(_ view: V, size: CGSize, name: String, colorScheme: ColorScheme = .dark) throws {
        let hosted = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme)

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
        window: TimeInterval = 5 * 60 * 60
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

// MARK: - Yellow Prototype Card (temporary helper — remove with yellow contrast tests)

/// Standalone card that reproduces the SmartUsageCard layout with a swappable indicator slot,
/// used for side-by-side yellow contrast prototype screenshots.
private struct YellowPrototypeCard<Indicator: View>: View {
    let title: String
    let subtitle: String
    let percentage: Int
    let resetLabel: String
    let statusColor: Color
    let cardBackground: Color
    let label: String
    var invertText: Bool = false
    @ViewBuilder let indicator: (String, String) -> Indicator

    private var textColor: Color { invertText ? Color(white: 0.85) : .primary }
    private var secondaryTextColor: Color { invertText ? Color(white: 0.55) : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Caption above card
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .padding(.leading, 4)

            // Card
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(textColor)
                        Text(subtitle)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(secondaryTextColor)
                    }
                    Spacer()
                    indicator("flame.fill", "\(percentage)%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [statusColor, statusColor.opacity(0.8)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * min(Double(percentage) / 100.0, 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(height: 8)

                HStack {
                    Spacer()
                    Text(resetLabel)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(secondaryTextColor)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(cardBackground))
        }
    }
}
