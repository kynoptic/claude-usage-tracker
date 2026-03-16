import Combine
import Foundation

/// Manages menu bar icon configuration, grey zone, monochrome mode, and icon name preferences.
@MainActor
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        self.defaults = UserDefaults.standard
    }

    // MARK: - Menu Bar Icon Style (Legacy)

    func saveMenuBarIconStyle(_ style: MenuBarIconStyle) {
        defaults.set(style.rawValue, forKey: Constants.UserDefaultsKeys.menuBarIconStyle)
    }

    func loadMenuBarIconStyle() -> MenuBarIconStyle {
        guard let rawValue = defaults.string(forKey: Constants.UserDefaultsKeys.menuBarIconStyle),
              let style = MenuBarIconStyle(rawValue: rawValue) else {
            return .battery
        }
        return style
    }

    func saveMonochromeMode(_ enabled: Bool) {
        defaults.set(enabled, forKey: Constants.UserDefaultsKeys.monochromeMode)
    }

    func loadMonochromeMode() -> Bool {
        return defaults.bool(forKey: Constants.UserDefaultsKeys.monochromeMode)
    }

    // MARK: - Menu Bar Icon Configuration (Multi-Metric System)

    func saveMenuBarIconConfiguration(_ config: MenuBarIconConfiguration) {
        do {
            let data = try encoder.encode(config)
            defaults.set(data, forKey: Constants.UserDefaultsKeys.menuBarIconConfiguration)
        } catch {
            LoggingService.shared.logStorageError("saveMenuBarIconConfiguration", error: error)
        }
    }

    func loadMenuBarIconConfiguration() -> MenuBarIconConfiguration {
        if let data = defaults.data(forKey: Constants.UserDefaultsKeys.menuBarIconConfiguration) {
            do {
                return try decoder.decode(MenuBarIconConfiguration.self, from: data)
            } catch {
                LoggingService.shared.logStorageError("loadMenuBarIconConfiguration", error: error)
            }
        }
        return migrateFromLegacySettings()
    }

    private func migrateFromLegacySettings() -> MenuBarIconConfiguration {
        var config = MenuBarIconConfiguration.default
        config.monochromeMode = loadMonochromeMode()
        let legacyStyle = loadMenuBarIconStyle()
        if var sessionConfig = config.config(for: .session) {
            sessionConfig.iconStyle = legacyStyle
            sessionConfig.isEnabled = true
            config.updateConfig(sessionConfig)
        }
        saveMenuBarIconConfiguration(config)
        return config
    }

    // MARK: - Grey Zone

    func saveShowGreyZone(_ show: Bool) {
        defaults.set(show, forKey: Constants.UserDefaultsKeys.showGreyZone)
    }

    func loadShowGreyZone() -> Bool {
        return defaults.bool(forKey: Constants.UserDefaultsKeys.showGreyZone)
    }

    func saveGreyThreshold(_ threshold: Double) {
        let clamped = min(max(threshold, 0.1), 0.8)
        defaults.set(clamped, forKey: Constants.UserDefaultsKeys.greyThreshold)
    }

    func loadGreyThreshold() -> Double {
        guard defaults.object(forKey: Constants.UserDefaultsKeys.greyThreshold) != nil else {
            return Constants.greyThresholdDefault
        }
        let value = defaults.double(forKey: Constants.UserDefaultsKeys.greyThreshold)
        return min(max(value, 0.1), 0.8)
    }

    // MARK: - Chart Color Mode

    func saveChartColorMode(_ mode: ChartColorMode) {
        defaults.set(mode.rawValue, forKey: Constants.UserDefaultsKeys.chartColorMode)
    }

    func loadChartColorMode() -> ChartColorMode {
        guard let rawValue = defaults.string(forKey: Constants.UserDefaultsKeys.chartColorMode),
              let mode = ChartColorMode(rawValue: rawValue) else {
            return .uniform
        }
        return mode
    }

    // MARK: - Icon Names

    func saveShowIconNames(_ show: Bool) {
        defaults.set(show, forKey: Constants.UserDefaultsKeys.showIconNames)
    }

    func loadShowIconNames() -> Bool {
        if defaults.object(forKey: Constants.UserDefaultsKeys.showIconNames) == nil {
            return true
        }
        return defaults.bool(forKey: Constants.UserDefaultsKeys.showIconNames)
    }

    // MARK: - Per-Metric Configuration Helpers

    func updateMetricConfig(_ metricConfig: MetricIconConfig) {
        var fullConfig = loadMenuBarIconConfiguration()
        fullConfig.updateConfig(metricConfig)
        saveMenuBarIconConfiguration(fullConfig)
    }

    func loadMetricConfig(for metricType: MenuBarMetricType) -> MetricIconConfig? {
        return loadMenuBarIconConfiguration().config(for: metricType)
    }

    func setMetricEnabled(_ metricType: MenuBarMetricType, enabled: Bool) {
        var config = loadMenuBarIconConfiguration()
        if var metricConfig = config.config(for: metricType) {
            metricConfig.isEnabled = enabled
            config.updateConfig(metricConfig)
            saveMenuBarIconConfiguration(config)
        }
    }

    func updateMetricOrder(metricType: MenuBarMetricType, order: Int) {
        var config = loadMenuBarIconConfiguration()
        if var metricConfig = config.config(for: metricType) {
            metricConfig.order = order
            config.updateConfig(metricConfig)
            saveMenuBarIconConfiguration(config)
        }
    }

    func updateMetricIconStyle(metricType: MenuBarMetricType, style: MenuBarIconStyle) {
        var config = loadMenuBarIconConfiguration()
        if var metricConfig = config.config(for: metricType) {
            metricConfig.iconStyle = style
            config.updateConfig(metricConfig)
            saveMenuBarIconConfiguration(config)
        }
    }

    func updateWeekDisplayMode(_ mode: WeekDisplayMode) {
        var config = loadMenuBarIconConfiguration()
        if var weekConfig = config.config(for: .week) {
            weekConfig.weekDisplayMode = mode
            config.updateConfig(weekConfig)
            saveMenuBarIconConfiguration(config)
        }
    }

    func updateAPIDisplayMode(_ mode: APIDisplayMode) {
        var config = loadMenuBarIconConfiguration()
        if var apiConfig = config.config(for: .api) {
            apiConfig.apiDisplayMode = mode
            config.updateConfig(apiConfig)
            saveMenuBarIconConfiguration(config)
        }
    }
}
