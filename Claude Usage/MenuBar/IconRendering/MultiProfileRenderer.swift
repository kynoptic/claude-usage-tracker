//
//  MultiProfileRenderer.swift
//  Claude Usage
//
//  Renders multi-profile icon styles (concentric circles, progress bars, compact dots, default logo).
//

import Cocoa

/// Handles rendering of multi-profile icon styles for the menu bar
struct MultiProfileRenderer {

    // MARK: - Concentric Icon

    /// Creates a compact concentric circle icon for multi-profile display mode
    /// - Parameters:
    ///   - sessionPercentage: Session usage percentage (0-100)
    ///   - weekPercentage: Week usage percentage (0-100)
    ///   - sessionStatus: Status level for session (for coloring)
    ///   - weekStatus: Status level for week (for coloring)
    ///   - profileInitial: Single character to display in center (e.g., "W" for Work)
    ///   - monochromeMode: If true, use foreground color for all elements
    ///   - isDarkMode: Whether the menu bar is in dark mode
    ///   - useSystemColor: If true, use system accent color instead of status colors
    /// - Returns: NSImage with concentric circles showing both metrics
    func createConcentricIcon(
        sessionPercentage: Double,
        weekPercentage: Double,
        sessionStatus: UsageStatus,
        weekStatus: UsageStatus,
        profileInitial: String,
        monochromeMode: Bool,
        isDarkMode: Bool,
        useSystemColor: Bool = false
    ) -> NSImage {
        let size: CGFloat = 24
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()
        defer { image.unlockFocus() }

        let center = NSPoint(x: size / 2, y: size / 2)

        // Use isDarkMode to determine correct foreground color for menu bar
        let foregroundColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let textColor: NSColor = foregroundColor
        let sessionColor: NSColor = iconColor(for: sessionStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let weekColor: NSColor = iconColor(for: weekStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let backgroundColor: NSColor = foregroundColor.withAlphaComponent(0.15)

        // Outer ring (Session) - larger radius, thicker stroke - Session is primary/more important
        let outerRadius: CGFloat = (size - 4) / 2  // 10pt radius
        let outerStrokeWidth: CGFloat = 3.0

        // Background ring for outer
        let outerBgPath = NSBezierPath()
        outerBgPath.appendArc(
            withCenter: center,
            radius: outerRadius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        backgroundColor.setStroke()
        outerBgPath.lineWidth = outerStrokeWidth
        outerBgPath.stroke()

        // Session progress ring (outer - primary metric)
        if sessionPercentage > 0 {
            let sessionEndAngle = 90 - (360 * CGFloat(sessionPercentage / 100.0))
            let outerProgressPath = NSBezierPath()
            outerProgressPath.appendArc(
                withCenter: center,
                radius: outerRadius,
                startAngle: 90,
                endAngle: sessionEndAngle,
                clockwise: true
            )
            sessionColor.setStroke()
            outerProgressPath.lineWidth = outerStrokeWidth
            outerProgressPath.lineCapStyle = .round
            outerProgressPath.stroke()
        }

        // Inner ring (Week) - smaller radius, thinner stroke - Week is secondary
        let innerRadius: CGFloat = outerRadius - 4.5  // 5.5pt radius
        let innerStrokeWidth: CGFloat = 2.0

        // Background ring for inner
        let innerBgPath = NSBezierPath()
        innerBgPath.appendArc(
            withCenter: center,
            radius: innerRadius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        backgroundColor.setStroke()
        innerBgPath.lineWidth = innerStrokeWidth
        innerBgPath.stroke()

        // Week progress ring (inner - secondary metric)
        if weekPercentage > 0 {
            let weekEndAngle = 90 - (360 * CGFloat(weekPercentage / 100.0))
            let innerProgressPath = NSBezierPath()
            innerProgressPath.appendArc(
                withCenter: center,
                radius: innerRadius,
                startAngle: 90,
                endAngle: weekEndAngle,
                clockwise: true
            )
            weekColor.setStroke()
            innerProgressPath.lineWidth = innerStrokeWidth
            innerProgressPath.lineCapStyle = .round
            innerProgressPath.stroke()
        }

        // Profile initial in center
        let initial = String(profileInitial.prefix(1)).uppercased()
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .bold),
            .foregroundColor: textColor
        ]
        let labelString = initial as NSString
        let labelSize = labelString.size(withAttributes: labelAttributes)
        let labelX = center.x - labelSize.width / 2
        let labelY = center.y - labelSize.height / 2
        labelString.draw(at: NSPoint(x: labelX, y: labelY), withAttributes: labelAttributes)

        return image
    }

    // MARK: - Concentric Icon with Label

    /// Creates a concentric icon with profile label below for multi-profile mode
    /// - Returns: NSImage with concentric circles and profile name label
    func createConcentricIconWithLabel(
        sessionPercentage: Double,
        weekPercentage: Double,
        sessionStatus: UsageStatus,
        weekStatus: UsageStatus,
        profileName: String,
        monochromeMode: Bool,
        isDarkMode: Bool,
        useSystemColor: Bool = false
    ) -> NSImage {
        let circleSize: CGFloat = 20
        let labelHeight: CGFloat = 10
        let spacing: CGFloat = 1
        let totalHeight = circleSize + spacing + labelHeight
        let labelWidth: CGFloat = max(circleSize, CGFloat(profileName.prefix(3).count) * 6 + 4)
        let totalWidth = max(circleSize, labelWidth)

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))

        image.lockFocus()
        defer { image.unlockFocus() }

        let circleCenter = NSPoint(x: totalWidth / 2, y: totalHeight - circleSize / 2)

        // Use isDarkMode to determine correct foreground color for menu bar
        let foregroundColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let textColor: NSColor = foregroundColor
        let sessionColor: NSColor = iconColor(for: sessionStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let weekColor: NSColor = iconColor(for: weekStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let backgroundColor: NSColor = foregroundColor.withAlphaComponent(0.15)

        // Outer ring (Session) - Session is primary/more important
        let outerRadius: CGFloat = (circleSize - 4) / 2
        let outerStrokeWidth: CGFloat = 2.5

        // Background ring for outer
        let outerBgPath = NSBezierPath()
        outerBgPath.appendArc(
            withCenter: circleCenter,
            radius: outerRadius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        backgroundColor.setStroke()
        outerBgPath.lineWidth = outerStrokeWidth
        outerBgPath.stroke()

        // Session progress ring (outer - primary metric)
        if sessionPercentage > 0 {
            let sessionEndAngle = 90 - (360 * CGFloat(sessionPercentage / 100.0))
            let outerProgressPath = NSBezierPath()
            outerProgressPath.appendArc(
                withCenter: circleCenter,
                radius: outerRadius,
                startAngle: 90,
                endAngle: sessionEndAngle,
                clockwise: true
            )
            sessionColor.setStroke()
            outerProgressPath.lineWidth = outerStrokeWidth
            outerProgressPath.lineCapStyle = .round
            outerProgressPath.stroke()
        }

        // Inner ring (Week) - Week is secondary
        let innerRadius: CGFloat = outerRadius - 3.5
        let innerStrokeWidth: CGFloat = 1.5

        // Background ring for inner
        let innerBgPath = NSBezierPath()
        innerBgPath.appendArc(
            withCenter: circleCenter,
            radius: innerRadius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        backgroundColor.setStroke()
        innerBgPath.lineWidth = innerStrokeWidth
        innerBgPath.stroke()

        // Week progress ring (inner - secondary metric)
        if weekPercentage > 0 {
            let weekEndAngle = 90 - (360 * CGFloat(weekPercentage / 100.0))
            let innerProgressPath = NSBezierPath()
            innerProgressPath.appendArc(
                withCenter: circleCenter,
                radius: innerRadius,
                startAngle: 90,
                endAngle: weekEndAngle,
                clockwise: true
            )
            weekColor.setStroke()
            innerProgressPath.lineWidth = innerStrokeWidth
            innerProgressPath.lineCapStyle = .round
            innerProgressPath.stroke()
        }

        // Profile label below the circle (first 3 characters)
        let label = String(profileName.prefix(3))
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.85)
        ]
        let labelString = label as NSString
        let labelSize = labelString.size(withAttributes: labelAttributes)
        let labelX = (totalWidth - labelSize.width) / 2
        let labelY: CGFloat = 0
        labelString.draw(at: NSPoint(x: labelX, y: labelY), withAttributes: labelAttributes)

        return image
    }

    // MARK: - Multi-Profile Progress Bar Style

    /// Creates a progress bar style icon for multi-profile mode
    func createMultiProfileProgressBar(
        sessionPercentage: Double,
        weekPercentage: Double?,
        sessionStatus: UsageStatus,
        weekStatus: UsageStatus,
        profileName: String?,
        monochromeMode: Bool,
        isDarkMode: Bool,
        useSystemColor: Bool = false
    ) -> NSImage {
        let barWidth: CGFloat = 24
        let barHeight: CGFloat = 4
        let spacing: CGFloat = 2
        let labelHeight: CGFloat = profileName != nil ? 10 : 0
        let hasWeek = weekPercentage != nil

        let totalHeight = barHeight + (hasWeek ? spacing + barHeight : 0) + (profileName != nil ? spacing + labelHeight : 0)
        let totalWidth = barWidth

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))

        image.lockFocus()
        defer { image.unlockFocus() }

        // Use isDarkMode to determine correct foreground color for menu bar
        let foregroundColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let sessionColor: NSColor = iconColor(for: sessionStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let weekColor: NSColor = iconColor(for: weekStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let backgroundColor: NSColor = foregroundColor.withAlphaComponent(0.2)

        var currentY = totalHeight

        // Session bar (top)
        currentY -= barHeight
        let sessionBgRect = NSRect(x: 0, y: currentY, width: barWidth, height: barHeight)
        backgroundColor.setFill()
        NSBezierPath(roundedRect: sessionBgRect, xRadius: 2, yRadius: 2).fill()

        let sessionFillWidth = barWidth * CGFloat(sessionPercentage / 100.0)
        let sessionFillRect = NSRect(x: 0, y: currentY, width: sessionFillWidth, height: barHeight)
        sessionColor.setFill()
        NSBezierPath(roundedRect: sessionFillRect, xRadius: 2, yRadius: 2).fill()

        // Week bar (if shown)
        if let weekPct = weekPercentage {
            currentY -= (spacing + barHeight)
            let weekBgRect = NSRect(x: 0, y: currentY, width: barWidth, height: barHeight)
            backgroundColor.setFill()
            NSBezierPath(roundedRect: weekBgRect, xRadius: 2, yRadius: 2).fill()

            let weekFillWidth = barWidth * CGFloat(weekPct / 100.0)
            let weekFillRect = NSRect(x: 0, y: currentY, width: weekFillWidth, height: barHeight)
            weekColor.setFill()
            NSBezierPath(roundedRect: weekFillRect, xRadius: 2, yRadius: 2).fill()
        }

        // Profile label (if shown)
        if let name = profileName {
            let label = String(name.prefix(3))
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: foregroundColor.withAlphaComponent(0.85)
            ]
            let labelString = label as NSString
            let labelSize = labelString.size(withAttributes: labelAttributes)
            let labelX = (totalWidth - labelSize.width) / 2
            labelString.draw(at: NSPoint(x: labelX, y: 0), withAttributes: labelAttributes)
        }

        return image
    }

    // MARK: - Compact Dot Style

    /// Creates a minimal dot indicator for multi-profile mode
    func createCompactDot(
        percentage: Double,
        status: UsageStatus,
        profileInitial: String?,
        monochromeMode: Bool,
        isDarkMode: Bool,
        useSystemColor: Bool = false
    ) -> NSImage {
        let dotSize: CGFloat = 10
        let labelHeight: CGFloat = profileInitial != nil ? 10 : 0
        let spacing: CGFloat = profileInitial != nil ? 1 : 0

        let totalHeight = dotSize + spacing + labelHeight
        let totalWidth = max(dotSize, 16)

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))

        image.lockFocus()
        defer { image.unlockFocus() }

        // Use isDarkMode to determine correct foreground color for menu bar
        let foregroundColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let dotColor: NSColor = iconColor(for: status, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)

        // Draw dot
        let dotRect = NSRect(
            x: (totalWidth - dotSize) / 2,
            y: totalHeight - dotSize,
            width: dotSize,
            height: dotSize
        )
        dotColor.setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        // Profile initial (if shown)
        if let initial = profileInitial {
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: foregroundColor.withAlphaComponent(0.85)
            ]
            let labelString = initial.uppercased() as NSString
            let labelSize = labelString.size(withAttributes: labelAttributes)
            let labelX = (totalWidth - labelSize.width) / 2
            labelString.draw(at: NSPoint(x: labelX, y: 0), withAttributes: labelAttributes)
        }

        return image
    }

    // MARK: - Default App Logo

    /// Creates a default app logo icon for the menu bar when no credentials are configured
    func createDefaultAppLogo(isDarkMode: Bool) -> NSImage {
        // Try to load the app logo from assets
        if let logo = NSImage(named: "HeaderLogo") {
            // Create a copy to avoid modifying the original
            let resizedLogo = NSImage(size: NSSize(width: 20, height: 20))
            resizedLogo.lockFocus()
            defer { resizedLogo.unlockFocus() }

            // Draw the logo centered
            logo.draw(in: NSRect(x: 0, y: 0, width: 20, height: 20),
                     from: NSRect.zero,
                     operation: .sourceOver,
                     fraction: 1.0)

            return resizedLogo
        }

        // Fallback: Create a simple circle icon if logo not found
        let size: CGFloat = 20
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()
        defer { image.unlockFocus() }

        // Use isDarkMode to determine correct foreground color for menu bar
        let color: NSColor = menuBarForegroundColor(isDarkMode: isDarkMode)

        // Draw a simple circle
        let circlePath = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: size - 4, height: size - 4))
        color.withAlphaComponent(0.7).setStroke()
        circlePath.lineWidth = 2.0
        circlePath.stroke()

        // Draw a small dot in the center
        let dotPath = NSBezierPath(ovalIn: NSRect(x: size/2 - 2, y: size/2 - 2, width: 4, height: 4))
        color.setFill()
        dotPath.fill()

        return image
    }
}
