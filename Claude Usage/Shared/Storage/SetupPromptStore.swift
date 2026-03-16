import Combine
import Foundation

/// Manages setup wizard state and GitHub star prompt tracking.
@MainActor
final class SetupPromptStore: ObservableObject {
    static let shared = SetupPromptStore()

    private let defaults: UserDefaults

    private init() {
        self.defaults = UserDefaults.standard
    }

    // MARK: - Setup State

    func saveHasCompletedSetup(_ completed: Bool) {
        defaults.set(completed, forKey: Constants.UserDefaultsKeys.hasCompletedSetup)
    }

    func hasCompletedSetup() -> Bool {
        if defaults.bool(forKey: Constants.UserDefaultsKeys.hasCompletedSetup) {
            return true
        }
        let sessionKeyPath = Constants.ClaudePaths.homeDirectory
            .appendingPathComponent(".claude-session-key")
        if FileManager.default.fileExists(atPath: sessionKeyPath.path) {
            saveHasCompletedSetup(true)
            return true
        }
        return false
    }

    func hasShownWizardOnce() -> Bool {
        return defaults.bool(forKey: Constants.UserDefaultsKeys.hasShownWizardOnce)
    }

    func markWizardShown() {
        defaults.set(true, forKey: Constants.UserDefaultsKeys.hasShownWizardOnce)
    }

    // MARK: - GitHub Star Prompt Tracking

    func saveFirstLaunchDate(_ date: Date) {
        defaults.set(date, forKey: Constants.UserDefaultsKeys.firstLaunchDate)
    }

    func loadFirstLaunchDate() -> Date? {
        return defaults.object(forKey: Constants.UserDefaultsKeys.firstLaunchDate) as? Date
    }

    func saveLastGitHubStarPromptDate(_ date: Date) {
        defaults.set(date, forKey: Constants.UserDefaultsKeys.lastGitHubStarPromptDate)
    }

    func loadLastGitHubStarPromptDate() -> Date? {
        return defaults.object(forKey: Constants.UserDefaultsKeys.lastGitHubStarPromptDate) as? Date
    }

    func saveHasStarredGitHub(_ starred: Bool) {
        defaults.set(starred, forKey: Constants.UserDefaultsKeys.hasStarredGitHub)
    }

    func loadHasStarredGitHub() -> Bool {
        return defaults.bool(forKey: Constants.UserDefaultsKeys.hasStarredGitHub)
    }

    func saveNeverShowGitHubPrompt(_ neverShow: Bool) {
        defaults.set(neverShow, forKey: Constants.UserDefaultsKeys.neverShowGitHubPrompt)
    }

    func loadNeverShowGitHubPrompt() -> Bool {
        return defaults.bool(forKey: Constants.UserDefaultsKeys.neverShowGitHubPrompt)
    }

    func resetGitHubStarPromptForTesting() {
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.firstLaunchDate)
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.lastGitHubStarPromptDate)
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.hasStarredGitHub)
        defaults.removeObject(forKey: Constants.UserDefaultsKeys.neverShowGitHubPrompt)
    }
}
