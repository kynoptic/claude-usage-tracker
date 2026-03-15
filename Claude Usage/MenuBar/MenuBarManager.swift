import Cocoa
import SwiftUI
import Combine

/// Primary ViewModel for the menu bar app. Owns the refresh timer, orchestrates all service
/// calls, manages the popover lifecycle, and is the main dependency of every SwiftUI view.
@MainActor
final class MenuBarManager: NSObject, ObservableObject {
    // MARK: - Properties

    /// The most recent Claude token-usage snapshot for the active profile.
    @Published private(set) var usage: ClaudeUsage = .empty
    /// The current Claude API status (e.g., operational, degraded, incident).
    @Published private(set) var status: ClaudeStatus = .unknown
    /// Raw API-level usage metrics for the active profile, if available.
    @Published private(set) var apiUsage: APIUsage?
    /// `true` while a refresh network request is in flight.
    @Published private(set) var isRefreshing: Bool = false
    /// Timestamp of the last successfully completed usage fetch.
    @Published private(set) var lastSuccessfulFetch: Date?
    /// `true` when the cached usage data has exceeded the staleness threshold or the scheduler is backing off.
    @Published private(set) var isStale: Bool = false
    /// The most recent error that caused a refresh to fail, or `nil` when the last refresh succeeded.
    @Published private(set) var lastRefreshError: AppError?
    /// The earliest date at which an automatic retry will be attempted after an error.
    @Published private(set) var nextRetryDate: Date?
    /// The scheduled date of the next automatic refresh when no error is pending.
    @Published private(set) var nextRefreshAt: Date?
    /// Burn-up pacing context derived from the active profile's elapsed session fraction.
    @Published private(set) var pacingContext: PacingContext = .none
    /// The ID of the profile whose status-bar button was most recently clicked.
    @Published private(set) var clickedProfileId: UUID?
    /// The cached Claude usage snapshot for the profile that was clicked, used to populate the popover.
    @Published private(set) var clickedProfileUsage: ClaudeUsage?
    /// The cached API usage snapshot for the profile that was clicked, used to populate the popover.
    @Published private(set) var clickedProfileAPIUsage: APIUsage?

    private var statusBarUIManager: StatusBarUIManager?
    private var refreshTimer: Timer?
    private var pollingScheduler = PollingScheduler()
    private var lastRefreshTriggerTime: Date = .distantPast
    private let windowCoordinator = WindowCoordinator()
    private let refreshOrchestrator = RefreshOrchestrator()
    private let dataStore = DataStore.shared
    private let networkMonitor = NetworkMonitor.shared
    let profileManager = ProfileManager.shared
    private let autoStartService = AutoStartSessionService.shared
    private var cancellables = Set<AnyCancellable>()
    private var hasHandledFirstProfileSwitch = false
    // NotificationCenter observers — assigned in MenuBarManager+Observers.swift (requires internal access).
    // All are removed in cleanup().
    var iconConfigObserver: NSObjectProtocol?
    var credentialsObserver: NSObjectProtocol?
    var displayModeObserver: NSObjectProtocol?
    private var refreshIntervalObserver: NSKeyValueObservation?
    private var updateDebounceTimer: Timer?
    private var cachedIsDarkMode: Bool = false

    // MARK: - Setup

    /// Initializes the status-bar UI, popover, network monitor, and auto-refresh timer.
    /// Call once during app launch after the manager is instantiated.
    func setup() {
        cachedIsDarkMode = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        observeProfileChanges()

        statusBarUIManager = StatusBarUIManager()
        statusBarUIManager?.delegate = self

        if profileManager.displayMode == .multi {
            setupMultiProfileMode()
        } else {
            let config = profileManager.activeProfile?.iconConfig ?? .default
            let hasCredentials = profileManager.activeProfile?.hasUsageCredentials ?? false
            statusBarUIManager?.setup(target: self, action: #selector(togglePopover), config: Self.displayConfig(from: config, hasUsageCredentials: hasCredentials))
        }

        windowCoordinator.setupPopover(contentViewController: createContentViewController())
        loadSavedProfileData()

        networkMonitor.onNetworkAvailable = { [weak self] in
            guard let self, let profile = self.profileManager.activeProfile, profile.hasUsageCredentials else {
                LoggingService.shared.log("Skipping network-available refresh (no usage credentials)")
                return
            }
            if Date().timeIntervalSince(self.lastRefreshTriggerTime) > 2.0 {
                self.refreshUsage()
            }
        }
        networkMonitor.startMonitoring()

        if let profile = profileManager.activeProfile, profile.hasUsageCredentials {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000))
                self?.refreshUsage()
            }
        }

        startAutoRefresh()
        autoStartService.start()
        observeIconConfigChanges()
        observeCredentialChanges()
        observeDisplayModeChanges()
    }

    /// Tears down all timers, observers, and UI resources. Call before the manager is deallocated
    /// or the application terminates.
    func cleanup() {
        refreshTimer?.invalidate(); refreshTimer = nil; nextRefreshAt = nil
        networkMonitor.stopMonitoring(); autoStartService.stop(); cancellables.removeAll()
        refreshIntervalObserver?.invalidate(); refreshIntervalObserver = nil
        for obs in [iconConfigObserver, credentialsObserver, displayModeObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(obs)
        }
        iconConfigObserver = nil; credentialsObserver = nil; displayModeObserver = nil
        windowCoordinator.cleanup(); statusBarUIManager?.cleanup(); statusBarUIManager = nil
    }

    // MARK: - Popover Toggle

    @objc private func togglePopover(_ sender: Any?) {
        let clickedButton = (sender as? NSStatusBarButton) ?? statusBarUIManager?.primaryButton
        guard let button = clickedButton else { return }

        if statusBarUIManager?.isInMultiProfileMode == true,
           let profileId = statusBarUIManager?.profileId(for: button),
           let profile = profileManager.profiles.first(where: { $0.id == profileId }) {
            clickedProfileId = profileId
            clickedProfileUsage = profile.claudeUsage ?? .empty
            clickedProfileAPIUsage = profile.apiUsage
        } else {
            clickedProfileId = profileManager.activeProfile?.id
            clickedProfileUsage = nil
            clickedProfileAPIUsage = nil
        }

        windowCoordinator.togglePopover(at: button) { [weak self] in
            self?.createContentViewController() ?? NSViewController()
        }
    }

    // MARK: - Profile Observation

    private func observeProfileChanges() {
        let initialProfileId = profileManager.activeProfile?.id

        profileManager.$activeProfile
            .removeDuplicates { $0?.id == $1?.id }
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newProfile in
                guard let self, let profile = newProfile else { return }
                if !self.hasHandledFirstProfileSwitch && profile.id == initialProfileId {
                    self.hasHandledFirstProfileSwitch = true
                    return
                }
                self.hasHandledFirstProfileSwitch = true
                Task { @MainActor in await self.handleProfileSwitch(to: profile) }
            }
            .store(in: &cancellables)
    }

    private func handleProfileSwitch(to profile: Profile) async {
        LoggingService.shared.log("MenuBarManager: Handling profile switch to: \(profile.name)")

        self.usage = profile.claudeUsage ?? .empty
        self.apiUsage = profile.apiUsage

        pollingScheduler = PollingScheduler(baseInterval: profile.refreshInterval)
        startAutoRefresh()

        if profileManager.displayMode == .multi {
            setupMultiProfileMode()
        } else {
            updateMenuBarDisplay(with: profile.iconConfig)
        }

        windowCoordinator.recreatePopover(contentViewController: createContentViewController())

        if profile.hasUsageCredentials {
            lastRefreshTriggerTime = Date()
            refreshUsage()
        }
    }

    // MARK: - Status Bar Icons

    /// Redraws all status-bar buttons with the latest usage data for the current display mode
    /// (single-profile icon update or multi-profile button set).
    func updateAllStatusBarIcons() {
        if profileManager.displayMode == .multi {
            statusBarUIManager?.updateMultiProfileButtons(profiles: profileManager.profiles, config: profileManager.multiProfileConfig)
        } else {
            statusBarUIManager?.updateAllButtons(usage: usage, apiUsage: apiUsage)
        }
    }

    /// Applies a new icon configuration to the single-profile status-bar button and redraws it.
    /// No-ops when the app is in multi-profile display mode.
    /// - Parameter config: The icon configuration to apply to the active profile's status-bar button.
    func updateMenuBarDisplay(with config: MenuBarIconConfiguration) {
        guard profileManager.displayMode == .single else { return }
        let hasCredentials = profileManager.activeProfile?.hasUsageCredentials ?? false
        statusBarUIManager?.updateConfiguration(target: self, action: #selector(togglePopover), config: Self.displayConfig(from: config, hasUsageCredentials: hasCredentials))
        updateAllStatusBarIcons()
    }

    // MARK: - Auto Refresh

    /// Cancels any pending refresh timer and schedules the next one based on the current polling
    /// interval from `PollingScheduler`. Updates `nextRefreshAt` accordingly.
    func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        let interval = pollingScheduler.currentInterval
        nextRefreshAt = Date().addingTimeInterval(interval)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.refreshUsage()
        }
        LoggingService.shared.log("Scheduled next refresh in \(interval)s")
    }

    // MARK: - Display Mode

    /// Responds to a change in the user's display-mode preference by switching the status-bar UI
    /// between single-profile and multi-profile layouts.
    func handleDisplayModeChange() {
        if profileManager.displayMode == .multi {
            setupMultiProfileMode()
        } else {
            setupSingleProfileMode()
        }
    }

    /// Configures the status-bar UI for multi-profile mode: creates a button per selected profile,
    /// performs an initial icon update, and kicks off a refresh for all selected profiles.
    func setupMultiProfileMode() {
        let selectedProfiles = profileManager.getSelectedProfiles()
        statusBarUIManager?.setupMultiProfile(profiles: selectedProfiles, target: self, action: #selector(togglePopover))
        statusBarUIManager?.updateMultiProfileButtons(profiles: profileManager.profiles, config: profileManager.multiProfileConfig)
        LoggingService.shared.log("MenuBarManager: Multi-profile mode enabled with \(selectedProfiles.count) profiles")
        refreshAllSelectedProfiles()
    }

    private func setupSingleProfileMode() {
        guard let profile = profileManager.activeProfile else { return }
        let displayConfig = Self.displayConfig(from: profile.iconConfig, hasUsageCredentials: profile.hasUsageCredentials)
        statusBarUIManager?.setup(target: self, action: #selector(togglePopover), config: displayConfig)
        updateAllStatusBarIcons()
    }

    // MARK: - Data Refresh

    /// Triggers an immediate usage refresh for the active profile (single-profile mode) or all
    /// selected profiles (multi-profile mode). Sets `isRefreshing` while the fetch is in flight
    /// and reschedules the auto-refresh timer when it completes.
    func refreshUsage() {
        if profileManager.displayMode == .multi { refreshAllSelectedProfiles(); return }
        guard let profile = profileManager.activeProfile, profile.hasUsageCredentials else { updateAllStatusBarIcons(); return }

        Task {
            self.isRefreshing = true
            let result = await refreshOrchestrator.refreshSingleProfile(profile: profile, apiSessionKey: profile.apiSessionKey, apiOrganizationId: profile.apiOrganizationId)
            await applySingleProfileResult(result)
        }
    }

    @MainActor private func applySingleProfileResult(_ result: SingleProfileRefreshResult) {
        // Status is independent of usage success — update whenever present.
        if let s = result.status { status = s }

        if let u = result.usage {
            usage = u
            // Persist usage and any newly discovered org ID before updating UI.
            if let pid = profileManager.activeProfile?.id {
                profileManager.saveClaudeUsage(u, for: pid)
                if let orgId = result.newlyFetchedOrgId {
                    profileManager.updateOrganizationId(orgId, for: pid)
                }
            }
            UsageHistoryStore.shared.recordAll(from: u)
            pacingContext = Self.buildPacingContext(for: u)
            updateAllStatusBarIcons()
            if let p = profileManager.activeProfile { NotificationManager.shared.checkAndNotify(usage: u, profileName: p.name, settings: p.notificationSettings) }
            recordRefreshSuccess(usage: u)
        } else if let err = result.usageError {
            recordRefreshError(err)
        }

        // API usage is fetched independently; update it regardless of main usage result.
        if let a = result.apiUsage {
            apiUsage = a
            if let pid = profileManager.activeProfile?.id { profileManager.saveAPIUsage(a, for: pid) }
        }

        finalizeRefresh(userTriggeredSuccess: result.usageSuccess)
    }

    private func refreshAllSelectedProfiles() {
        let selected = profileManager.profiles.filter { $0.isSelectedForDisplay && $0.hasUsageCredentials }
        guard !selected.isEmpty else { updateAllStatusBarIcons(); return }

        Task {
            self.isRefreshing = true
            let result = await refreshOrchestrator.refreshMultipleProfiles(selected)
            await applyMultiProfileResult(result)
        }
    }

    @MainActor private func applyMultiProfileResult(_ result: MultiProfileRefreshResult) {
        if let s = result.status { status = s }
        for (pid, u) in result.profileUsage {
            profileManager.saveClaudeUsage(u, for: pid)
            UsageHistoryStore.shared.recordAll(from: u)
            if pid == profileManager.activeProfile?.id {
                usage = u; lastSuccessfulFetch = Date(); pacingContext = Self.buildPacingContext(for: u)
            }
        }
        statusBarUIManager?.updateMultiProfileButtons(profiles: profileManager.profiles, config: profileManager.multiProfileConfig)

        if let activeUsage = profileManager.activeProfile.flatMap({ result.profileUsage[$0.id] }) {
            recordRefreshSuccess(usage: activeUsage)
        } else if result.encounteredRateLimit {
            pollingScheduler.recordRateLimitError(retryAfter: result.rateLimitRetryAfter)
            lastRefreshError = AppError(code: .apiRateLimited, message: "Rate limited by Claude API", isRecoverable: true, retryAfter: result.rateLimitRetryAfter)
            nextRetryDate = Date().addingTimeInterval(result.rateLimitRetryAfter ?? pollingScheduler.currentInterval)
        }
        finalizeRefresh(userTriggeredSuccess: profileManager.activeProfile.flatMap({ result.profileUsage[$0.id] }) != nil)
    }

    // MARK: - Refresh Helpers

    @MainActor private func recordRefreshSuccess(usage: ClaudeUsage) {
        pollingScheduler.recordSuccess(usage: usage)
        lastSuccessfulFetch = Date()
        lastRefreshError = nil
        nextRetryDate = nil
    }

    @MainActor private func recordRefreshError(_ appError: AppError) {
        if appError.code == .apiRateLimited {
            pollingScheduler.recordRateLimitError(retryAfter: appError.retryAfter)
            nextRetryDate = Date().addingTimeInterval(appError.retryAfter ?? pollingScheduler.currentInterval)
        } else {
            pollingScheduler.recordOtherError()
            let requiresAction = appError.code == .apiUnauthorized || appError.code == .sessionKeyNotFound
            nextRetryDate = requiresAction ? nil : Date().addingTimeInterval(pollingScheduler.currentInterval)
        }
        lastRefreshError = appError
    }

    @MainActor private func finalizeRefresh(userTriggeredSuccess: Bool) {
        updateStaleness()
        isRefreshing = false
        if userTriggeredSuccess && abs(lastRefreshTriggerTime.timeIntervalSinceNow) < 5 {
            NotificationManager.shared.sendSuccessNotification()
        }
        startAutoRefresh()
    }

    // MARK: - Window Actions

    @objc func preferencesClicked() {
        windowCoordinator.closePopoverOrWindow()
        windowCoordinator.showSettings()
    }

    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }

    /// Presents the GitHub star prompt sheet. Handles the three user actions: star the repo,
    /// dismiss for later, or permanently suppress the prompt.
    func showGitHubStarPrompt() {
        windowCoordinator.showGitHubStarPrompt(
            onStar: { [weak self] in
                if let url = URL(string: Constants.GitHub.repoURL) { NSWorkspace.shared.open(url) }
                self?.dataStore.saveHasStarredGitHub(true)
            },
            onMaybeLater: {},
            onDontAskAgain: { [weak self] in self?.dataStore.saveNeverShowGitHubPrompt(true) }
        )
    }

    // MARK: - Private Helpers

    /// Creates a new `NSHostingController` wrapping `PopoverContentView`, wired up with refresh,
    /// preferences, and quit callbacks. Used to populate the popover on first show and after
    /// profile switches.
    /// - Returns: A hosting controller ready to be presented in the popover.
    func createContentViewController() -> NSHostingController<PopoverContentView> {
        let contentView = PopoverContentView(
            manager: self,
            onRefresh: { [weak self] in self?.refreshUsage() },
            onPreferences: { [weak self] in
                self?.windowCoordinator.closePopoverOrWindow()
                self?.preferencesClicked()
            },
            onQuit: { [weak self] in self?.quitClicked() }
        )
        return NSHostingController(rootView: contentView)
    }

    /// Returns a display configuration for the status-bar icon, disabling all metrics when the
    /// profile has no usage credentials so the icon falls back to the default logo state.
    /// - Parameters:
    ///   - config: The profile's stored `MenuBarIconConfiguration`.
    ///   - hasUsageCredentials: Whether the active profile has valid API credentials.
    /// - Returns: The original `config` when credentials are present; a metrics-disabled copy otherwise.
    static func displayConfig(from config: MenuBarIconConfiguration, hasUsageCredentials: Bool) -> MenuBarIconConfiguration {
        guard !hasUsageCredentials else { return config }
        return MenuBarIconConfiguration(
            monochromeMode: config.monochromeMode,
            showIconNames: config.showIconNames,
            metrics: config.metrics.map { var m = $0; m.isEnabled = false; return m }
        )
    }

    /// Derives the current burn-up `PacingContext` from a usage snapshot by computing
    /// the elapsed fraction of the session window.
    /// - Parameter usage: The `ClaudeUsage` snapshot to derive pacing from.
    /// - Returns: A `PacingContext` reflecting the proportion of the session that has elapsed.
    static func buildPacingContext(for usage: ClaudeUsage) -> PacingContext {
        let elapsed = UsageStatusCalculator.elapsedFraction(resetTime: usage.sessionResetTime, duration: Constants.sessionWindow, showRemaining: false)
        return PacingContext(elapsedFraction: elapsed)
    }

    /// Recomputes `isStale` based on the time since the last successful fetch and whether
    /// the polling scheduler is currently in back-off. Only writes the property when the value changes.
    func updateStaleness() {
        let stale: Bool
        if pollingScheduler.isBackingOff {
            stale = true
        } else if let lastFetch = lastSuccessfulFetch {
            stale = Date().timeIntervalSince(lastFetch) > Constants.RefreshIntervals.stalenessThreshold
        } else {
            stale = false
        }
        if isStale != stale { isStale = stale }
    }

    private func loadSavedProfileData() {
        guard let profile = profileManager.activeProfile else { return }
        if profile.hasUsageCredentials {
            if let savedUsage = profile.claudeUsage { usage = savedUsage }
            if let savedAPIUsage = profile.apiUsage { apiUsage = savedAPIUsage }
        } else {
            usage = .empty
            apiUsage = nil
        }
        updateAllStatusBarIcons()
    }
}

// MARK: - StatusBarUIManagerDelegate

extension MenuBarManager: StatusBarUIManagerDelegate {
    func statusBarAppearanceDidChange() {
        cachedIsDarkMode = NSApp.effectiveAppearance.name == .darkAqua
        updateAllStatusBarIcons()
    }
}
