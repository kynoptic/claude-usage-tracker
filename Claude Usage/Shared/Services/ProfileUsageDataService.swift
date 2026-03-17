//
//  ProfileUsageDataService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-03-16.
//

import Foundation

/// Manages usage data persistence for profiles: save and load Claude and API usage.
///
/// Extracted from `ProfileManager` to reduce god-object complexity.
/// Mutates profile state through `ProfileManager.shared.updateProfile(_:mutate:)`.
@MainActor
final class ProfileUsageDataService {
    static let shared = ProfileUsageDataService()

    private init() {}

    // MARK: - Claude Usage

    /// Saves Claude usage data for a specific profile.
    func saveClaudeUsage(_ usage: ClaudeUsage, for profileId: UUID) {
        let manager = ProfileManager.shared
        guard manager.profiles.contains(where: { $0.id == profileId }) else {
            LoggingService.shared.logError("saveClaudeUsage: Profile not found with ID: \(profileId)")
            return
        }
        manager.updateProfile(profileId) { $0.claudeUsage = usage }
        LoggingService.shared.log("Saved Claude usage for profile: \(profileId.uuidString)")
    }

    /// Loads Claude usage data for a specific profile.
    func loadClaudeUsage(for profileId: UUID) -> ClaudeUsage? {
        ProfileManager.shared.profiles.first(where: { $0.id == profileId })?.claudeUsage
    }

    // MARK: - API Usage

    /// Saves API usage data for a specific profile.
    func saveAPIUsage(_ usage: APIUsage, for profileId: UUID) {
        let manager = ProfileManager.shared
        guard manager.profiles.contains(where: { $0.id == profileId }) else {
            LoggingService.shared.logError("saveAPIUsage: Profile not found with ID: \(profileId)")
            return
        }
        manager.updateProfile(profileId) { $0.apiUsage = usage }
        LoggingService.shared.log("Saved API usage for profile: \(profileId.uuidString)")
    }

    /// Loads API usage data for a specific profile.
    func loadAPIUsage(for profileId: UUID) -> APIUsage? {
        ProfileManager.shared.profiles.first(where: { $0.id == profileId })?.apiUsage
    }
}
