import SwiftUI

// MARK: - Smart Usage Dashboard
struct SmartUsageDashboard: View {
    let usage: ClaudeUsage
    let apiUsage: APIUsage?
    var sessionContext: PacingContext = .none
    var isStale: Bool = false
    var lastSuccessfulFetch: Date?
    var lastRefreshError: AppError?
    var nextRetryDate: Date?
    @ObservedObject var profileManager = ProfileManager.shared
    @ObservedObject var viewModel: SmartUsageDashboardViewModel

    // Get the display mode from active profile's icon config
    private var showRemainingPercentage: Bool {
        profileManager.activeProfile?.iconConfig.showRemainingPercentage ?? false
    }

    private var showTimeMarker: Bool {
        profileManager.activeProfile?.iconConfig.showTimeMarker ?? true
    }

    var body: some View {
        VStack(spacing: 16) {
            // Staleness / error indicator
            if let error = lastRefreshError, isStale {
                if error.code == .apiRateLimited, let retryDate = nextRetryDate {
                    // Live countdown banner for rate limiting
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.orange)

                            Text(SmartUsageDashboardViewModel.countdownText(until: retryDate, now: context.date))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.orange)

                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                } else {
                    // Static error banner for auth/credential/other errors
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.orange)

                        Text(SmartUsageDashboardViewModel.errorBannerText(for: lastRefreshError) ?? "Refresh failed")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            } else if isStale {
                // Stale data, no error (aged past threshold)
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)

                        Text(SmartUsageDashboardViewModel.stalenessLabel(lastSuccessfulFetch: lastSuccessfulFetch, at: context.date))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            }

            // Primary Usage Card
            SmartUsageCard(
                title: "menubar.session_usage".localized,
                subtitle: "menubar.5_hour_window".localized,
                usedPercentage: usage.sessionPercentage,
                showRemaining: showRemainingPercentage,
                resetTime: usage.sessionResetTime,
                isPrimary: true,
                periodDuration: Constants.sessionWindow,
                showTimeMarker: showTimeMarker,
                metric: .session,
                isStale: isStale,
                context: sessionContext,
                showGreyZone: viewModel.showGreyZone,
                greyThreshold: viewModel.greyThreshold,
                chartColorMode: viewModel.chartColorMode
            )

            // Secondary Usage Cards
            HStack(spacing: 12) {
                SmartUsageCard(
                    title: "menubar.all_models".localized,
                    subtitle: "menubar.weekly".localized,
                    usedPercentage: usage.weeklyPercentage,
                    showRemaining: showRemainingPercentage,
                    resetTime: usage.weeklyResetTime,
                    isPrimary: false,
                    periodDuration: Constants.weeklyWindow,
                    showTimeMarker: showTimeMarker,
                    metric: .weekly,
                    isStale: isStale,
                    showGreyZone: viewModel.showGreyZone,
                    greyThreshold: viewModel.greyThreshold,
                    chartColorMode: viewModel.chartColorMode
                )

                if usage.opusWeeklyTokensUsed > 0 {
                    SmartUsageCard(
                        title: "menubar.opus_usage".localized,
                        subtitle: "menubar.weekly".localized,
                        usedPercentage: usage.opusWeeklyPercentage,
                        showRemaining: showRemainingPercentage,
                        resetTime: nil,
                        isPrimary: false,
                        periodDuration: Constants.weeklyWindow,
                        showTimeMarker: showTimeMarker,
                        metric: .opus,
                        isStale: isStale,
                        showGreyZone: viewModel.showGreyZone,
                        greyThreshold: viewModel.greyThreshold,
                        chartColorMode: viewModel.chartColorMode
                    )
                }

                if usage.sonnetWeeklyTokensUsed > 0 {
                    SmartUsageCard(
                        title: "menubar.sonnet_usage".localized,
                        subtitle: "menubar.weekly".localized,
                        usedPercentage: usage.sonnetWeeklyPercentage,
                        showRemaining: showRemainingPercentage,
                        resetTime: usage.sonnetWeeklyResetTime,
                        isPrimary: false,
                        periodDuration: Constants.weeklyWindow,
                        showTimeMarker: showTimeMarker,
                        metric: .sonnet,
                        isStale: isStale,
                        showGreyZone: viewModel.showGreyZone,
                        greyThreshold: viewModel.greyThreshold,
                        chartColorMode: viewModel.chartColorMode
                    )
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            if let used = usage.costUsed, let limit = usage.costLimit, let currency = usage.costCurrency, limit > 0 {
                let usedPercentage = (used / limit) * 100.0
                SmartUsageCard(
                    title: "menubar.extra_usage".localized,
                    subtitle: String(format: "%.2f / %.2f %@", used / 100.0, limit / 100.0, currency),
                    usedPercentage: usedPercentage,
                    showRemaining: showRemainingPercentage,
                    resetTime: nil,
                    isPrimary: false,
                    periodDuration: nil,
                    isStale: isStale,
                    showGreyZone: viewModel.showGreyZone,
                    greyThreshold: viewModel.greyThreshold,
                    chartColorMode: viewModel.chartColorMode
                )
            }

            // API Usage Card (only if tracking is enabled AND profile has credentials)
            if viewModel.isAPITrackingEnabled,
               let apiUsage = apiUsage,
               let profile = profileManager.activeProfile,
               profile.hasAPIConsole {
                APIUsageCard(apiUsage: apiUsage, showRemaining: showRemainingPercentage)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Smart Usage Card
struct SmartUsageCard: View {
    let title: String
    let subtitle: String
    let usedPercentage: Double
    let showRemaining: Bool
    let resetTime: Date?
    let isPrimary: Bool
    let periodDuration: TimeInterval?
    var showTimeMarker: Bool = true
    var metric: UsageMetric? = nil
    var isStale: Bool = false
    var context: PacingContext = .none
    var showGreyZone: Bool = false
    var greyThreshold: Double = Constants.greyThresholdDefault
    var chartColorMode: ChartColorMode = .uniform

    @State private var isFlipped = false

    /// Raw elapsed fraction (0…1), never inverted. Nil when timing data is unavailable.
    /// Used for both the time marker position and pacing calculations.
    private var rawElapsedFraction: Double? {
        UsageStatusCalculator.elapsedFraction(
            resetTime: resetTime,
            duration: periodDuration ?? 0,
            showRemaining: false
        )
    }

    /// Fraction (0...1) of elapsed time within the period, adjusted for display mode.
    /// CGFloat for SwiftUI layout; showRemaining inverts the direction of the arc marker.
    private var timeMarkerFraction: CGFloat? {
        guard showTimeMarker, let f = rawElapsedFraction else { return nil }
        return CGFloat(showRemaining ? 1.0 - f : f)
    }

    /// Display percentage based on mode
    private var displayPercentage: Double {
        UsageStatusCalculator.getDisplayPercentage(
            usedPercentage: usedPercentage,
            showRemaining: showRemaining
        )
    }

    /// Pacing status for this usage card.
    private var usageStatus: UsageStatus {
        let elapsed = context.elapsedFraction ?? rawElapsedFraction
        return UsageStatusCalculator.calculateStatus(
            usedPercentage: usedPercentage,
            showRemaining: showRemaining,
            elapsedFraction: elapsed,
            showGrey: showGreyZone,
            greyThreshold: greyThreshold
        )
    }

    /// Vibrant system color for non-text elements — icon, progress bar, charts.
    private var statusColor: Color { .usageStatus(usageStatus) }

    /// Accessible color for text elements — adjusted for contrast on light backgrounds.
    private var accessibleStatusColor: Color {
        switch usageStatus.zone {
        case .grey:   return Color(nsColor: .systemGray)
        case .green:  return Color("UsageGreen")
        case .yellow: return Color("UsageYellow")
        case .orange: return Color("UsageOrange")
        case .red:    return Color(nsColor: .systemRed)
        }
    }

    private var statusIcon: String {
        switch usageStatus.zone {
        case .grey:   return "moon.zzz.fill"
        case .green:  return "checkmark.circle.fill"
        case .yellow: return "flame.fill"
        case .orange: return "exclamationmark.triangle.fill"
        case .red:    return "xmark.circle.fill"
        }
    }

    var body: some View {
        Group {
            if isFlipped {
                backContent
                    .transition(.opacity)
            } else {
                frontContent
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: isPrimary ? nil : .infinity)
        .padding(isPrimary ? 16 : 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .drawingGroup()
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.3), value: isFlipped)
        .opacity(isStale ? 0.7 : 1.0)
        .onTapGesture { if metric != nil { isFlipped.toggle() } }
        .accessibilityHint(metric != nil ? "Double tap to \(isFlipped ? "hide" : "show") usage chart" : "")
    }

    // MARK: - Front Content

    private var frontContent: some View {
        VStack(spacing: isPrimary ? 12 : 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: isPrimary ? 13 : 11, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: isPrimary ? 10 : 9, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status indicator
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.system(size: isPrimary ? 12 : 10, weight: .medium))
                        .foregroundColor(statusColor)

                    Text("\(Int(displayPercentage))%")
                        .font(.system(size: isPrimary ? 16 : 14, weight: .bold, design: .monospaced))
                        .foregroundColor(accessibleStatusColor)
                }
            }

            // Progress visualization
            VStack(spacing: 6) {
                // Animated progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [statusColor, statusColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * min(displayPercentage / 100.0, 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .animation(.easeInOut(duration: 0.8), value: displayPercentage)
                    }
                    .overlay(alignment: .leading) {
                        // Time elapsed marker
                        if let fraction = timeMarkerFraction {
                            Rectangle()
                                .fill(Color(nsColor: .labelColor))
                                .frame(width: 1.5)
                                .offset(x: round(geometry.size.width * fraction))
                        }
                    }
                }
                .frame(height: 8)

                // Reset time information
                if let reset = resetTime {
                    HStack {
                        Spacer()
                        Text("menubar.resets_time".localized(with: reset.resetTimeString()))
                            .font(.system(size: isPrimary ? 9 : 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Back Content (Burn-Up Chart)

    private var backContent: some View {
        VStack(spacing: isPrimary ? 8 : 4) {
            HStack {
                Text(title)
                    .font(.system(size: isPrimary ? 11 : 9, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: isPrimary ? 10 : 8, weight: .medium))
                    .foregroundColor(.secondary)
            }

            if let metric = metric {
                BurnUpChartView(
                    snapshots: UsageHistoryStore.shared.snapshots(for: metric),
                    isPrimary: isPrimary,
                    windowStart: chartWindowStart,
                    windowEnd: chartWindowEnd,
                    statusColor: statusColor,
                    isStale: isStale,
                    chartColorMode: chartColorMode,
                    showGreyZone: showGreyZone,
                    greyThreshold: greyThreshold
                )
            }
        }
    }

    /// Effective period duration, falling back to the metric's natural window
    private var effectiveDuration: TimeInterval {
        if let duration = periodDuration { return duration }
        switch metric {
        case .session: return Constants.sessionWindow
        case .weekly, .opus, .sonnet: return Constants.weeklyWindow
        case .none: return Constants.sessionWindow
        }
    }

    /// Start of the chart time window, computed from reset time and period duration
    private var chartWindowStart: Date {
        if let reset = resetTime {
            return reset.addingTimeInterval(-effectiveDuration)
        }
        return Date().addingTimeInterval(-effectiveDuration)
    }

    /// End of the chart time window (the reset time, or now + buffer)
    private var chartWindowEnd: Date {
        resetTime ?? Date().addingTimeInterval(60)
    }
}

// MARK: - API Usage Card
struct APIUsageCard: View {
    let apiUsage: APIUsage
    let showRemaining: Bool

    /// Display percentage based on mode
    private var displayPercentage: Double {
        UsageStatusCalculator.getDisplayPercentage(
            usedPercentage: apiUsage.usagePercentage,
            showRemaining: showRemaining
        )
    }

    /// Status for API billing (no elapsed data).
    private var usageStatus: UsageStatus {
        UsageStatusCalculator.calculateStatus(
            usedPercentage: apiUsage.usagePercentage,
            showRemaining: showRemaining,
            elapsedFraction: nil
        )
    }

    private var usageColor: Color { .usageStatus(usageStatus) }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("menubar.api_credits".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("menubar.anthropic_console".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Percentage
                Text("\(Int(displayPercentage))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(usageColor)
            }

            // Progress Bar
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))

                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(usageColor)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: displayPercentage / 100.0, y: 1.0, anchor: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 8)

            // Used / Remaining
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("menubar.used".localized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(apiUsage.formattedUsed)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("menubar.remaining".localized)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(apiUsage.formattedRemaining)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }

            // Reset Time
            if apiUsage.resetsAt > Date() {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)

                    Text("menubar.resets_time".localized(with: apiUsage.resetsAt.formatted(.relative(presentation: .named))))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(usageColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
