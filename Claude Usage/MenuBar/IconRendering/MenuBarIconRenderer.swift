//
//  MenuBarIconRenderer.swift
//  Claude Usage
//
//  Public facade for menu bar icon rendering. Routes calls to focused renderers.
//
//  Created by Claude Code on 2025-12-27.
//

import Cocoa

/// Handles rendering of individual metric icons for the menu bar
final class MenuBarIconRenderer {

    // MARK: - Properties

    private let singleMetric = SingleMetricRenderer()
    private let multiProfile = MultiProfileRenderer()
    private let metricExtractor = MetricDataExtractor()

    // MARK: - Public Methods

    /// Creates an image for a specific metric
    func createImage(
        for metricType: MenuBarMetricType,
        config: MetricIconConfig,
        globalConfig: MenuBarIconConfiguration,
        usage: ClaudeUsage,
        apiUsage: APIUsage?,
        isDarkMode: Bool,
        monochromeMode: Bool,
        showIconName: Bool,
        showNextSessionTime: Bool
    ) -> NSImage {
        // Get the metric value and percentage
        let metricData = metricExtractor.extract(
            metricType: metricType,
            config: config,
            usage: usage,
            apiUsage: apiUsage,
            showRemaining: globalConfig.showRemainingPercentage
        )

        // API is ALWAYS text-based (no icon styles)
        if metricType == .api {
            return singleMetric.createAPITextStyle(
                metricData: metricData,
                isDarkMode: isDarkMode,
                monochromeMode: monochromeMode,
                showIconName: showIconName
            )
        }

        // Calculate time marker fraction for session/week metrics
        let timeMarkerFraction: CGFloat? = globalConfig.showTimeMarker
            ? calculateTimeMarkerFraction(
                metricType: metricType,
                usage: usage,
                showRemaining: globalConfig.showRemainingPercentage
            )
            : nil

        // Render based on icon style for Session and Week
        switch config.iconStyle {
        case .battery:
            return singleMetric.createBatteryStyle(
                metricType: metricType,
                metricData: metricData,
                isDarkMode: isDarkMode,
                monochromeMode: monochromeMode,
                showIconName: showIconName,
                showNextSessionTime: showNextSessionTime,
                usage: usage,
                timeMarkerFraction: timeMarkerFraction
            )
        case .progressBar:
            return singleMetric.createProgressBarStyle(
                metricType: metricType,
                metricData: metricData,
                isDarkMode: isDarkMode,
                monochromeMode: monochromeMode,
                showIconName: showIconName,
                showNextSessionTime: showNextSessionTime,
                usage: usage,
                timeMarkerFraction: timeMarkerFraction
            )
        case .percentageOnly:
            return singleMetric.createPercentageOnlyStyle(
                metricType: metricType,
                metricData: metricData,
                isDarkMode: isDarkMode,
                monochromeMode: monochromeMode,
                showIconName: showIconName
            )
        case .icon:
            return singleMetric.createIconWithBarStyle(
                metricType: metricType,
                metricData: metricData,
                isDarkMode: isDarkMode,
                monochromeMode: monochromeMode,
                showIconName: showIconName,
                timeMarkerFraction: timeMarkerFraction
            )
        case .compact:
            return singleMetric.createCompactStyle(
                metricType: metricType,
                metricData: metricData,
                isDarkMode: isDarkMode,
                monochromeMode: monochromeMode,
                showIconName: showIconName
            )
        }
    }

    // MARK: - Multi-Profile Methods

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
        multiProfile.createConcentricIcon(
            sessionPercentage: sessionPercentage,
            weekPercentage: weekPercentage,
            sessionStatus: sessionStatus,
            weekStatus: weekStatus,
            profileInitial: profileInitial,
            monochromeMode: monochromeMode,
            isDarkMode: isDarkMode,
            useSystemColor: useSystemColor
        )
    }

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
        multiProfile.createConcentricIconWithLabel(
            sessionPercentage: sessionPercentage,
            weekPercentage: weekPercentage,
            sessionStatus: sessionStatus,
            weekStatus: weekStatus,
            profileName: profileName,
            monochromeMode: monochromeMode,
            isDarkMode: isDarkMode,
            useSystemColor: useSystemColor
        )
    }

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
        multiProfile.createMultiProfileProgressBar(
            sessionPercentage: sessionPercentage,
            weekPercentage: weekPercentage,
            sessionStatus: sessionStatus,
            weekStatus: weekStatus,
            profileName: profileName,
            monochromeMode: monochromeMode,
            isDarkMode: isDarkMode,
            useSystemColor: useSystemColor
        )
    }

    /// Creates a minimal dot indicator for multi-profile mode
    func createCompactDot(
        percentage: Double,
        status: UsageStatus,
        profileInitial: String?,
        monochromeMode: Bool,
        isDarkMode: Bool,
        useSystemColor: Bool = false
    ) -> NSImage {
        multiProfile.createCompactDot(
            percentage: percentage,
            status: status,
            profileInitial: profileInitial,
            monochromeMode: monochromeMode,
            isDarkMode: isDarkMode,
            useSystemColor: useSystemColor
        )
    }

    /// Creates a default app logo icon for the menu bar when no credentials are configured
    func createDefaultAppLogo(isDarkMode: Bool) -> NSImage {
        multiProfile.createDefaultAppLogo(isDarkMode: isDarkMode)
    }
}
