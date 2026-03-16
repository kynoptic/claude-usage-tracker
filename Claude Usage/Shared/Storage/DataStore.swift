import Foundation

/// Manages shared data storage using standard UserDefaults (app container)
@MainActor
final class DataStore: StorageProvider {
    static let shared = DataStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        // Use standard UserDefaults (app container)
        self.defaults = UserDefaults.standard
        LoggingService.shared.log("DataStore: Using standard app container storage")
    }

    // MARK: - Usage Data

    /// Saves usage data to shared storage
    func saveUsage(_ usage: ClaudeUsage) {
        do {
            let data = try encoder.encode(usage)
            defaults.set(data, forKey: Constants.UserDefaultsKeys.claudeUsageData)
            // Note: synchronize() is deprecated and unnecessary - UserDefaults auto-syncs
            LoggingService.shared.logStorageSave("claudeUsageData")
        } catch {
            LoggingService.shared.logStorageError("saveUsage", error: error)
        }
    }

    /// Loads usage data from shared storage
    func loadUsage() -> ClaudeUsage? {
        guard let data = defaults.data(forKey: Constants.UserDefaultsKeys.claudeUsageData) else {
            LoggingService.shared.logStorageLoad("claudeUsageData", success: false)
            return nil
        }

        do {
            let usage = try decoder.decode(ClaudeUsage.self, from: data)
            LoggingService.shared.logStorageLoad("claudeUsageData", success: true)
            return usage
        } catch {
            LoggingService.shared.logStorageError("loadUsage", error: error)
            return nil
        }
    }

    // MARK: - User Preferences

    /// Saves notification preferences
    func saveNotificationsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Constants.UserDefaultsKeys.notificationsEnabled)
    }

    /// Loads notification preferences
    func loadNotificationsEnabled() -> Bool {
        return defaults.bool(forKey: Constants.UserDefaultsKeys.notificationsEnabled)
    }

    /// Saves refresh interval
    func saveRefreshInterval(_ interval: TimeInterval) {
        defaults.set(interval, forKey: Constants.UserDefaultsKeys.refreshInterval)
    }

    /// Loads refresh interval
    func loadRefreshInterval() -> TimeInterval {
        let interval = defaults.double(forKey: Constants.UserDefaultsKeys.refreshInterval)
        return interval > 0 ? interval : Constants.RefreshIntervals.menuBar
    }

    /// Saves auto-start session preference
    func saveAutoStartSessionEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Constants.UserDefaultsKeys.autoStartSessionEnabled)
    }

    /// Loads auto-start session preference
    func loadAutoStartSessionEnabled() -> Bool {
        return defaults.bool(forKey: Constants.UserDefaultsKeys.autoStartSessionEnabled)
    }

    /// Saves check overage limit preference
    func saveCheckOverageLimitEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Constants.UserDefaultsKeys.checkOverageLimitEnabled)
    }

    /// Loads check overage limit preference (defaults to true)
    func loadCheckOverageLimitEnabled() -> Bool {
        // If key doesn't exist, register default as true
        if defaults.object(forKey: Constants.UserDefaultsKeys.checkOverageLimitEnabled) == nil {
            return true
        }
        return defaults.bool(forKey: Constants.UserDefaultsKeys.checkOverageLimitEnabled)
    }

    // MARK: - Organization Settings

    /// Saves selected organization ID for personal usage tracking
    func saveOrganizationId(_ organizationId: String) {
        defaults.set(organizationId, forKey: Constants.UserDefaultsKeys.selectedOrganizationId)
        LoggingService.shared.logStorageSave("selectedOrganizationId")
    }

    /// Loads selected organization ID (returns nil if not set)
    func loadOrganizationId() -> String? {
        let orgId = defaults.string(forKey: Constants.UserDefaultsKeys.selectedOrganizationId)
        LoggingService.shared.logStorageLoad("selectedOrganizationId", success: orgId != nil)
        return orgId
    }

    /// Clears stored organization ID (call when session key changes)
    func clearOrganizationId() {
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.selectedOrganizationId)
        LoggingService.shared.logInfo("Cleared stored organization ID")
    }

    // MARK: - Debug Settings

    /// Saves debug API logging preference
    func saveDebugAPILoggingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Constants.UserDefaultsKeys.debugAPILoggingEnabled)
    }

    /// Loads debug API logging preference (defaults to false)
    func loadDebugAPILoggingEnabled() -> Bool {
        return defaults.bool(forKey: Constants.UserDefaultsKeys.debugAPILoggingEnabled)
    }

    // MARK: - Language & Localization

    /// Saves the selected language code
    func saveLanguageCode(_ code: String) {
        defaults.set(code, forKey: Constants.UserDefaultsKeys.selectedLanguageCode)
    }

    /// Loads the selected language code
    func loadLanguageCode() -> String? {
        return defaults.string(forKey: Constants.UserDefaultsKeys.selectedLanguageCode)
    }

    // MARK: - API Usage Tracking

    /// Saves API usage data to shared storage
    func saveAPIUsage(_ usage: APIUsage) {
        do {
            let data = try encoder.encode(usage)
            defaults.set(data, forKey: Constants.UserDefaultsKeys.apiUsageData)
        } catch {
            LoggingService.shared.logStorageError("saveAPIUsage", error: error)
        }
    }

    /// Loads API usage data from shared storage
    func loadAPIUsage() -> APIUsage? {
        guard let data = defaults.data(forKey: Constants.UserDefaultsKeys.apiUsageData) else {
            return nil
        }

        do {
            return try decoder.decode(APIUsage.self, from: data)
        } catch {
            LoggingService.shared.logStorageError("loadAPIUsage", error: error)
            return nil
        }
    }

    /// Saves API tracking enabled preference
    func saveAPITrackingEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Constants.UserDefaultsKeys.apiTrackingEnabled)
    }

    /// Loads API tracking enabled preference
    func loadAPITrackingEnabled() -> Bool {
        return defaults.bool(forKey: Constants.UserDefaultsKeys.apiTrackingEnabled)
    }

    /// Saves API session key to Keychain
    func saveAPISessionKey(_ key: String) {
        do {
            try KeychainService.shared.save(key, for: .apiSessionKey)

            // Migration: Remove from UserDefaults if it exists there
            if defaults.string(forKey: Constants.UserDefaultsKeys.apiSessionKey) != nil {
                defaults.removeObject(forKey: Constants.UserDefaultsKeys.apiSessionKey)
                LoggingService.shared.log("Migrated API session key from UserDefaults to Keychain")
            }
        } catch {
            LoggingService.shared.logStorageError("saveAPISessionKey", error: error)
        }
    }

    /// Loads API session key from Keychain (with fallback to UserDefaults for migration)
    func loadAPISessionKey() -> String? {
        do {
            // Try to load from Keychain first
            if let key = try KeychainService.shared.load(for: .apiSessionKey) {
                return key
            }

            // Migration: Check UserDefaults for existing key
            if let legacyKey = defaults.string(forKey: Constants.UserDefaultsKeys.apiSessionKey) {
                LoggingService.shared.log("Found API session key in UserDefaults, migrating to Keychain")
                // Migrate to Keychain
                try KeychainService.shared.save(legacyKey, for: .apiSessionKey)
                // Remove from UserDefaults
                defaults.removeObject(forKey: Constants.UserDefaultsKeys.apiSessionKey)
                return legacyKey
            }

            return nil
        } catch {
            LoggingService.shared.logStorageError("loadAPISessionKey", error: error)
            // Fallback to UserDefaults on error
            return defaults.string(forKey: Constants.UserDefaultsKeys.apiSessionKey)
        }
    }

    /// Saves selected API organization ID
    func saveAPIOrganizationId(_ orgId: String) {
        defaults.set(orgId, forKey: Constants.UserDefaultsKeys.apiOrganizationId)
    }

    /// Loads selected API organization ID
    func loadAPIOrganizationId() -> String? {
        return defaults.string(forKey: Constants.UserDefaultsKeys.apiOrganizationId)
    }

}
