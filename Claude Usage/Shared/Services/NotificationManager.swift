import Foundation
import UserNotifications

/// Manages user notifications for usage threshold alerts
@MainActor
final class NotificationManager: NotificationServiceProtocol {
    static let shared = NotificationManager()

    // Track previous session percentage per profile to detect resets
    private var previousSessionPercentages: [UUID: Double] = [:]

    // Track which notifications have been sent per profile to prevent duplicates
    private var sentNotifications: [UUID: Set<String>] = [:]

    private init() {}

    /// Sends a notification when approaching usage limits (legacy, non-profile-aware)
    func sendUsageAlert(type: AlertType, percentage: Double, resetTime: Date?) {
        // Check if notifications are enabled in preferences
        guard DataStore.shared.loadNotificationsEnabled() else {
            return
        }

        let legacyId = Self.legacyProfileId
        // Create unique identifier for this notification
        let deduplicationKey = "\(type.rawValue)_\(Int(percentage))"

        // Check if we've already sent this notification
        guard !(sentNotifications[legacyId]?.contains(deduplicationKey) ?? false) else {
            return
        }

        // Mark as sent immediately
        sentNotifications[legacyId, default: []].insert(deduplicationKey)

        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.message(percentage: percentage, resetTime: resetTime)
        content.sound = .default
        content.categoryIdentifier = "USAGE_ALERT"

        let request = UNNotificationRequest(
            identifier: deduplicationKey,
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LoggingService.shared.logError("Failed to send usage alert: \(error)")
            }
        }
    }

    /// Sends a simple notification (for non-usage alerts)
    func sendSimpleAlert(type: AlertType) {
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.message(percentage: 0, resetTime: nil)
        content.sound = .default
        content.categoryIdentifier = "INFO_ALERT"

        let request = UNNotificationRequest(
            identifier: type.rawValue,
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request) { _ in
            // Notification sent
        }
    }

    /// Sends a brief success notification for user-triggered refreshes
    func sendSuccessNotification() {
        let center = UNUserNotificationCenter.current()

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Claude Usage Updated"
        content.body = "Successfully loaded usage data"
        // Silent notification (no sound)
        content.categoryIdentifier = "SUCCESS_ALERT"

        // Create a trigger to deliver immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)

        // Create the request with a unique identifier
        let identifier = "usage_refresh_success_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // Add the notification request
        center.add(request) { error in
            if let error = error {
                LoggingService.shared.logError("Failed to show success notification: \(error)")
            }
        }

        // Auto-remove after 2 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            center.removeDeliveredNotifications(withIdentifiers: [identifier])
        }
    }

    /// Checks usage and sends appropriate alerts (profile-aware)
    func checkAndNotify(usage: ClaudeUsage, profileId: UUID, profileName: String, settings: NotificationSettings) {
        // Check if notifications are enabled for this profile
        guard settings.enabled else {
            return
        }

        let sessionPercentage = usage.sessionPercentage
        let previousPercentage = previousSessionPercentages[profileId] ?? 0.0

        // Check for session reset (went from >0% to 0%)
        if previousPercentage > 0.0 && sessionPercentage == 0.0 {
            sendProfileAlert(
                profileId: profileId,
                profileName: profileName,
                type: .sessionReset,
                percentage: sessionPercentage,
                resetTime: usage.sessionResetTime
            )

            // Note: Auto-start session is handled per-profile but called from elsewhere
        }

        // Update previous percentage for this profile
        previousSessionPercentages[profileId] = sessionPercentage

        // Clear lower threshold notifications for this profile only
        clearLowerThresholdNotifications(profileId: profileId, currentPercentage: sessionPercentage)

        // 95% threshold
        if sessionPercentage >= 95 && settings.threshold95Enabled {
            sendProfileAlert(
                profileId: profileId,
                profileName: profileName,
                type: .sessionCritical,
                percentage: sessionPercentage,
                resetTime: usage.sessionResetTime
            )
        }
        // 90% threshold
        else if sessionPercentage >= 90 && settings.threshold90Enabled {
            sendProfileAlert(
                profileId: profileId,
                profileName: profileName,
                type: .sessionWarning,
                percentage: sessionPercentage,
                resetTime: usage.sessionResetTime
            )
        }
        // 75% threshold
        else if sessionPercentage >= 75 && settings.threshold75Enabled {
            sendProfileAlert(
                profileId: profileId,
                profileName: profileName,
                type: .sessionInfo,
                percentage: sessionPercentage,
                resetTime: usage.sessionResetTime
            )
        }
    }

    /// Stable UUID for the legacy single-profile fallback path
    private static let legacyProfileId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

    /// Checks usage and sends appropriate alerts (legacy, for backwards compatibility)
    func checkAndNotify(usage: ClaudeUsage) {
        // Fallback to old behavior if called without profile
        guard DataStore.shared.loadNotificationsEnabled() else {
            return
        }

        let settings = NotificationSettings(
            enabled: true,
            threshold75Enabled: true,
            threshold90Enabled: true,
            threshold95Enabled: true
        )

        checkAndNotify(usage: usage, profileId: Self.legacyProfileId, profileName: "Default", settings: settings)
    }

    /// Sends a profile-specific usage alert
    private func sendProfileAlert(profileId: UUID, profileName: String, type: AlertType, percentage: Double, resetTime: Date?) {
        // Create unique identifier for this notification type within the profile
        let deduplicationKey = "\(type.rawValue)_\(Int(percentage))"

        // Check if we've already sent this notification for this profile
        guard !(sentNotifications[profileId]?.contains(deduplicationKey) ?? false) else {
            return
        }

        // Mark as sent immediately to prevent races on @MainActor
        sentNotifications[profileId, default: []].insert(deduplicationKey)

        let content = UNMutableNotificationContent()
        content.title = "\(profileName) - \(type.title)"
        content.body = type.message(percentage: percentage, resetTime: resetTime)
        content.sound = .default
        content.categoryIdentifier = "USAGE_ALERT"

        // Include profile ID in notification center identifier for uniqueness
        let notificationIdentifier = "\(profileId.uuidString)_\(deduplicationKey)"
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LoggingService.shared.logError("Failed to send profile alert: \(error)")
            }
        }
    }

    /// Sends auto-start session notification
    func sendAutoStartNotification(profileName: String, success: Bool, error: String?) {
        let content = UNMutableNotificationContent()

        if success {
            content.title = "\(profileName) - \(AlertType.sessionAutoStarted.title)"
            content.body = AlertType.sessionAutoStarted.message(percentage: 0, resetTime: nil)
            content.sound = .default
            content.categoryIdentifier = "INFO_ALERT"
        } else {
            content.title = "\(profileName) - \(AlertType.sessionAutoStartFailed.title)"
            var message = AlertType.sessionAutoStartFailed.message(percentage: 0, resetTime: nil)
            if let error = error {
                message += " Error: \(error)"
            }
            content.body = message
            content.sound = .default
            content.categoryIdentifier = "ERROR_ALERT"
        }

        let identifier = success ? "auto_start_\(profileName)_success" : "auto_start_\(profileName)_failed_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LoggingService.shared.logError("Failed to send auto-start notification: \(error)")
            }
        }
    }

    /// Clears all pending notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// Clears sent notification tracking for lower percentages for a specific profile
    /// This allows re-notification if usage goes back up
    private func clearLowerThresholdNotifications(profileId: UUID, currentPercentage: Double) {
        guard var profileNotifications = sentNotifications[profileId] else { return }
        // Remove notifications for percentages higher than current
        // (they should re-fire if usage climbs back up)
        profileNotifications = profileNotifications.filter { identifier in
            // Extract percentage from identifier (format: "type_percentage")
            let components = identifier.components(separatedBy: "_")
            guard components.count >= 2,
                  let percentage = Double(components.last ?? "0") else {
                return true // Keep if we can't parse
            }
            return percentage <= currentPercentage
        }
        sentNotifications[profileId] = profileNotifications
    }

    // MARK: - Test Inspection

    /// Returns the last recorded session percentage for a profile (test support)
    func previousSessionPercentage(for profileId: UUID) -> Double {
        previousSessionPercentages[profileId] ?? 0.0
    }

    /// Returns whether a notification has been sent for a specific profile, type, and percentage (test support)
    func hasSentNotification(profileId: UUID, type: AlertType, percentage: Double) -> Bool {
        let key = "\(type.rawValue)_\(Int(percentage))"
        return sentNotifications[profileId]?.contains(key) ?? false
    }

    /// Resets all per-profile state (test support)
    func resetAllState() {
        previousSessionPercentages.removeAll()
        sentNotifications.removeAll()
    }
}

// MARK: - Alert Types

extension NotificationManager {
    enum AlertType: String {
        case sessionInfo = "session_info"  // 75% threshold
        case sessionWarning = "session_warning"  // 90% threshold
        case sessionCritical = "session_critical"  // 95% threshold
        case sessionReset = "session_reset"
        case sessionAutoStarted = "session_auto_started"
        case sessionAutoStartFailed = "session_auto_start_failed"
        case weeklyWarning = "weekly_warning"
        case weeklyCritical = "weekly_critical"
        case opusWarning = "opus_warning"
        case opusCritical = "opus_critical"
        case notificationsEnabled = "notifications_enabled"

        var title: String {
            switch self {
            case .sessionInfo:
                return "Usage Info"
            case .sessionWarning:
                return "notification.session_warning.title".localized
            case .sessionCritical:
                return "notification.session_critical.title".localized
            case .sessionReset:
                return "notification.session_reset.title".localized
            case .sessionAutoStarted:
                return "notification.session_auto_started.title".localized
            case .sessionAutoStartFailed:
                return "notification.session_auto_start_failed.title".localized
            case .weeklyWarning:
                return "notification.weekly_warning.title".localized
            case .weeklyCritical:
                return "notification.weekly_critical.title".localized
            case .opusWarning:
                return "notification.opus_warning.title".localized
            case .opusCritical:
                return "notification.opus_critical.title".localized
            case .notificationsEnabled:
                return "notification.enabled.title".localized
            }
        }

        func message(percentage: Double, resetTime: Date?) -> String {
            let percentStr = String(format: "%.1f%%", percentage)
            let resetStr = resetTime.map { "Resets \(FormatterHelper.timeUntilReset(from: $0))" } ?? ""

            switch self {
            case .sessionInfo:
                return "You've used \(percentStr) of your session limit. \(resetStr)"
            case .sessionWarning:
                return "notification.session_warning.message".localized(with: percentStr, resetStr)
            case .sessionCritical:
                return "notification.session_critical.message".localized(with: percentStr, resetStr)
            case .sessionReset:
                return "notification.session_reset.message".localized
            case .sessionAutoStarted:
                return "notification.session_auto_started.message".localized
            case .sessionAutoStartFailed:
                return "notification.session_auto_start_failed.message".localized
            case .weeklyWarning:
                return "notification.weekly_warning.message".localized(with: percentStr, resetStr)
            case .weeklyCritical:
                return "notification.weekly_critical.message".localized(with: percentStr, resetStr)
            case .opusWarning:
                return "notification.opus_warning.message".localized(with: percentStr, resetStr)
            case .opusCritical:
                return "notification.opus_critical.message".localized(with: percentStr, resetStr)
            case .notificationsEnabled:
                return "notification.enabled.message".localized
            }
        }
    }
}
