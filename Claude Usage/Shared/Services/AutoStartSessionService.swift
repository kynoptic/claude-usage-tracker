//
//  AutoStartSessionService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-11.
//

import Foundation
import Cocoa

/// Background service that monitors all profiles and auto-starts sessions when they reset
@MainActor
final class AutoStartSessionService {
    static let shared = AutoStartSessionService()

    // Timer for 5-minute check cycle
    private var checkTimer: Timer?

    // Track last check time to prevent duplicate checks on wake
    private var lastCheckTime: Date = .distantPast

    // Observers for sleep/wake notifications
    private var wakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?

    private let apiService: ClaudeAPIService
    private let profileManager: ProfileManager
    private let notificationManager: NotificationManager
    private let session: URLSession

    // Track last captured reset time per profile to prevent duplicate auto-starts
    private var lastCapturedResetTime: [UUID: Date] = [:]

    private init() {
        self.session = .shared
        self.apiService = ClaudeAPIService(session: .shared)
        self.profileManager = ProfileManager.shared
        self.notificationManager = NotificationManager.shared
    }

    // MARK: - Lifecycle

    func start() {
        // Start 5-minute check timer with tolerance for energy efficiency
        let timer = Timer.scheduledTimer(
            withTimeInterval: 300, // 5 minutes
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.performCheckIfNeeded(source: "timer")
            }
        }
        timer.tolerance = 30 // Allow up to 30 seconds of drift for energy efficiency
        checkTimer = timer

        // Register for wake/sleep notifications
        let workspace = NSWorkspace.shared

        wakeObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                LoggingService.shared.logInfo("Mac woke from sleep - checking for session resets")
                await self.performCheckIfNeeded(source: "wake")
            }
        }

        sleepObserver = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { _ in
            LoggingService.shared.logDebug("Mac going to sleep")
        }

        LoggingService.shared.logInfo("AutoStartSessionService started (5-minute cycle + wake detection)")

        // Perform immediate initial check to populate state
        Task { @MainActor in
            await self.performCheckIfNeeded(source: "startup")
        }
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil

        // Remove observers
        if let wakeObserver = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        if let sleepObserver = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
            self.sleepObserver = nil
        }

        LoggingService.shared.logInfo("AutoStartSessionService stopped")
    }

    // MARK: - Profile Checking

    /// Performs check with debouncing to prevent duplicate checks
    private func performCheckIfNeeded(source: String) async {
        // Debounce: Don't check if we checked less than 10 seconds ago
        let timeSinceLastCheck = Date().timeIntervalSince(lastCheckTime)
        if timeSinceLastCheck < 10 {
            LoggingService.shared.logDebug("Skipping check from \(source) - checked \(Int(timeSinceLastCheck))s ago")
            return
        }

        lastCheckTime = Date()
        await checkAllProfiles(source: source)
    }

    private func checkAllProfiles(source: String) async {
        LoggingService.shared.logDebug("AutoStartSessionService: Checking all profiles for auto-start (source: \(source))")

        // Get all profiles with auto-start enabled
        let profilesWithAutoStart = profileManager.profiles.filter { $0.autoStartSessionEnabled }

        guard !profilesWithAutoStart.isEmpty else {
            LoggingService.shared.logDebug("No profiles with auto-start enabled")
            return
        }

        LoggingService.shared.logInfo("Checking \(profilesWithAutoStart.count) profile(s) with auto-start enabled")

        // Check each profile
        for profile in profilesWithAutoStart {
            await checkProfile(profile)
        }
    }

    private func checkProfile(_ profile: Profile) async {
        // Skip if profile doesn't have Claude.ai credentials
        guard profile.hasClaudeAI else {
            LoggingService.shared.logDebug("Skipping profile '\(profile.name)' - no Claude.ai credentials")
            return
        }

        do {
            // Fetch current usage for this profile
            let usage = try await fetchUsageForProfile(profile)

            let currentPercentage = usage.sessionPercentage

            // Simple logic (like v1.1.0): If session is at 0%, start it
            // The initialization message will bring usage above 0%, preventing repeated starts
            if currentPercentage == 0.0 {
                // Check if we recently auto-started and should wait for reset
                if let lastResetTime = lastCapturedResetTime[profile.id],
                   Date() < lastResetTime {
                    let minutesRemaining = Int(lastResetTime.timeIntervalSinceNow / 60)
                    LoggingService.shared.logDebug("Profile '\(profile.name)': skipping auto-start - \(minutesRemaining)m until session reset")
                    return
                }

                LoggingService.shared.logInfo("Session at 0% for profile '\(profile.name)' - triggering auto-start")

                // Auto-start the session
                await autoStartSession(for: profile)
            } else {
                // Session is active, clear any tracked reset time since usage endpoint is now showing correct data
                lastCapturedResetTime.removeValue(forKey: profile.id)
                LoggingService.shared.logDebug("Profile '\(profile.name)': session at \(currentPercentage)% (active)")
            }

        } catch {
            LoggingService.shared.logError("Failed to check profile '\(profile.name)': \(error.localizedDescription)")
        }
    }

    private func fetchUsageForProfile(_ profile: Profile) async throws -> ClaudeUsage {
        // Delegate to the canonical fetch path (CLI OAuth → cookie fallback)
        let usage = try await apiService.fetchUsage(for: profile)

        // Save usage to profile
        ProfileUsageDataService.shared.saveClaudeUsage(usage, for: profile.id)

        return usage
    }

    /// Parse the completion response (SSE format) to extract session reset time from messageLimit.windows.5h
    private func parseCompletionResponseForResetTime(_ data: Data) -> Date? {
        guard let responseString = String(data: data, encoding: .utf8) else { return nil }

        // The response is SSE format - find the last completion event with messageLimit data
        let lines = responseString.components(separatedBy: "\n")
        for line in lines.reversed() {
            if line.hasPrefix("data: "),
               let jsonStart = line.index(line.startIndex, offsetBy: 6, limitedBy: line.endIndex),
               let jsonData = String(line[jsonStart...]).data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let messageLimit = json["messageLimit"] as? [String: Any],
               let windows = messageLimit["windows"] as? [String: Any],
               let fiveH = windows["5h"] as? [String: Any],
               let resetsAt = fiveH["resets_at"] as? Double {
                return Date(timeIntervalSince1970: resetsAt)
            }
        }
        return nil
    }

    // MARK: - Auto-Start Session

    private func autoStartSession(for profile: Profile) async {
        guard let sessionKey = profile.claudeSessionKey,
              let orgId = profile.organizationId else {
            LoggingService.shared.logError("Failed to auto-start session for profile '\(profile.name)': missing credentials")
            notificationManager.sendAutoStartNotification(
                profileName: profile.name,
                success: false,
                error: "Missing credentials"
            )
            return
        }

        do {
            // Delegate to the shared API service implementation and get response data
            let responseData = try await apiService.sendInitializationMessage(
                sessionKey: sessionKey,
                organizationId: orgId
            )

            // Capture reset time from response to prevent duplicate auto-starts
            if let data = responseData,
               let resetTime = parseCompletionResponseForResetTime(data) {
                lastCapturedResetTime[profile.id] = resetTime
                LoggingService.shared.logInfo("Captured session reset time for '\(profile.name)': \(resetTime)")
            }

            LoggingService.shared.logInfo("Successfully auto-started session for profile '\(profile.name)'")

            // Send success notification
            notificationManager.sendAutoStartNotification(
                profileName: profile.name,
                success: true,
                error: nil
            )

        } catch {
            LoggingService.shared.logError("Failed to auto-start session for profile '\(profile.name)': \(error.localizedDescription)")

            // Send failure notification
            notificationManager.sendAutoStartNotification(
                profileName: profile.name,
                success: false,
                error: error.localizedDescription
            )
        }
    }
}
