import XCTest
import SwiftUI
@testable import Claude_Usage

/// Verifies HSB colour interpolation via UsageStatusCalculator.color(for:).
/// Hue ranges: 0.0–0.4 → 120° (green), 0.4–0.5 → 120°→60°, 0.5–1.0 → 60°→0° (red).
final class ColorInterpolationTests: XCTestCase {

    private func nsColor(severity: Double, zone: UsageZone = .green) -> NSColor {
        let status = UsageStatus(zone: zone, severity: severity, actionText: "")
        return UsageStatusCalculator.color(for: status).usingColorSpace(.deviceRGB)!
    }

    private func hue(severity: Double, zone: UsageZone = .green) -> CGFloat {
        var h: CGFloat = 0
        nsColor(severity: severity, zone: zone).getHue(&h, saturation: nil, brightness: nil, alpha: nil)
        return h * 360.0  // degrees
    }

    private func saturation(severity: Double, zone: UsageZone = .green) -> CGFloat {
        var s: CGFloat = 0
        nsColor(severity: severity, zone: zone).getHue(nil, saturation: &s, brightness: nil, alpha: nil)
        return s
    }

    // MARK: - Green zone (severity 0.0–0.4)

    func testSeverity0_HueIsGreen() {
        XCTAssertEqual(hue(severity: 0.0), 120.0, accuracy: 1.0)
    }

    func testSeverity0_SaturationIsLow() {
        // At severity=0, saturation should be ~10%
        XCTAssertEqual(saturation(severity: 0.0), 0.10, accuracy: 0.02)
    }

    func testSeverity04_HueIsGreen_FullSaturation() {
        // At severity=0.4 (end of green zone), still green hue but full saturation
        XCTAssertEqual(hue(severity: 0.4), 120.0, accuracy: 2.0)
        XCTAssertEqual(saturation(severity: 0.4), 1.0, accuracy: 0.02)
    }

    func testSeverityMidGreen_SaturationRamps() {
        // Saturation at 0.2 should be between 10% and 100%
        let s = saturation(severity: 0.2)
        XCTAssertGreaterThan(s, 0.10)
        XCTAssertLessThan(s, 1.00)
    }

    // MARK: - Approach zone transition (severity 0.4–0.5)

    func testSeverity045_HueBetween60And120() {
        let h = hue(severity: 0.45)
        XCTAssertGreaterThan(h, 60.0)
        XCTAssertLessThan(h, 120.0)
    }

    func testSeverity05_HueIsYellow() {
        XCTAssertEqual(hue(severity: 0.5), 60.0, accuracy: 2.0)
    }

    // MARK: - Warning/Critical zone (severity 0.5–1.0)

    func testSeverity075_HueBetween0And60() {
        let h = hue(severity: 0.75)
        XCTAssertGreaterThan(h, 0.0)
        XCTAssertLessThan(h, 60.0)
    }

    func testSeverity1_HueIsRed() {
        // NSColor with hue=0 may report as 0° or 360° — both represent red.
        let h = hue(severity: 1.0)
        XCTAssertTrue(h < 2.0 || h > 358.0, "Expected red hue (0°/360°), got \(h)°")
    }

    // MARK: - Continuity at boundaries

    func testContinuityAt04_NoJump() {
        // Colours just below and just above 0.4 should be very close
        let hBelow = hue(severity: 0.39)
        let hAbove = hue(severity: 0.41)
        XCTAssertEqual(hBelow, hAbove, accuracy: 10.0)
    }

    func testContinuityAt05_NoJump() {
        let hBelow = hue(severity: 0.49)
        let hAbove = hue(severity: 0.51)
        XCTAssertEqual(hBelow, hAbove, accuracy: 10.0)
    }

    // MARK: - SwiftUI Color bridge

    func testSwiftUIColorBridge_GreenSeverity() {
        let status = UsageStatus(zone: .green, severity: 0.2, actionText: "On track ✅")
        // Color.usageStatus should not crash
        let color: SwiftUI.Color = .usageStatus(status)
        // Convert back to verify it's not clear/transparent
        _ = color  // just verify it compiles and doesn't throw
    }
}
