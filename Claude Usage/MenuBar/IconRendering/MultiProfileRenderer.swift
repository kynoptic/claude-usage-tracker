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
        let center = NSPoint(x: size / 2, y: size / 2)
        let foreground = menuBarForegroundColor(isDarkMode: isDarkMode)
        let sessionColor = iconColor(for: sessionStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let weekColor = iconColor(for: weekStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let bgColor = foreground.withAlphaComponent(0.15)

        let outerRadius: CGFloat = (size - 4) / 2
        let innerRadius: CGFloat = outerRadius - 4.5

        return makeImage(width: size, height: size) { _ in
            // Outer ring (Session)
            drawRingBackground(center: center, radius: outerRadius, strokeWidth: 3.0, color: bgColor)
            drawProgressRing(center: center, radius: outerRadius, percentage: sessionPercentage, strokeWidth: 3.0, color: sessionColor)

            // Inner ring (Week)
            drawRingBackground(center: center, radius: innerRadius, strokeWidth: 2.0, color: bgColor)
            drawProgressRing(center: center, radius: innerRadius, percentage: weekPercentage, strokeWidth: 2.0, color: weekColor)

            // Profile initial in center
            let initial = String(profileInitial.prefix(1)).uppercased()
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: foreground
            ]
            let labelSize = textSize(initial, attributes: labelAttrs)
            drawText(initial, at: NSPoint(
                x: center.x - labelSize.width / 2,
                y: center.y - labelSize.height / 2
            ), attributes: labelAttrs)
        }
    }

    // MARK: - Concentric Icon with Label

    /// Creates a concentric icon with profile label below for multi-profile mode
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

        let foreground = menuBarForegroundColor(isDarkMode: isDarkMode)
        let sessionColor = iconColor(for: sessionStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let weekColor = iconColor(for: weekStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let bgColor = foreground.withAlphaComponent(0.15)

        let circleCenter = NSPoint(x: totalWidth / 2, y: totalHeight - circleSize / 2)
        let outerRadius: CGFloat = (circleSize - 4) / 2
        let innerRadius: CGFloat = outerRadius - 3.5

        return makeImage(width: totalWidth, height: totalHeight) { _ in
            // Outer ring (Session)
            drawRingBackground(center: circleCenter, radius: outerRadius, strokeWidth: 2.5, color: bgColor)
            drawProgressRing(center: circleCenter, radius: outerRadius, percentage: sessionPercentage, strokeWidth: 2.5, color: sessionColor)

            // Inner ring (Week)
            drawRingBackground(center: circleCenter, radius: innerRadius, strokeWidth: 1.5, color: bgColor)
            drawProgressRing(center: circleCenter, radius: innerRadius, percentage: weekPercentage, strokeWidth: 1.5, color: weekColor)

            // Profile label below the circle
            let label = String(profileName.prefix(3))
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .medium),
                .foregroundColor: foreground.withAlphaComponent(0.85)
            ]
            drawCenteredText(label, in: totalWidth, y: 0, attributes: labelAttrs)
        }
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

        let foreground = menuBarForegroundColor(isDarkMode: isDarkMode)
        let sessionColor = iconColor(for: sessionStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let weekColor = iconColor(for: weekStatus, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)
        let bgColor = foreground.withAlphaComponent(0.2)

        return makeImage(width: barWidth, height: totalHeight) { _ in
            var currentY = totalHeight

            // Session bar (top)
            currentY -= barHeight
            drawBarBackground(rect: NSRect(x: 0, y: currentY, width: barWidth, height: barHeight), cornerRadius: 2, color: bgColor)
            let sessionFillW = barWidth * CGFloat(sessionPercentage / 100.0)
            drawBarFill(
                rect: NSRect(x: 0, y: currentY, width: sessionFillW, height: barHeight),
                cornerRadius: 2, color: sessionColor
            )

            // Week bar (if shown)
            if let weekPct = weekPercentage {
                currentY -= (spacing + barHeight)
                drawBarBackground(
                    rect: NSRect(x: 0, y: currentY, width: barWidth, height: barHeight),
                    cornerRadius: 2, color: bgColor
                )
                let weekFillW = barWidth * CGFloat(weekPct / 100.0)
                drawBarFill(
                    rect: NSRect(x: 0, y: currentY, width: weekFillW, height: barHeight),
                    cornerRadius: 2, color: weekColor
                )
            }

            // Profile label (if shown)
            if let name = profileName {
                let label = String(name.prefix(3))
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 8, weight: .medium),
                    .foregroundColor: foreground.withAlphaComponent(0.85)
                ]
                drawCenteredText(label, in: barWidth, y: 0, attributes: labelAttrs)
            }
        }
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
        let totalWidth: CGFloat = max(dotSize, 16)

        let foreground = menuBarForegroundColor(isDarkMode: isDarkMode)
        let dotColor = iconColor(for: status, monochromeMode: monochromeMode, useSystemColor: useSystemColor, isDarkMode: isDarkMode)

        return makeImage(width: totalWidth, height: totalHeight) { _ in
            // Draw dot
            drawDot(
                center: NSPoint(x: totalWidth / 2, y: totalHeight - dotSize / 2),
                diameter: dotSize,
                color: dotColor
            )

            // Profile initial (if shown)
            if let initial = profileInitial {
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                    .foregroundColor: foreground.withAlphaComponent(0.85)
                ]
                drawCenteredText(initial.uppercased(), in: totalWidth, y: 0, attributes: labelAttrs)
            }
        }
    }

    // MARK: - Default App Logo

    /// Creates a default app logo icon for the menu bar when no credentials are configured
    func createDefaultAppLogo(isDarkMode: Bool) -> NSImage {
        // Try to load the app logo from assets
        if let logo = NSImage(named: "HeaderLogo") {
            return makeImage(width: 20, height: 20) { rect in
                logo.draw(in: rect, from: NSRect.zero, operation: .sourceOver, fraction: 1.0)
            }
        }

        // Fallback: simple circle icon if logo not found
        let size: CGFloat = 20
        let color = menuBarForegroundColor(isDarkMode: isDarkMode)

        return makeImage(width: size, height: size) { _ in
            let center = NSPoint(x: size / 2, y: size / 2)
            drawCircleOutline(center: center, diameter: size - 4, color: color.withAlphaComponent(0.7), lineWidth: 2.0)
            drawDot(center: center, diameter: 4, color: color)
        }
    }
}
