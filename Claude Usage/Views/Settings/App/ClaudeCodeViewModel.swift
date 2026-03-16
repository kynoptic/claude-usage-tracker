import Combine
import Foundation

/// ViewModel for ClaudeCodeView. Manages statusline configuration state and
/// routes all DataStore / StatuslineService interactions through domain methods.
@MainActor
final class ClaudeCodeViewModel: ObservableObject {

    // MARK: - Properties

    @Published var showDirectory: Bool
    @Published var showBranch: Bool
    @Published var showUsage: Bool
    @Published var showProgressBar: Bool
    @Published var showResetTime: Bool
    @Published var showTimeMarker: Bool
    @Published var statusMessage: String?
    @Published var isSuccess: Bool = true

    private let statuslineConfigStore = StatuslineConfigStore.shared
    private let statuslineService = StatuslineService.shared

    // MARK: - Initialization

    init() {
        showDirectory = StatuslineConfigStore.shared.loadStatuslineShowDirectory()
        showBranch = StatuslineConfigStore.shared.loadStatuslineShowBranch()
        showUsage = StatuslineConfigStore.shared.loadStatuslineShowUsage()
        showProgressBar = StatuslineConfigStore.shared.loadStatuslineShowProgressBar()
        showResetTime = StatuslineConfigStore.shared.loadStatuslineShowResetTime()
        showTimeMarker = StatuslineConfigStore.shared.loadStatuslineShowTimeMarker()
    }

    // MARK: - Public Methods

    /// Applies the current configuration to Claude Code statusline.
    /// Installs scripts, updates config file, and enables statusline in settings.json.
    func applyConfiguration() {
        guard showDirectory || showBranch || showUsage else {
            statusMessage = "claudecode.error_no_components".localized
            isSuccess = false
            return
        }

        guard statuslineService.hasValidSessionKey() else {
            statusMessage = "claudecode.error_no_sessionkey".localized
            isSuccess = false
            return
        }

        statuslineConfigStore.saveStatuslineShowDirectory(showDirectory)
        statuslineConfigStore.saveStatuslineShowBranch(showBranch)
        statuslineConfigStore.saveStatuslineShowUsage(showUsage)
        statuslineConfigStore.saveStatuslineShowProgressBar(showProgressBar)
        statuslineConfigStore.saveStatuslineShowResetTime(showResetTime)
        statuslineConfigStore.saveStatuslineShowTimeMarker(showTimeMarker)

        do {
            try statuslineService.installScripts()
            try statuslineService.updateConfiguration(
                showDirectory: showDirectory,
                showBranch: showBranch,
                showUsage: showUsage,
                showProgressBar: showProgressBar,
                showResetTime: showResetTime,
                showTimeMarker: showTimeMarker,
                showGreyZone: AppearanceStore.shared.loadShowGreyZone()
            )
            try statuslineService.updateClaudeCodeSettings(enabled: true)

            statusMessage = "claudecode.success_applied".localized
            isSuccess = true
        } catch {
            statusMessage = "error.generic".localized(with: error.localizedDescription)
            isSuccess = false
        }
    }

    /// Disables the statusline by removing it from Claude CLI settings.json.
    func resetConfiguration() {
        do {
            try statuslineService.updateClaudeCodeSettings(enabled: false)
            statusMessage = "claudecode.success_disabled".localized
            isSuccess = true
        } catch {
            statusMessage = "error.generic".localized(with: error.localizedDescription)
            isSuccess = false
        }
    }

    /// Dismisses the status message.
    func clearStatus() {
        statusMessage = nil
    }
}
