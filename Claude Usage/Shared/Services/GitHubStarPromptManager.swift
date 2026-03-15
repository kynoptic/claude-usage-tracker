import Foundation

/// Manages business logic for the GitHub star prompt feature.
/// Determines whether the prompt should be shown based on timing rules and user preferences.
@MainActor
final class GitHubStarPromptManager {
    static let shared = GitHubStarPromptManager(storage: DataStore.shared)

    private let storage: StorageProvider

    init(storage: StorageProvider) {
        self.storage = storage
    }

    /// Determines whether the GitHub star prompt should be shown.
    /// Returns true when all conditions are met:
    /// - User hasn't opted out with "Don't ask again"
    /// - User hasn't already starred the repo
    /// - Either: 1+ days since first launch (never shown before), OR 10+ days since last shown
    func shouldShowGitHubStarPrompt() -> Bool {
        // Don't show if user said "don't ask again"
        if storage.loadNeverShowGitHubPrompt() {
            return false
        }

        // Don't show if user already starred
        if storage.loadHasStarredGitHub() {
            return false
        }

        let now = Date()

        // Check if we have a first launch date
        guard let firstLaunch = storage.loadFirstLaunchDate() else {
            // If no first launch date, save it now and don't show prompt yet
            storage.saveFirstLaunchDate(now)
            return false
        }

        // Check if it's been at least 1 day since first launch
        let timeSinceFirstLaunch = now.timeIntervalSince(firstLaunch)
        if timeSinceFirstLaunch < Constants.GitHubPromptTiming.initialDelay {
            return false
        }

        // Check if we've ever shown the prompt before
        guard let lastPrompt = storage.loadLastGitHubStarPromptDate() else {
            // Never shown before, and it's been 1+ days since first launch
            return true
        }

        // Has been shown before - check if enough time has passed for a reminder
        let timeSinceLastPrompt = now.timeIntervalSince(lastPrompt)
        return timeSinceLastPrompt >= Constants.GitHubPromptTiming.reminderInterval
    }
}
