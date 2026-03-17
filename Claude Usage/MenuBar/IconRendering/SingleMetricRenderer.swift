//
//  SingleMetricRenderer.swift
//  Claude Usage
//
//  Renders individual metric icons (battery, progressBar, percentageOnly, icon, compact, API text).
//

import Cocoa

/// Handles rendering of single-metric icon styles for the menu bar
struct SingleMetricRenderer {

    // MARK: - Properties

    /// Shared appearance values derived once per render call.
    private struct RenderColors {
        let foreground: NSColor
        let fill: NSColor
        let text: NSColor

        init(isDarkMode: Bool, monochromeMode: Bool, status: UsageStatus) {
            let fg = menuBarForegroundColor(isDarkMode: isDarkMode)
            self.foreground = fg
            self.text = fg
            self.fill = monochromeMode ? fg : UsageStatusCalculator.color(for: status)
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
        let batteryWidth: CGFloat = 42
        let totalHeight: CGFloat = 28
        let barHeight: CGFloat = 10
        let padding: CGFloat = 2.0
        let barWidth = batteryWidth - 2
        let barY = totalHeight - barHeight - 4
        let percentage = CGFloat(metricData.percentage) / 100.0
        let colors = RenderColors(isDarkMode: isDarkMode, monochromeMode: monochromeMode, status: metricData.status)

        return makeImage(width: batteryWidth, height: totalHeight) { _ in
            drawBarOutline(
                rect: NSRect(x: 1, y: barY, width: barWidth, height: barHeight),
                cornerRadius: 2.5,
                color: colors.foreground.withAlphaComponent(0.5)
            )

            let fillWidth = (barWidth - padding * 2) * percentage
            drawBarFill(
                rect: NSRect(x: 1 + padding, y: barY + padding, width: fillWidth, height: barHeight - padding * 2),
                cornerRadius: 1.5,
                color: colors.fill
            )

            if let fraction = timeMarkerFraction {
                let tickX = round(1 + padding + (barWidth - padding * 2) * fraction)
                let tickPath = NSBezierPath()
                tickPath.move(to: NSPoint(x: tickX, y: barY))
                tickPath.line(to: NSPoint(x: tickX, y: barY + barHeight))
                drawTimeMarkerTick(tickPath)
            }

            let labelText = self.batteryLabelText(
                metricType: metricType, metricData: metricData,
                showIconName: showIconName, showNextSessionTime: showNextSessionTime
            )
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                .foregroundColor: colors.text.withAlphaComponent(0.85)
            ]
            drawCenteredText(labelText, in: batteryWidth, y: 2, attributes: attrs)
        }
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
        let labelWidth: CGFloat = showIconName ? 10 : 0
        let barWidth: CGFloat = 40
        let spacing: CGFloat = showIconName ? 2 : 0
        let totalWidth = labelWidth + spacing + barWidth + 2
        let height: CGFloat = 18
        let barHeight: CGFloat = 9
        let barY = (height - barHeight) / 2
        let colors = RenderColors(isDarkMode: isDarkMode, monochromeMode: monochromeMode, status: metricData.status)

        return makeImage(width: totalWidth, height: height) { _ in
            var xOffset: CGFloat = 1

            if showIconName {
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                    .foregroundColor: colors.text.withAlphaComponent(0.9)
                ]
                let label = metricType == .session ? "S" : "W"
                let labelSize = textSize(label, attributes: labelAttrs)
                drawText(label, at: NSPoint(x: xOffset, y: (height - labelSize.height) / 2), attributes: labelAttrs)
                xOffset += labelWidth + spacing
            }

            drawBarBackground(
                rect: NSRect(x: xOffset, y: barY, width: barWidth, height: barHeight),
                cornerRadius: 4, color: colors.foreground.withAlphaComponent(0.2)
            )

            let fillWidth = barWidth * CGFloat(metricData.percentage / 100.0)
            drawBarFill(
                rect: NSRect(x: xOffset, y: barY, width: fillWidth, height: barHeight),
                cornerRadius: 4, color: colors.fill
            )

            guard fillWidth > 1 else { return }

            if let fraction = timeMarkerFraction {
                let tickX = round(xOffset + barWidth * fraction)
                let tickPath = NSBezierPath()
                tickPath.move(to: NSPoint(x: tickX, y: barY))
                tickPath.line(to: NSPoint(x: tickX, y: barY + barHeight))
                drawTimeMarkerTick(tickPath)
            }

            if showNextSessionTime && metricType == .session, let resetTime = metricData.sessionResetTime {
                let timeStr = resetTime.timeRemainingHoursString()
                let timeAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 5.5, weight: .medium),
                    .foregroundColor: NSColor.white
                ]
                let tSize = textSize(timeStr, attributes: timeAttrs)
                if fillWidth > tSize.width + 2 {
                    let timeX = xOffset + fillWidth - tSize.width - 4
                    let timeY = barY + (barHeight - tSize.height) / 2
                    drawText(timeStr, at: NSPoint(x: timeX, y: timeY), attributes: timeAttrs)
                }
            }
        }
    }

    func createPercentageOnlyStyle(
        metricType: MenuBarMetricType,
        metricData: MetricData,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool
    ) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        let colors = RenderColors(isDarkMode: isDarkMode, monochromeMode: monochromeMode, status: metricData.status)
        let fullText = showIconName ? "\(metricType.prefixText) \(metricData.displayText)" : metricData.displayText
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: colors.fill]
        let size = textSize(fullText, attributes: attrs)

        return makeImage(width: size.width + 2, height: 18) { _ in
            let textY = (18 - size.height) / 2
            drawText(fullText, at: NSPoint(x: 2, y: textY), attributes: attrs)
        }
    }

    func createIconWithBarStyle(
        metricType: MenuBarMetricType,
        metricData: MetricData,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool,
        timeMarkerFraction: CGFloat? = nil
    ) -> NSImage {
        let circleSize: CGFloat = showIconName ? 22 : 18
        let totalWidth = circleSize + 1
        let colors = RenderColors(isDarkMode: isDarkMode, monochromeMode: monochromeMode, status: metricData.status)
        let centerX: CGFloat = 1 + circleSize / 2
        let center = NSPoint(x: centerX, y: circleSize / 2)
        let radius = (circleSize - 4.0) / 2

        return makeImage(width: totalWidth, height: circleSize) { _ in
            drawRingBackground(center: center, radius: radius, strokeWidth: 3.0, color: colors.text.withAlphaComponent(0.15))
            drawProgressRing(center: center, radius: radius, percentage: metricData.percentage, strokeWidth: 3.0, color: colors.fill)

            if let fraction = timeMarkerFraction {
                let tickAngle = (90 - 360 * fraction) * .pi / 180
                let innerR = radius - 2.0
                let outerR = radius + 2.0
                let tickPath = NSBezierPath()
                tickPath.move(to: NSPoint(x: center.x + innerR * cos(tickAngle), y: center.y + innerR * sin(tickAngle)))
                tickPath.line(to: NSPoint(x: center.x + outerR * cos(tickAngle), y: center.y + outerR * sin(tickAngle)))
                drawTimeMarkerTick(tickPath)
            }

            if showIconName {
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                    .foregroundColor: colors.text
                ]
                let label = metricType == .session ? "S" : "W"
                let lSize = textSize(label, attributes: labelAttrs)
                drawText(label, at: NSPoint(x: center.x - lSize.width / 2, y: center.y - lSize.height / 2), attributes: labelAttrs)
            }
        }
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
        let colors = RenderColors(isDarkMode: isDarkMode, monochromeMode: monochromeMode, status: metricData.status)

        return makeImage(width: totalWidth, height: height) { _ in
            var xOffset: CGFloat = 1

            if showIconName {
                let prefixAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9, weight: .medium),
                    .foregroundColor: colors.text.withAlphaComponent(0.85)
                ]
                let prefixStr = metricType.prefixText
                let pSize = textSize(prefixStr, attributes: prefixAttrs)
                drawText(prefixStr, at: NSPoint(x: xOffset, y: (height - pSize.height) / 2), attributes: prefixAttrs)
                xOffset += prefixWidth + spacing
            }

            drawDot(center: NSPoint(x: xOffset + dotSize / 2, y: height / 2), diameter: dotSize, color: colors.fill)
        }
    }

    // MARK: - API Text Style (Always Text-Based)

    func createAPITextStyle(
        metricData: MetricData,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool
    ) -> NSImage {
        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let textColor = menuBarForegroundColor(isDarkMode: isDarkMode)
        let fullText = showIconName ? "API: \(metricData.displayText)" : metricData.displayText
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: textColor]
        let size = textSize(fullText, attributes: attrs)

        return makeImage(width: size.width + 4, height: 18) { _ in
            let textY = (18 - size.height) / 2
            drawText(fullText, at: NSPoint(x: 2, y: textY), attributes: attrs)
        }
    }

    // MARK: - Private Methods

    private func batteryLabelText(
        metricType: MenuBarMetricType, metricData: MetricData,
        showIconName: Bool, showNextSessionTime: Bool
    ) -> String {
        if showNextSessionTime && metricType == .session, let resetTime = metricData.sessionResetTime {
            return showIconName
                ? "S (\(resetTime.timeRemainingHoursString()))"
                : resetTime.timeRemainingHoursString()
        } else if showIconName {
            return metricType == .session ? "Session" : "Week"
        } else {
            return "\(Int(metricData.percentage))%"
        }
    }
}
