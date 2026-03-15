//
//  LoggingService.swift
//  Claude Usage
//
//  Created by Claude Code on 2025-12-20.
//

import Foundation
import os.log

/// Centralized logging service using os.log
/// Provides consistent logging across the application
@MainActor
final class LoggingService {
    nonisolated static let shared = LoggingService()

    // Category-specific loggers
    nonisolated private let apiLogger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.claudeusage", category: "API")
    nonisolated private let storageLogger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.claudeusage", category: "Storage")
    nonisolated private let notificationLogger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.claudeusage", category: "Notifications")
    nonisolated private let uiLogger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.claudeusage", category: "UI")
    nonisolated private let generalLogger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.claudeusage", category: "General")

    nonisolated private init() {}

    // MARK: - API Logging

    nonisolated func logAPIRequest(_ endpoint: String) {
        os_log("📤 API Request: %{private}@", log: apiLogger, type: .info, endpoint)
    }

    nonisolated func logAPIResponse(_ endpoint: String, statusCode: Int) {
        os_log("📥 API Response: %{private}@ [%d]", log: apiLogger, type: .info, endpoint, statusCode)
    }

    nonisolated func logAPIError(_ endpoint: String, error: Error) {
        os_log("❌ API Error: %{private}@ - %{public}@", log: apiLogger, type: .error, endpoint, error.localizedDescription)
    }

    // MARK: - Storage Logging

    nonisolated func logStorageSave(_ key: String) {
        os_log("💾 Storage Save: %{public}@", log: storageLogger, type: .debug, key)
    }

    nonisolated func logStorageLoad(_ key: String, success: Bool) {
        if success {
            os_log("📂 Storage Load: %{public}@ ✓", log: storageLogger, type: .debug, key)
        } else {
            os_log("📂 Storage Load: %{public}@ ✗ (not found)", log: storageLogger, type: .debug, key)
        }
    }

    nonisolated func logStorageError(_ operation: String, error: Error) {
        os_log("❌ Storage Error [%{public}@]: %{public}@", log: storageLogger, type: .error, operation, error.localizedDescription)
    }

    // MARK: - Notification Logging

    nonisolated func logNotificationSent(_ type: String) {
        os_log("🔔 Notification Sent: %{public}@", log: notificationLogger, type: .info, type)
    }

    nonisolated func logNotificationError(_ error: Error) {
        os_log("❌ Notification Error: %{public}@", log: notificationLogger, type: .error, error.localizedDescription)
    }

    nonisolated func logNotificationPermission(_ granted: Bool) {
        os_log("🔐 Notification Permission: %{public}@", log: notificationLogger, type: .info, granted ? "Granted" : "Denied")
    }

    // MARK: - UI Logging

    nonisolated func logUIEvent(_ event: String) {
        os_log("🖱️ UI Event: %{public}@", log: uiLogger, type: .debug, event)
    }

    nonisolated func logWindowEvent(_ event: String) {
        os_log("🪟 Window Event: %{public}@", log: uiLogger, type: .debug, event)
    }

    // MARK: - General Logging

    nonisolated func log(_ message: String, type: OSLogType = .default) {
        os_log("%{public}@", log: generalLogger, type: type, message)
    }

    nonisolated func logError(_ message: String, error: Error? = nil) {
        if let error = error {
            os_log("❌ %{public}@: %{public}@", log: generalLogger, type: .error, message, error.localizedDescription)
        } else {
            os_log("❌ %{public}@", log: generalLogger, type: .error, message)
        }
    }

    nonisolated func logWarning(_ message: String) {
        os_log("⚠️ %{public}@", log: generalLogger, type: .default, message)
    }

    nonisolated func logInfo(_ message: String) {
        os_log("ℹ️ %{public}@", log: generalLogger, type: .info, message)
    }

    nonisolated func logDebug(_ message: String) {
        os_log("🐛 %{public}@", log: generalLogger, type: .debug, message)
    }
}
