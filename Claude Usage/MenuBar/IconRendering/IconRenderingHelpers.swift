//
//  IconRenderingHelpers.swift
//  Claude Usage
//
//  Shared drawing utilities for menu bar icon rendering.
//

import Cocoa

// MARK: - Drawing Utilities

/// Returns the appropriate foreground color for menu bar icons based on appearance.
/// `NSColor.labelColor` doesn't resolve correctly in image drawing contexts.
func menuBarForegroundColor(isDarkMode: Bool) -> NSColor {
    return isDarkMode ? .white : .black
}

/// Returns the appropriate color based on mode settings
func iconColor(for status: UsageStatus, monochromeMode: Bool, useSystemColor: Bool, isDarkMode: Bool) -> NSColor {
    if monochromeMode || useSystemColor {
        return menuBarForegroundColor(isDarkMode: isDarkMode)
    } else {
        return UsageStatusCalculator.color(for: status)
    }
}

/// Draws the time-elapsed tick mark (clear gap + white stroke) onto any bar or ring path.
/// Guards against a missing graphics context so this is safe to call from any drawing block.
func drawTimeMarkerTick(_ path: NSBezierPath) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.saveGState()
    ctx.setBlendMode(.clear)
    path.lineWidth = 3.0
    path.lineCapStyle = .butt
    path.stroke()
    ctx.restoreGState()
    NSColor.white.setStroke()
    path.lineWidth = 1.5
    path.stroke()
}

/// Calculates the fraction of elapsed time within a period for the time marker
func calculateTimeMarkerFraction(
    metricType: MenuBarMetricType,
    usage: ClaudeUsage,
    showRemaining: Bool
) -> CGFloat? {
    let resetTime: Date?
    let duration: TimeInterval

    switch metricType {
    case .session:
        resetTime = usage.sessionResetTime
        duration = Constants.sessionWindow
    case .week:
        resetTime = usage.weeklyResetTime
        duration = Constants.weeklyWindow
    case .api:
        return nil
    }

    guard let f = UsageStatusCalculator.elapsedFraction(resetTime: resetTime, duration: duration, showRemaining: showRemaining) else { return nil }
    return CGFloat(f)
}

/// Formats token count intelligently (e.g., 1M instead of 1000K)
func formatTokenCount(_ used: Int, _ limit: Int) -> String {
    func formatSingleValue(_ value: Int) -> String {
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000.0
            if millions.truncatingRemainder(dividingBy: 1.0) == 0 {
                return "\(Int(millions))M"
            } else {
                return String(format: "%.1fM", millions)
            }
        } else if value >= 1_000 {
            let thousands = Double(value) / 1_000.0
            if thousands.truncatingRemainder(dividingBy: 1.0) == 0 {
                return "\(Int(thousands))K"
            } else {
                return String(format: "%.1fK", thousands)
            }
        } else {
            return "\(value)"
        }
    }

    return "\(formatSingleValue(used))/\(formatSingleValue(limit))"
}
