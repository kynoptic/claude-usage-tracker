//
//  WindowCoordinator.swift
//  Claude Usage
//
//  Created by Claude Code on 2025-12-20.
//

import Cocoa
import SwiftUI

/// Coordinates window lifecycle (popover, settings, GitHub prompt, detached window).
///
/// `MenuBarManager` delegates all NSWindow/NSPopover creation and teardown to
/// this coordinator, keeping the manager focused on data, timer, and icon state.
final class WindowCoordinator: NSObject {
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var detachedWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var githubPromptWindow: NSWindow?

    /// The status bar button currently anchoring the popover (multi-profile aware).
    private weak var currentPopoverButton: NSStatusBarButton?

    private let setupPromptStore = SetupPromptStore.shared

    // MARK: - Popover Management

    /// Creates the initial popover with the given content view controller.
    func setupPopover(contentViewController: NSViewController) {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 600)
        popover.behavior = .semitransient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = contentViewController
        self.popover = popover
    }

    /// Replaces the current popover with a fresh one (e.g. after a profile switch).
    func recreatePopover(contentViewController: NSViewController) {
        if popover?.isShown == true {
            closePopover()
        }

        let newPopover = NSPopover()
        newPopover.contentSize = NSSize(width: 320, height: 600)
        newPopover.behavior = .semitransient
        newPopover.animates = true
        newPopover.delegate = self
        newPopover.contentViewController = contentViewController
        self.popover = newPopover

        LoggingService.shared.log("WindowCoordinator: Popover recreated for profile switch")
    }

    /// Toggles the popover at the given button, recreating content via `contentProvider`.
    ///
    /// In multi-profile mode the same popover may be re-anchored to a different
    /// status-bar button — the coordinator handles closing the old anchor first.
    func togglePopover(at button: NSStatusBarButton, contentProvider: () -> NSViewController) {
        // If there's a detached window, close it instead
        if let window = detachedWindow {
            window.close()
            detachedWindow = nil
            currentPopoverButton = nil
            return
        }

        guard let popover = popover else { return }

        if popover.isShown {
            if currentPopoverButton === button {
                // Same button — close
                closePopover()
            } else {
                // Different button — reanchor
                popover.performClose(nil)
                stopMonitoringForOutsideClicks()
                popover.contentViewController = contentProvider()
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
                NSApp.activate(ignoringOtherApps: true)
                currentPopoverButton = button
                startMonitoringForOutsideClicks()
            }
        } else {
            stopMonitoringForOutsideClicks()
            popover.contentViewController = contentProvider()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            NSApp.activate(ignoringOtherApps: true)
            currentPopoverButton = button
            startMonitoringForOutsideClicks()
        }
    }

    func closePopover() {
        popover?.performClose(nil)
        stopMonitoringForOutsideClicks()
        currentPopoverButton = nil
    }

    func closePopoverOrWindow() {
        if let window = detachedWindow {
            window.close()
            detachedWindow = nil
        } else {
            popover?.performClose(nil)
        }
    }

    // MARK: - Settings Window

    /// Opens the settings window, closing the popover first.
    func showSettings() {
        closePopoverOrWindow()

        // If settings window already exists, just bring it to front
        if let existingWindow = settingsWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Small delay to ensure smooth transition
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(0.15 * 1_000_000_000))
            await MainActor.run {
                guard let self else { return }

                NSApp.setActivationPolicy(.regular)

                let settingsView = SettingsView()
                let hostingController = NSHostingController(rootView: settingsView)

                let window = NSWindow(contentViewController: hostingController)
                window.title = "Claude Usage - Settings"
                window.styleMask = [.titled, .closable, .miniaturizable]
                window.setContentSize(NSSize(width: 720, height: 600))
                window.center()
                window.isReleasedWhenClosed = false
                window.isRestorable = false
                window.delegate = self

                self.settingsWindow = window

                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    // MARK: - GitHub Star Prompt

    /// Shows the GitHub star prompt window with the given action callbacks.
    func showGitHubStarPrompt(
        onStar: @escaping () -> Void,
        onMaybeLater: @escaping () -> Void,
        onDontAskAgain: @escaping () -> Void
    ) {
        // If window already exists, just bring it to front
        if let existingWindow = githubPromptWindow, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        NSApp.setActivationPolicy(.regular)

        let promptView = GitHubStarPromptView(
            onStar: { [weak self] in
                onStar()
                self?.closeGitHubPrompt()
            },
            onMaybeLater: { [weak self] in
                onMaybeLater()
                self?.closeGitHubPrompt()
            },
            onDontAskAgain: { [weak self] in
                onDontAskAgain()
                self?.closeGitHubPrompt()
            }
        )

        let hostingController = NSHostingController(rootView: promptView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = ""
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.setContentSize(NSSize(width: 300, height: 145))
        window.center()
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.level = .floating
        window.delegate = self

        githubPromptWindow = window

        setupPromptStore.saveLastGitHubStarPromptDate(Date())

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Closes the GitHub prompt window and hides the dock icon.
    private func closeGitHubPrompt() {
        githubPromptWindow?.close()
        githubPromptWindow = nil
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Event Monitoring

    private func startMonitoringForOutsideClicks() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self,
                  let popover = self.popover,
                  popover.isShown,
                  self.detachedWindow == nil else { return }
            self.closePopover()
        }
    }

    private func stopMonitoringForOutsideClicks() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        stopMonitoringForOutsideClicks()
        detachedWindow?.close()
        detachedWindow = nil
        settingsWindow?.close()
        settingsWindow = nil
        githubPromptWindow?.close()
        githubPromptWindow = nil
        popover = nil
    }
}

// MARK: - NSPopoverDelegate

extension WindowCoordinator: NSPopoverDelegate {
    func popoverShouldDetach(_ popover: NSPopover) -> Bool {
        // Detachment disabled: dragging while a card-flip animation is in-flight causes
        // NSPopover._dragFromScreenLocation: to open an inner run loop that flushes a
        // CA transaction, which hits a baseline-constraint exception on the
        // rotation3DEffect view and crashes via NSApplication._crashOnException:.
        return false
    }

    func popoverDidClose(_ notification: Notification) {
        stopMonitoringForOutsideClicks()
    }
}

// MARK: - NSWindowDelegate

extension WindowCoordinator: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window === settingsWindow {
                NSApp.setActivationPolicy(.accessory)
                settingsWindow = nil
            } else if window === detachedWindow {
                detachedWindow = nil
            } else if window === githubPromptWindow {
                NSApp.setActivationPolicy(.accessory)
                githubPromptWindow = nil
            }
        }
    }
}
