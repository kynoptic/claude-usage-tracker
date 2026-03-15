//
//  MenuBarManager+Observers.swift
//  Claude Usage
//
//  NotificationCenter and KVO observers extracted from MenuBarManager.
//

import Foundation

extension MenuBarManager {

    // MARK: - Icon Configuration

    /// Registers a `NotificationCenter` observer for `.menuBarIconConfigChanged`.
    /// When the notification fires, updates the status-bar icon configuration for the active display mode.
    func observeIconConfigChanges() {
        iconConfigObserver = NotificationCenter.default.addObserver(
            forName: .menuBarIconConfigChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            Task { @MainActor in
                if self.profileManager.displayMode == .multi {
                    self.setupMultiProfileMode()
                } else {
                    let newConfig = self.profileManager.activeProfile?.iconConfig ?? .default
                    self.updateMenuBarDisplay(with: newConfig)
                }
            }
        }
    }

    // MARK: - Credential Changes

    /// Registers a `NotificationCenter` observer for `.credentialsChanged`.
    /// When credentials are updated, triggers an immediate usage refresh if the active profile
    /// now has valid credentials, or falls back to the default logo state if it does not.
    func observeCredentialChanges() {
        credentialsObserver = NotificationCenter.default.addObserver(
            forName: .credentialsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            Task { @MainActor in
                guard let profile = self.profileManager.activeProfile, profile.hasUsageCredentials else {
                    LoggingService.shared.logInfo("Credentials changed but no usage credentials - showing default logo")
                    let config = self.profileManager.activeProfile?.iconConfig ?? .default
                    self.updateMenuBarDisplay(with: config)
                    return
                }

                LoggingService.shared.logInfo("Credentials changed - triggering immediate refresh")
                self.updateMenuBarDisplay(with: profile.iconConfig)
                self.refreshUsage()
            }
        }
    }

    // MARK: - Display Mode

    /// Registers a `NotificationCenter` observer for `.displayModeChanged`.
    /// When the display mode changes, delegates to `handleDisplayModeChange()` to switch the
    /// status-bar UI between single-profile and multi-profile layouts.
    func observeDisplayModeChanges() {
        displayModeObserver = NotificationCenter.default.addObserver(
            forName: .displayModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }

            Task { @MainActor in
                self.handleDisplayModeChange()
            }
        }
    }
}
