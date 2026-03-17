//
//  MetricDataExtractor.swift
//  Claude Usage
//
//  Extracts and transforms metric values from usage data for icon rendering.
//

import Foundation

// MARK: - Metric Data

/// Snapshot of a single metric's display values, consumed by icon renderers.
struct MetricData {
    let percentage: Double
    let displayText: String
    let status: UsageStatus
    let sessionResetTime: Date?  // Only populated for session metric
}

// MARK: - Metric Data Extraction

/// Transforms raw usage data into renderer-ready `MetricData`.
struct MetricDataExtractor {

    // MARK: - Public Methods

    func extract(
        metricType: MenuBarMetricType,
        config: MetricIconConfig,
        usage: ClaudeUsage,
        apiUsage: APIUsage?,
        showRemaining: Bool
    ) -> MetricData {
        switch metricType {
        case .session:
            return sessionMetricData(usage: usage, showRemaining: showRemaining)
        case .week:
            return weekMetricData(usage: usage, config: config, showRemaining: showRemaining)
        case .api:
            return apiMetricData(apiUsage: apiUsage, config: config, showRemaining: showRemaining)
        }
    }

    // MARK: - Private Methods

    private func sessionMetricData(usage: ClaudeUsage, showRemaining: Bool) -> MetricData {
        let usedPercentage = usage.sessionPercentage
        let displayPercentage = UsageStatusCalculator.getDisplayPercentage(
            usedPercentage: usedPercentage, showRemaining: showRemaining
        )
        let sessionElapsed = UsageStatusCalculator.elapsedFraction(
            resetTime: usage.sessionResetTime, duration: Constants.sessionWindow, showRemaining: false
        )
        let status = UsageStatusCalculator.calculateStatus(
            usedPercentage: usedPercentage, showRemaining: showRemaining,
            elapsedFraction: sessionElapsed,
            showGrey: AppearanceStore.shared.loadShowGreyZone(),
            greyThreshold: AppearanceStore.shared.loadGreyThreshold()
        )
        return MetricData(
            percentage: displayPercentage,
            displayText: "\(Int(displayPercentage))%",
            status: status,
            sessionResetTime: usage.sessionResetTime
        )
    }

    private func weekMetricData(usage: ClaudeUsage, config: MetricIconConfig, showRemaining: Bool) -> MetricData {
        let usedPercentage = usage.weeklyPercentage
        let displayPercentage = UsageStatusCalculator.getDisplayPercentage(
            usedPercentage: usedPercentage, showRemaining: showRemaining
        )
        let weekElapsed = UsageStatusCalculator.elapsedFraction(
            resetTime: usage.weeklyResetTime, duration: Constants.weeklyWindow, showRemaining: false
        )
        let status = UsageStatusCalculator.calculateStatus(
            usedPercentage: usedPercentage, showRemaining: showRemaining,
            elapsedFraction: weekElapsed,
            showGrey: AppearanceStore.shared.loadShowGreyZone(),
            greyThreshold: AppearanceStore.shared.loadGreyThreshold()
        )
        let displayText = config.weekDisplayMode == .percentage
            ? "\(Int(displayPercentage))%"
            : formatTokenCount(usage.weeklyTokensUsed, usage.weeklyLimit)
        return MetricData(
            percentage: displayPercentage, displayText: displayText,
            status: status, sessionResetTime: nil
        )
    }

    private func apiMetricData(apiUsage: APIUsage?, config: MetricIconConfig, showRemaining: Bool) -> MetricData {
        guard let apiUsage = apiUsage else {
            return MetricData(
                percentage: showRemaining ? 100 : 0,
                displayText: "N/A",
                status: UsageStatus(zone: .green, actionText: ""),
                sessionResetTime: nil
            )
        }
        let usedPercentage = apiUsage.usagePercentage
        let displayPercentage = UsageStatusCalculator.getDisplayPercentage(
            usedPercentage: usedPercentage, showRemaining: showRemaining
        )
        let status = UsageStatusCalculator.calculateStatus(
            usedPercentage: usedPercentage, showRemaining: showRemaining, elapsedFraction: nil
        )
        let displayText: String
        switch config.apiDisplayMode {
        case .remaining: displayText = apiUsage.formattedRemaining
        case .used:      displayText = apiUsage.formattedUsed
        case .both:      displayText = "\(apiUsage.formattedUsed)/\(apiUsage.formattedTotal)"
        }
        return MetricData(
            percentage: displayPercentage, displayText: displayText,
            status: status, sessionResetTime: nil
        )
    }
}
