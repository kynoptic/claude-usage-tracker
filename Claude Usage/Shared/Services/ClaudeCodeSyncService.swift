//
//  ClaudeCodeSyncService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-07.
//

import Foundation
import Security

/// Manages synchronization of Claude Code CLI credentials between system Keychain and profiles
class ClaudeCodeSyncService {
    static let shared = ClaudeCodeSyncService()

    /// Maximum time to wait for a security subprocess before timing out
    static let subprocessTimeout: TimeInterval = 10

    private init() {}

    // MARK: - System Keychain Access

    /// Reads Claude Code credentials from system Keychain using security command.
    /// Runs subprocess off the main actor with a per-process timeout.
    func readSystemCredentials() async throws -> String? {
        try await runOffMainActor {
            try self.readSystemCredentialsSync()
        }
    }

    /// Writes Claude Code credentials to system Keychain using security command.
    /// Runs subprocesses off the main actor with a per-process timeout.
    func writeSystemCredentials(_ jsonData: String) async throws {
        try await runOffMainActor {
            try self.writeSystemCredentialsSync(jsonData)
        }
    }

    // MARK: - Profile Sync Operations

    /// Syncs credentials from system to profile (one-time copy)
    func syncToProfile(_ profileId: UUID) async throws {
        guard let jsonData = try await readSystemCredentials() else {
            throw ClaudeCodeError.noCredentialsFound
        }

        // Validate JSON format
        guard let data = jsonData.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeCodeError.invalidJSON
        }

        // Save to profile directly
        var profiles = ProfileStore.shared.loadProfiles()
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else {
            throw ClaudeCodeError.noProfileCredentials
        }

        profiles[index].cliCredentialsJSON = jsonData
        profiles[index].hasValidOAuthCredentials = Profile.isValidOAuthJSON(jsonData)
        ProfileStore.shared.saveProfiles(profiles)

        LoggingService.shared.log("Synced CLI credentials to profile: \(profileId)")
    }

    /// Applies profile's CLI credentials to system (overwrites current login)
    func applyProfileCredentials(_ profileId: UUID) async throws {
        LoggingService.shared.log("Applying CLI credentials for profile: \(profileId)")

        let profiles = ProfileStore.shared.loadProfiles()
        guard let profile = profiles.first(where: { $0.id == profileId }),
              let jsonData = profile.cliCredentialsJSON else {
            LoggingService.shared.log("No CLI credentials found for profile: \(profileId)")
            throw ClaudeCodeError.noProfileCredentials
        }

        LoggingService.shared.log("Found CLI credentials, writing to keychain...")
        try await writeSystemCredentials(jsonData)

        LoggingService.shared.log("Applied profile CLI credentials to system: \(profileId)")
    }

    /// Removes CLI credentials from profile (doesn't affect system)
    func removeFromProfile(_ profileId: UUID) throws {
        var profiles = ProfileStore.shared.loadProfiles()
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else {
            throw ClaudeCodeError.noProfileCredentials
        }

        profiles[index].cliCredentialsJSON = nil
        profiles[index].hasValidOAuthCredentials = false
        ProfileStore.shared.saveProfiles(profiles)

        LoggingService.shared.log("Removed CLI credentials from profile: \(profileId)")
    }

    // MARK: - Access Token Extraction

    func extractAccessToken(from jsonData: String) -> String? {
        guard let data = jsonData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }
        return token
    }

    func extractSubscriptionInfo(from jsonData: String) -> (type: String, scopes: [String])? {
        guard let data = jsonData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any] else {
            return nil
        }

        let subType = oauth["subscriptionType"] as? String ?? "unknown"
        let scopes = oauth["scopes"] as? [String] ?? []

        return (subType, scopes)
    }

    /// Extracts the token expiry date from CLI credentials JSON
    /// Handles both seconds and milliseconds epoch formats
    func extractTokenExpiry(from jsonData: String) -> Date? {
        guard let data = jsonData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let expiresAt = oauth["expiresAt"] as? TimeInterval else {
            return nil
        }
        // Normalize milliseconds to seconds: ms epoch values are > 1e12
        let epoch = expiresAt > 1e12 ? expiresAt / 1000.0 : expiresAt
        return Date(timeIntervalSince1970: epoch)
    }

    /// Checks if the OAuth token in the credentials JSON is expired
    func isTokenExpired(_ jsonData: String) -> Bool {
        guard let expiryDate = extractTokenExpiry(from: jsonData) else {
            // No expiry info = assume valid
            return false
        }
        return Date() > expiryDate
    }

    // MARK: - Auto Re-sync Before Switching

    /// Re-syncs credentials from system Keychain before profile switching
    /// This ensures we always have the latest CLI login when switching profiles
    func resyncBeforeSwitching(for profileId: UUID) async throws {
        LoggingService.shared.log("Re-syncing CLI credentials before profile switch: \(profileId)")

        // Read fresh credentials from system (if user is logged in)
        guard let freshJSON = try await readSystemCredentials() else {
            // No credentials in system - user not logged into CLI anymore
            LoggingService.shared.log("No system credentials found - skipping re-sync")
            return
        }

        // Update profile's stored credentials with fresh ones
        var profiles = ProfileStore.shared.loadProfiles()
        guard let index = profiles.firstIndex(where: { $0.id == profileId }) else {
            return
        }

        profiles[index].cliCredentialsJSON = freshJSON
        profiles[index].hasValidOAuthCredentials = Profile.isValidOAuthJSON(freshJSON)
        profiles[index].cliAccountSyncedAt = Date()  // Update sync timestamp
        ProfileStore.shared.saveProfiles(profiles)

        LoggingService.shared.log("Re-synced CLI credentials from system and updated timestamp")
    }

    // MARK: - Private Methods

    /// Runs a throwing closure off the main actor to avoid blocking UI
    private func runOffMainActor<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try work()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Synchronous implementation of readSystemCredentials with timeout
    private func readSystemCredentialsSync() throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = [
            "find-generic-password",
            "-s", "Claude Code-credentials",
            "-a", NSUserName(),
            "-w"  // Print password only
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        try waitForProcess(process, timeout: Self.subprocessTimeout)

        let exitCode = process.terminationStatus

        if exitCode == 0 {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let value = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                throw ClaudeCodeError.invalidJSON
            }
            return value
        } else if exitCode == 44 {
            // Exit code 44 = item not found
            return nil
        } else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            LoggingService.shared.log("Failed to read keychain: \(errorString)")
            throw ClaudeCodeError.keychainReadFailed(status: OSStatus(exitCode))
        }
    }

    /// Synchronous implementation of writeSystemCredentials with timeout
    private func writeSystemCredentialsSync(_ jsonData: String) throws {
        LoggingService.shared.log("Writing credentials to keychain using security command")

        // First, delete existing item
        let deleteProcess = Process()
        deleteProcess.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        deleteProcess.arguments = [
            "delete-generic-password",
            "-s", "Claude Code-credentials",
            "-a", NSUserName()
        ]

        try deleteProcess.run()
        try waitForProcess(deleteProcess, timeout: Self.subprocessTimeout)

        let deleteExitCode = deleteProcess.terminationStatus
        if deleteExitCode == 0 {
            LoggingService.shared.log("Deleted existing keychain item")
        } else {
            LoggingService.shared.log("No existing keychain item to delete (or delete failed with code \(deleteExitCode))")
        }

        // Add new item using security command
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        addProcess.arguments = [
            "add-generic-password",
            "-s", "Claude Code-credentials",
            "-a", NSUserName(),
            "-w", jsonData,
            "-U"  // Update if exists
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        addProcess.standardOutput = outputPipe
        addProcess.standardError = errorPipe

        try addProcess.run()
        try waitForProcess(addProcess, timeout: Self.subprocessTimeout)

        let exitCode = addProcess.terminationStatus

        if exitCode == 0 {
            LoggingService.shared.log("Added Claude Code system credentials successfully using security command")
        } else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            LoggingService.shared.log("Failed to add credentials: \(errorString)")
            throw ClaudeCodeError.keychainWriteFailed(status: OSStatus(exitCode))
        }
    }

    /// Waits for a subprocess to exit within the given timeout.
    /// Terminates the process and throws `subprocessTimedOut` if the deadline is exceeded.
    private func waitForProcess(_ process: Process, timeout: TimeInterval) throws {
        let semaphore = DispatchSemaphore(value: 0)

        // Observe termination asynchronously so we can enforce a deadline
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        let result = semaphore.wait(timeout: .now() + timeout)
        if result == .timedOut {
            process.terminate()
            // Give it a brief moment to clean up, then force-kill if still running
            let cleanup = semaphore.wait(timeout: .now() + 1)
            if cleanup == .timedOut && process.isRunning {
                kill(process.processIdentifier, SIGKILL)
            }
            throw ClaudeCodeError.subprocessTimedOut(seconds: timeout)
        }
    }
}

// MARK: - ClaudeCodeError

enum ClaudeCodeError: LocalizedError {
    case noCredentialsFound
    case invalidJSON
    case keychainReadFailed(status: OSStatus)
    case keychainWriteFailed(status: OSStatus)
    case noProfileCredentials
    case subprocessTimedOut(seconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .noCredentialsFound:
            return "No Claude Code credentials found in system Keychain. Please log in to Claude Code first."
        case .invalidJSON:
            return "Claude Code credentials are corrupted or invalid."
        case .keychainReadFailed(let status):
            return "Failed to read credentials from system Keychain (status: \(status))."
        case .keychainWriteFailed(let status):
            return "Failed to write credentials to system Keychain (status: \(status))."
        case .noProfileCredentials:
            return "This profile has no synced CLI account."
        case .subprocessTimedOut(let seconds):
            return "Security subprocess timed out after \(Int(seconds)) seconds."
        }
    }
}
