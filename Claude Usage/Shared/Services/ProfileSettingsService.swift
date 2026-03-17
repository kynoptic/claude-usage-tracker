//
//  ProfileSettingsService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-03-16.
//

import Foundation

/// Manages per-profile settings mutations: icon config, refresh interval,
/// notification settings, and organization IDs.
///
/// Extracted from `ProfileManager` to reduce god-object complexity.
/// Mutates profile state through `ProfileManager.shared.updateProfile(_:mutate:)`.
@MainActor
final class ProfileSettingsService {
    static let shared = ProfileSettingsService()

    private init() {}

    // MARK: - Public Methods

    /// Updates icon configuration for a profile.
    func updateIconConfig(_ config: MenuBarIconConfiguration, for profileId: UUID) {
        ProfileManager.shared.updateProfile(profileId) { $0.iconConfig = config }
    }

    /// Updates refresh interval for a profile.
    func updateRefreshInterval(_ interval: TimeInterval, for profileId: UUID) {
        ProfileManager.shared.updateProfile(profileId) { $0.refreshInterval = interval }
    }

    /// Updates auto-start session setting for a profile.
    func updateAutoStartSessionEnabled(_ enabled: Bool, for profileId: UUID) {
        ProfileManager.shared.updateProfile(profileId) { $0.autoStartSessionEnabled = enabled }
    }

    /// Updates check overage limit setting for a profile.
    func updateCheckOverageLimitEnabled(_ enabled: Bool, for profileId: UUID) {
        ProfileManager.shared.updateProfile(profileId) { $0.checkOverageLimitEnabled = enabled }
    }

    /// Updates notification settings for a profile.
    func updateNotificationSettings(_ settings: NotificationSettings, for profileId: UUID) {
        ProfileManager.shared.updateProfile(profileId) { $0.notificationSettings = settings }
    }

    /// Updates organization ID for a profile.
    func updateOrganizationId(_ orgId: String?, for profileId: UUID) {
        ProfileManager.shared.updateProfile(profileId) { $0.organizationId = orgId }
    }

    /// Updates API organization ID for a profile.
    func updateAPIOrganizationId(_ orgId: String?, for profileId: UUID) {
        ProfileManager.shared.updateProfile(profileId) { $0.apiOrganizationId = orgId }
    }
}
