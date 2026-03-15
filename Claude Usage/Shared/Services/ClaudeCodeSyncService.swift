//
//  ClaudeCodeSyncService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-07.
//

import Foundation
import Security

/// Manages synchronization of Claude Code CLI credentials between system Keychain and profiles
@MainActor
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

    /// Reads and validates CLI credentials from system Keychain.
    /// Returns the validated JSON string, or throws on missing/invalid credentials.
    func readAndValidateSystemCredentials() async throws -> String {
        guard let jsonData = try await readSystemCredentials() else {
            throw ClaudeCodeError.noCredentialsFound
        }

        // Validate JSON format
        guard let data = jsonData.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeCodeError.invalidJSON
        }

        return jsonData
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

    /// Reads fresh CLI credentials from system Keychain for re-sync.
    /// Returns the JSON string, or nil if no credentials are found in the system.
    func readFreshSystemCredentials() async throws -> String? {
        try await readSystemCredentials()
    }

    // MARK: - Private Methods

    /// Runs a throwing closure off the main actor to avoid blocking UI
    nonisolated private func runOffMainActor<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
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
    nonisolated private func readSystemCredentialsSync() throws -> String? {
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
    nonisolated private func writeSystemCredentialsSync(_ jsonData: String) throws {
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
    nonisolated private func waitForProcess(_ process: Process, timeout: TimeInterval) throws {
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
