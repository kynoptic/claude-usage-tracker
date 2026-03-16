import Combine
import Foundation

/// Manages Claude Code statusline component visibility preferences.
@MainActor
final class StatuslineConfigStore: ObservableObject {
    static let shared = StatuslineConfigStore()

    private let defaults: UserDefaults

    private init() {
        self.defaults = UserDefaults.standard
    }

    // MARK: - Component Visibility

    func saveStatuslineShowDirectory(_ show: Bool) {
        defaults.set(show, forKey: Constants.UserDefaultsKeys.statuslineShowDirectory)
    }

    func loadStatuslineShowDirectory() -> Bool {
        if defaults.object(forKey: Constants.UserDefaultsKeys.statuslineShowDirectory) == nil { return true }
        return defaults.bool(forKey: Constants.UserDefaultsKeys.statuslineShowDirectory)
    }

    func saveStatuslineShowBranch(_ show: Bool) {
        defaults.set(show, forKey: Constants.UserDefaultsKeys.statuslineShowBranch)
    }

    func loadStatuslineShowBranch() -> Bool {
        if defaults.object(forKey: Constants.UserDefaultsKeys.statuslineShowBranch) == nil { return true }
        return defaults.bool(forKey: Constants.UserDefaultsKeys.statuslineShowBranch)
    }

    func saveStatuslineShowUsage(_ show: Bool) {
        defaults.set(show, forKey: Constants.UserDefaultsKeys.statuslineShowUsage)
    }

    func loadStatuslineShowUsage() -> Bool {
        if defaults.object(forKey: Constants.UserDefaultsKeys.statuslineShowUsage) == nil { return true }
        return defaults.bool(forKey: Constants.UserDefaultsKeys.statuslineShowUsage)
    }

    func saveStatuslineShowProgressBar(_ show: Bool) {
        defaults.set(show, forKey: Constants.UserDefaultsKeys.statuslineShowProgressBar)
    }

    func loadStatuslineShowProgressBar() -> Bool {
        if defaults.object(forKey: Constants.UserDefaultsKeys.statuslineShowProgressBar) == nil { return true }
        return defaults.bool(forKey: Constants.UserDefaultsKeys.statuslineShowProgressBar)
    }

    func saveStatuslineShowResetTime(_ show: Bool) {
        defaults.set(show, forKey: Constants.UserDefaultsKeys.statuslineShowResetTime)
    }

    func loadStatuslineShowResetTime() -> Bool {
        if defaults.object(forKey: Constants.UserDefaultsKeys.statuslineShowResetTime) == nil { return true }
        return defaults.bool(forKey: Constants.UserDefaultsKeys.statuslineShowResetTime)
    }

    func saveStatuslineShowTimeMarker(_ show: Bool) {
        defaults.set(show, forKey: Constants.UserDefaultsKeys.statuslineShowTimeMarker)
    }

    func loadStatuslineShowTimeMarker() -> Bool {
        if defaults.object(forKey: Constants.UserDefaultsKeys.statuslineShowTimeMarker) == nil { return true }
        return defaults.bool(forKey: Constants.UserDefaultsKeys.statuslineShowTimeMarker)
    }
}
