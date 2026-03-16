//
//  Profile.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-07.
//

import Foundation

/// Represents a complete isolated profile with all credentials and settings
struct Profile: Codable, Identifiable, Equatable {
    // MARK: - Identity
    let id: UUID
    var name: String

    // MARK: - Credentials (stored directly in profile)
    var claudeSessionKey: String?
    var organizationId: String?
    var apiSessionKey: String?
    var apiOrganizationId: String?
    var cliCredentialsJSON: String?

    // MARK: - CLI Account Sync Metadata
    var hasCliAccount: Bool
    var cliAccountSyncedAt: Date?

    /// Cached result of CLI OAuth credential validation.
    /// Updated when credentials are synced, loaded, or removed — never during SwiftUI body evaluation.
    var hasValidOAuthCredentials: Bool

    // MARK: - Usage Data (Per-Profile)
    var claudeUsage: ClaudeUsage?
    var apiUsage: APIUsage?

    // MARK: - Appearance Settings (Per-Profile)
    var iconConfig: MenuBarIconConfiguration

    // MARK: - Behavior Settings (Per-Profile)
    var refreshInterval: TimeInterval
    var autoStartSessionEnabled: Bool
    var checkOverageLimitEnabled: Bool

    // MARK: - Notification Settings (Per-Profile)
    var notificationSettings: NotificationSettings

    // MARK: - Display Configuration
    var isSelectedForDisplay: Bool  // For multi-profile menu bar mode

    // MARK: - Metadata
    var createdAt: Date
    var lastUsedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        claudeSessionKey: String? = nil,
        organizationId: String? = nil,
        apiSessionKey: String? = nil,
        apiOrganizationId: String? = nil,
        cliCredentialsJSON: String? = nil,
        hasCliAccount: Bool = false,
        cliAccountSyncedAt: Date? = nil,
        hasValidOAuthCredentials: Bool = false,
        claudeUsage: ClaudeUsage? = nil,
        apiUsage: APIUsage? = nil,
        iconConfig: MenuBarIconConfiguration = .default,
        refreshInterval: TimeInterval = 30.0,
        autoStartSessionEnabled: Bool = false,
        checkOverageLimitEnabled: Bool = true,
        notificationSettings: NotificationSettings = NotificationSettings(),
        isSelectedForDisplay: Bool = true,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.claudeSessionKey = claudeSessionKey
        self.organizationId = organizationId
        self.apiSessionKey = apiSessionKey
        self.apiOrganizationId = apiOrganizationId
        self.cliCredentialsJSON = cliCredentialsJSON
        self.hasCliAccount = hasCliAccount
        self.cliAccountSyncedAt = cliAccountSyncedAt
        self.hasValidOAuthCredentials = hasValidOAuthCredentials
        self.claudeUsage = claudeUsage
        self.apiUsage = apiUsage
        self.iconConfig = iconConfig
        self.refreshInterval = refreshInterval
        self.autoStartSessionEnabled = autoStartSessionEnabled
        self.checkOverageLimitEnabled = checkOverageLimitEnabled
        self.notificationSettings = notificationSettings
        self.isSelectedForDisplay = isSelectedForDisplay
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, name
        case claudeSessionKey, organizationId, apiSessionKey, apiOrganizationId, cliCredentialsJSON
        case hasCliAccount, cliAccountSyncedAt, hasValidOAuthCredentials
        case claudeUsage, apiUsage
        case iconConfig, refreshInterval, autoStartSessionEnabled, checkOverageLimitEnabled
        case notificationSettings, isSelectedForDisplay
        case createdAt, lastUsedAt
    }

    /// Decodes all fields including legacy credential fields for backward compatibility.
    /// Older versions stored credentials in UserDefaults; the decoder still reads them
    /// so that KeychainPerProfileMigrationService can migrate them on launch.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        claudeSessionKey = try container.decodeIfPresent(String.self, forKey: .claudeSessionKey)
        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)
        apiSessionKey = try container.decodeIfPresent(String.self, forKey: .apiSessionKey)
        apiOrganizationId = try container.decodeIfPresent(String.self, forKey: .apiOrganizationId)
        cliCredentialsJSON = try container.decodeIfPresent(String.self, forKey: .cliCredentialsJSON)
        hasCliAccount = try container.decodeIfPresent(Bool.self, forKey: .hasCliAccount) ?? false
        cliAccountSyncedAt = try container.decodeIfPresent(Date.self, forKey: .cliAccountSyncedAt)
        hasValidOAuthCredentials = try container.decodeIfPresent(Bool.self, forKey: .hasValidOAuthCredentials) ?? false
        claudeUsage = try container.decodeIfPresent(ClaudeUsage.self, forKey: .claudeUsage)
        apiUsage = try container.decodeIfPresent(APIUsage.self, forKey: .apiUsage)
        iconConfig = try container.decodeIfPresent(MenuBarIconConfiguration.self, forKey: .iconConfig) ?? .default
        refreshInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .refreshInterval) ?? 30.0
        autoStartSessionEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoStartSessionEnabled) ?? false
        checkOverageLimitEnabled = try container.decodeIfPresent(Bool.self, forKey: .checkOverageLimitEnabled) ?? true
        notificationSettings = try container.decodeIfPresent(NotificationSettings.self, forKey: .notificationSettings) ?? NotificationSettings()
        isSelectedForDisplay = try container.decodeIfPresent(Bool.self, forKey: .isSelectedForDisplay) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt) ?? Date()
    }

    /// Encodes only non-credential fields. Credential fields (claudeSessionKey,
    /// organizationId, apiSessionKey, apiOrganizationId, cliCredentialsJSON) are
    /// stored in the macOS Keychain per ADR-008 and must never be serialized to
    /// UserDefaults or any other unprotected storage.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        // Credential fields intentionally excluded — stored in Keychain (ADR-008)
        try container.encode(hasCliAccount, forKey: .hasCliAccount)
        try container.encodeIfPresent(cliAccountSyncedAt, forKey: .cliAccountSyncedAt)
        try container.encode(hasValidOAuthCredentials, forKey: .hasValidOAuthCredentials)
        try container.encodeIfPresent(claudeUsage, forKey: .claudeUsage)
        try container.encodeIfPresent(apiUsage, forKey: .apiUsage)
        try container.encode(iconConfig, forKey: .iconConfig)
        try container.encode(refreshInterval, forKey: .refreshInterval)
        try container.encode(autoStartSessionEnabled, forKey: .autoStartSessionEnabled)
        try container.encode(checkOverageLimitEnabled, forKey: .checkOverageLimitEnabled)
        try container.encode(notificationSettings, forKey: .notificationSettings)
        try container.encode(isSelectedForDisplay, forKey: .isSelectedForDisplay)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUsedAt, forKey: .lastUsedAt)
    }

    // MARK: - Computed Properties
    var hasClaudeAI: Bool {
        claudeSessionKey != nil && organizationId != nil
    }

    var hasAPIConsole: Bool {
        apiSessionKey != nil && apiOrganizationId != nil
    }

    /// True if profile has credentials that can fetch usage data (Claude.ai, CLI OAuth, or API Console)
    var hasUsageCredentials: Bool {
        hasClaudeAI || hasAPIConsole || hasValidOAuthCredentials
    }

    // MARK: - OAuth Validation Helpers

    /// Pure validation: checks whether a CLI credentials JSON string contains a valid, non-expired OAuth token.
    /// Safe to call from any context — no subprocess, no I/O.
    static func isValidOAuthJSON(_ jsonData: String) -> Bool {
        guard let data = jsonData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let _ = oauth["accessToken"] as? String else {
            return false
        }
        // Check expiry if present
        if let expiresAt = oauth["expiresAt"] as? TimeInterval {
            let epoch = expiresAt > 1e12 ? expiresAt / 1000.0 : expiresAt
            let expiryDate = Date(timeIntervalSince1970: epoch)
            return Date() < expiryDate
        }
        // No expiry info = assume valid
        return true
    }

    var hasAnyCredentials: Bool {
        hasClaudeAI || hasAPIConsole || cliCredentialsJSON != nil
    }
}

// MARK: - ProfileCredentials (for compatibility)
/// Simple struct for passing credentials around
struct ProfileCredentials {
    var claudeSessionKey: String?
    var organizationId: String?
    var apiSessionKey: String?
    var apiOrganizationId: String?
    var cliCredentialsJSON: String?

    var hasClaudeAI: Bool {
        claudeSessionKey != nil && organizationId != nil
    }

    var hasAPIConsole: Bool {
        apiSessionKey != nil && apiOrganizationId != nil
    }

    var hasCLI: Bool {
        cliCredentialsJSON != nil
    }
}
