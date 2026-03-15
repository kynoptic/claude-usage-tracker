//
//  SingleMetricRenderer.swift
//  Claude Usage
//
//  Renders individual metric icons (battery, progressBar, percentageOnly, icon, compact, API text).
//

import Cocoa

/// Handles rendering of single-metric icon styles for the menu bar
struct SingleMetricRenderer {

    // MARK: - Metric Data

    struct MetricData {
        let percentage: Double
        let displayText: String
        let status: UsageStatus
        let sessionResetTime: Date?  // Only populated for session metric
    }

    // MARK: - Metric Data Extraction

    func getMetricData(
        metricType: MenuBarMetricType,
        config: MetricIconConfig,
        usage: ClaudeUsage,
        apiUsage: APIUsage?,
        showRemaining: Bool
    ) -> MetricData {
        switch metricType {
        case .session:
            let usedPercentage = usage.sessionPercentage
            let displayPercentage = UsageStatusCalculator.getDisplayPercentage(
                usedPercentage: usedPercentage,
                showRemaining: showRemaining
            )
            let sessionElapsed = UsageStatusCalculator.elapsedFraction(
                resetTime: usage.sessionResetTime,
                duration: Constants.sessionWindow,
                showRemaining: false
            )
            let status = UsageStatusCalculator.calculateStatus(
                usedPercentage: usedPercentage,
                showRemaining: showRemaining,
                elapsedFraction: sessionElapsed,
                showGrey: DataStore.shared.loadShowGreyZone(),
                greyThreshold: DataStore.shared.loadGreyThreshold()
            )

            return MetricData(
                percentage: displayPercentage,
                displayText: "\(Int(displayPercentage))%",
                status: status,
                sessionResetTime: usage.sessionResetTime
            )

        case .week:
            let usedPercentage = usage.weeklyPercentage
            let displayPercentage = UsageStatusCalculator.getDisplayPercentage(
                usedPercentage: usedPercentage,
                showRemaining: showRemaining
            )
            let weekElapsed = UsageStatusCalculator.elapsedFraction(
                resetTime: usage.weeklyResetTime,
                duration: Constants.weeklyWindow,
                showRemaining: false
            )
            let status = UsageStatusCalculator.calculateStatus(
                usedPercentage: usedPercentage,
                showRemaining: showRemaining,
                elapsedFraction: weekElapsed,
                showGrey: DataStore.shared.loadShowGreyZone(),
                greyThreshold: DataStore.shared.loadGreyThreshold()
            )

            let displayText: String
            if config.weekDisplayMode == .percentage {
                displayText = "\(Int(displayPercentage))%"
            } else {
                // Token display mode - smart formatting
                displayText = formatTokenCount(usage.weeklyTokensUsed, usage.weeklyLimit)
            }

            return MetricData(
                percentage: displayPercentage,
                displayText: displayText,
                status: status,
                sessionResetTime: nil
            )

        case .api:
            guard let apiUsage = apiUsage else {
                return MetricData(
                    percentage: showRemaining ? 100 : 0,  // 100% remaining or 0% used when no data
                    displayText: "N/A",
                    status: UsageStatus(zone: .green, actionText: ""),
                    sessionResetTime: nil
                )
            }

            let usedPercentage = apiUsage.usagePercentage
            let displayPercentage = UsageStatusCalculator.getDisplayPercentage(
                usedPercentage: usedPercentage,
                showRemaining: showRemaining
            )
            let status = UsageStatusCalculator.calculateStatus(
                usedPercentage: usedPercentage,
                showRemaining: showRemaining,
                elapsedFraction: nil
            )

            let displayText: String
            switch config.apiDisplayMode {
            case .remaining:
                displayText = apiUsage.formattedRemaining
            case .used:
                displayText = apiUsage.formattedUsed
            case .both:
                displayText = "\(apiUsage.formattedUsed)/\(apiUsage.formattedTotal)"
            }

            return MetricData(
                percentage: displayPercentage,
                displayText: displayText,
                status: status,
                sessionResetTime: nil
            )
        }
    }

    // MARK: - Icon Style Renderers

    func createBatteryStyle(
        metricType: MenuBarMetricType,
        metricData: MetricData,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool,
        showNextSessionTime: Bool,
        usage: ClaudeUsage,
        timeMarkerFraction: CGFloat? = nil
    ) -> NSImage {
        let percentage = CGFloat(metricData.percentage) / 100.0

        // Battery style: NO prefix before the bar, label goes below
        let batteryWidth: CGFloat = 42  // Match original exactly
        let totalWidth = batteryWidth
        let totalHeight: CGFloat = 28  // Taller to fit bar on top, text below
        let barHeight: CGFloat = 10  // Match original

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))

        image.lockFocus()
        defer { image.unlockFocus() }

        // Use isDarkMode to determine correct foreground color for menu bar
        let foregroundColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let outlineColor: NSColor = foregroundColor
        let textColor: NSColor = foregroundColor
        let fillColor: NSColor = monochromeMode ? foregroundColor : UsageStatusCalculator.color(for: metricData.status)

        let xOffset: CGFloat = 0

        // Battery bar at TOP (like original)
        let barY = totalHeight - barHeight - 4
        let barWidth = batteryWidth - 2
        let padding: CGFloat = 2.0

        // Outer container
        let containerPath = NSBezierPath(
            roundedRect: NSRect(x: xOffset + 1, y: barY, width: barWidth, height: barHeight),
            xRadius: 2.5,
            yRadius: 2.5
        )
        outlineColor.withAlphaComponent(0.5).setStroke()
        containerPath.lineWidth = 1.2
        containerPath.stroke()

        // Fill level
        let fillWidth = (barWidth - padding * 2) * percentage
        if fillWidth > 1 {
            let fillPath = NSBezierPath(
                roundedRect: NSRect(
                    x: xOffset + 1 + padding,
                    y: barY + padding,
                    width: fillWidth,
                    height: barHeight - padding * 2
                ),
                xRadius: 1.5,
                yRadius: 1.5
            )
            fillColor.setFill()
            fillPath.fill()
        }

        // Time-elapsed tick mark on the battery bar
        if let fraction = timeMarkerFraction {
            // +1 accounts for the battery container's 1pt left border offset
            let tickX = round(xOffset + 1 + padding + (barWidth - padding * 2) * fraction)
            let tickPath = NSBezierPath()
            tickPath.move(to: NSPoint(x: tickX, y: barY))
            tickPath.line(to: NSPoint(x: tickX, y: barY + barHeight))
            drawTimeMarkerTick(tickPath)
        }

        // Label BELOW the battery (replaces percentage text)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.85)
        ]

        // Show metric label if enabled, otherwise show percentage
        let text: NSString
        if showNextSessionTime && metricType == .session, let resetTime = metricData.sessionResetTime {
            if showIconName {
                // Show "S (→2H)" when labels enabled
                text = "S (\(resetTime.timeRemainingHoursString()))" as NSString
            } else {
                // Show just "→2H" when labels disabled
                text = resetTime.timeRemainingHoursString() as NSString
            }
        } else if showIconName {
            // Show full word: "Session" or "Week"
            text = (metricType == .session ? "Session" : "Week") as NSString
        } else {
            // No label mode - show percentage instead
            text = "\(Int(metricData.percentage))%" as NSString
        }

        let textSize = text.size(withAttributes: textAttributes)
        let textX = xOffset + (batteryWidth - textSize.width) / 2
        let textY: CGFloat = 2
        text.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttributes)

        return image
    }

    func createProgressBarStyle(
        metricType: MenuBarMetricType,
        metricData: MetricData,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool,
        showNextSessionTime: Bool,
        usage: ClaudeUsage,
        timeMarkerFraction: CGFloat? = nil
    ) -> NSImage {
        // For progress bar: show "S" or "W" before the bar (not full prefix)
        let labelWidth: CGFloat = showIconName ? 10 : 0
        let barWidth: CGFloat = 40
        let spacing: CGFloat = showIconName ? 2 : 0
        let totalWidth = labelWidth + spacing + barWidth + 2
        let height: CGFloat = 18

        let image = NSImage(size: NSSize(width: totalWidth, height: height))

        image.lockFocus()
        defer { image.unlockFocus() }

        // Use isDarkMode to determine correct foreground color for menu bar
        let foregroundColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let textColor: NSColor = foregroundColor
        let fillColor: NSColor = monochromeMode ? foregroundColor : UsageStatusCalculator.color(for: metricData.status)
        let backgroundColor: NSColor = foregroundColor.withAlphaComponent(0.2)

        var xOffset: CGFloat = 1

        // Draw label before bar (just "S" or "W")
        if showIconName {
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: textColor.withAlphaComponent(0.9)
            ]
            let label = (metricType == .session ? "S" : "W") as NSString
            let labelSize = label.size(withAttributes: labelAttributes)
            label.draw(
                at: NSPoint(x: xOffset, y: (height - labelSize.height) / 2),
                withAttributes: labelAttributes
            )
            xOffset += labelWidth + spacing
        }

        // Progress bar
        let barHeight: CGFloat = 9  // Slightly taller
        let barY = (height - barHeight) / 2

        // Background
        let bgPath = NSBezierPath(
            roundedRect: NSRect(x: xOffset, y: barY, width: barWidth, height: barHeight),
            xRadius: 4,
            yRadius: 4
        )
        backgroundColor.setFill()
        bgPath.fill()

        // Fill
        let fillWidth = barWidth * CGFloat(metricData.percentage / 100.0)
        if fillWidth > 1 {
            let fillPath = NSBezierPath(
                roundedRect: NSRect(x: xOffset, y: barY, width: fillWidth, height: barHeight),
                xRadius: 4,
                yRadius: 4
            )
            fillColor.setFill()
            fillPath.fill()

            // Time-elapsed tick mark on the progress bar
            if let fraction = timeMarkerFraction {
                let tickX = round(xOffset + barWidth * fraction)
                let tickPath = NSBezierPath()
                tickPath.move(to: NSPoint(x: tickX, y: barY))
                tickPath.line(to: NSPoint(x: tickX, y: barY + barHeight))
                drawTimeMarkerTick(tickPath)
            }

            // Draw session reset time inside the fill area if enabled and this is a session metric
            if showNextSessionTime && metricType == .session, let resetTime = metricData.sessionResetTime {
                let timeString = resetTime.timeRemainingHoursString() as NSString
                let timeFont = NSFont.systemFont(ofSize: 5.5, weight: .medium)
                let timeAttributes: [NSAttributedString.Key: Any] = [
                    .font: timeFont,
                    .foregroundColor: NSColor.white
                ]

                let timeSize = timeString.size(withAttributes: timeAttributes)
                // Only draw if there's enough space in the fill area
                if fillWidth > timeSize.width + 2 {
                    // Right-align the text in the fill area
                    let timeX = xOffset + fillWidth - timeSize.width - 4
                    let timeY = barY + (barHeight - timeSize.height) / 2
                    timeString.draw(at: NSPoint(x: timeX, y: timeY), withAttributes: timeAttributes)
                }
            }
        }

        return image
    }

    func createPercentageOnlyStyle(
        metricType: MenuBarMetricType,
        metricData: MetricData,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool
    ) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)  // Larger font

        // Use isDarkMode to determine correct foreground color for menu bar
        let foregroundColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let fillColor: NSColor = monochromeMode ? foregroundColor : UsageStatusCalculator.color(for: metricData.status)

        var fullText = ""

        if showIconName {
            fullText = "\(metricType.prefixText) \(metricData.displayText)"
        } else {
            fullText = metricData.displayText
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fillColor
        ]

        let textSize = fullText.size(withAttributes: attributes)
        let image = NSImage(size: NSSize(width: textSize.width + 2, height: 18))

        image.lockFocus()
        defer { image.unlockFocus() }

        let textY = (18 - textSize.height) / 2
        fullText.draw(at: NSPoint(x: 2, y: textY), withAttributes: attributes)

        return image
    }

    func createIconWithBarStyle(
        metricType: MenuBarMetricType,
        metricData: MetricData,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool,
        timeMarkerFraction: CGFloat? = nil
    ) -> NSImage {
        // For circle: make it bigger to fit S/W in center
        let circleSize: CGFloat = showIconName ? 22 : 18  // Bigger when showing label
        let size: CGFloat = showIconName ? 22 : 18
        let totalWidth = circleSize + 1

        let image = NSImage(size: NSSize(width: totalWidth, height: size))

        image.lockFocus()
        defer { image.unlockFocus() }

        // Use isDarkMode to determine correct foreground color for menu bar
        let foregroundColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let textColor: NSColor = foregroundColor
        let fillColor: NSColor = monochromeMode ? foregroundColor : UsageStatusCalculator.color(for: metricData.status)

        let xOffset: CGFloat = 1

        // Progress arc
        let percentage = metricData.percentage / 100.0
        let centerX = xOffset + circleSize / 2
        let center = NSPoint(x: centerX, y: size / 2)
        let radius = (circleSize - 4.0) / 2
        let startAngle: CGFloat = 90
        let endAngle = startAngle - (360 * CGFloat(percentage))

        // Background ring
        let bgArcPath = NSBezierPath()
        bgArcPath.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 0,
            endAngle: 360,
            clockwise: false
        )
        textColor.withAlphaComponent(0.15).setStroke()
        bgArcPath.lineWidth = 3.0
        bgArcPath.lineCapStyle = .round
        bgArcPath.stroke()

        // Progress ring
        if percentage > 0 {
            let arcPath = NSBezierPath()
            arcPath.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )
            fillColor.setStroke()
            arcPath.lineWidth = 3.0
            arcPath.lineCapStyle = .round
            arcPath.stroke()
        }

        // Time-elapsed tick mark on the ring (clockwise from 12 o'clock)
        if let fraction = timeMarkerFraction {
            let tickAngle = (90 - 360 * fraction) * .pi / 180
            let innerR = radius - 2.0
            let outerR = radius + 2.0
            let tickPath = NSBezierPath()
            tickPath.move(to: NSPoint(
                x: center.x + innerR * cos(tickAngle),
                y: center.y + innerR * sin(tickAngle)
            ))
            tickPath.line(to: NSPoint(
                x: center.x + outerR * cos(tickAngle),
                y: center.y + outerR * sin(tickAngle)
            ))
            drawTimeMarkerTick(tickPath)
        }

        // Draw S/W in the CENTER of the circle
        if showIconName {
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: textColor
            ]
            let label = (metricType == .session ? "S" : "W") as NSString
            let labelSize = label.size(withAttributes: labelAttributes)
            let labelX = center.x - labelSize.width / 2
            let labelY = center.y - labelSize.height / 2
            label.draw(at: NSPoint(x: labelX, y: labelY), withAttributes: labelAttributes)
        }

        return image
    }

    func createCompactStyle(
        metricType: MenuBarMetricType,
        metricData: MetricData,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool
    ) -> NSImage {
        let prefixWidth: CGFloat = showIconName ? 16 : 0
        let dotSize: CGFloat = 8
        let spacing: CGFloat = showIconName ? 1 : 0
        let totalWidth = prefixWidth + spacing + dotSize + 1
        let height: CGFloat = 18

        let image = NSImage(size: NSSize(width: totalWidth, height: height))

        image.lockFocus()
        defer { image.unlockFocus() }

        // Use isDarkMode to determine correct foreground color for menu bar
        let foregroundColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let textColor: NSColor = foregroundColor
        let fillColor: NSColor = monochromeMode ? foregroundColor : UsageStatusCalculator.color(for: metricData.status)

        var xOffset: CGFloat = 1

        // Draw prefix if enabled
        if showIconName {
            let prefixAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: textColor.withAlphaComponent(0.85)
            ]
            let prefixText = metricType.prefixText as NSString
            let prefixSize = prefixText.size(withAttributes: prefixAttributes)
            prefixText.draw(
                at: NSPoint(x: xOffset, y: (height - prefixSize.height) / 2),
                withAttributes: prefixAttributes
            )
            xOffset += prefixWidth + spacing
        }

        // Draw dot
        let dotY = (height - dotSize) / 2
        let dotRect = NSRect(x: xOffset, y: dotY, width: dotSize, height: dotSize)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        fillColor.setFill()
        dotPath.fill()

        return image
    }

    // MARK: - API Text Style (Always Text-Based)

    func createAPITextStyle(
        metricData: MetricData,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool
    ) -> NSImage {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)

        // Use isDarkMode to determine correct foreground color for menu bar
        let textColor: NSColor = menuBarForegroundColor(isDarkMode: isDarkMode)

        var fullText = ""

        if showIconName {
            fullText = "API: \(metricData.displayText)"
        } else {
            fullText = metricData.displayText
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor
        ]

        let textSize = fullText.size(withAttributes: attributes)
        let image = NSImage(size: NSSize(width: textSize.width + 4, height: 18))

        image.lockFocus()
        defer { image.unlockFocus() }

        let textY = (18 - textSize.height) / 2
        fullText.draw(at: NSPoint(x: 2, y: textY), withAttributes: attributes)

        return image
    }
}
