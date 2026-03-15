//
//  ClaudeCodeSyncService.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-01-07.
//

import Foundation
import Security

/// Manages synchronization of Claude Code CLI credentials between system Keychain and profiles
///
/// ## Concurrency model
///
/// `ClaudeCodeSyncService` is **not** `@MainActor`. It is called from `@MainActor` contexts
/// (e.g. `ProfileManager`, `AppDelegate`) via `await`, which would ordinarily inherit the
/// caller's actor and run synchronous work on the main thread.
///
/// To prevent the blocking Security framework calls (`SecItemCopyMatching`, `SecItemUpdate`,
/// `SecItemAdd`) from executing on the main thread, the async public methods dispatch their
/// work onto a detached task. This keeps the main thread responsive during Keychain I/O.
///
/// The private `*Sync` helpers are marked `nonisolated` to make their actor-independence
/// explicit and to satisfy Swift's strict concurrency checks when called from a detached task.
final class ClaudeCodeSyncService {
    static let shared = ClaudeCodeSyncService()

    private static let keychainService = "Claude Code-credentials"
    private static var keychainAccount: String { NSUserName() }

    private init() {}

    // MARK: - System Keychain Access

    /// Reads Claude Code credentials from system Keychain using Security framework.
    /// Dispatches to a detached task so Security calls do not block the main thread.
    func readSystemCredentials() async throws -> String? {
        try await Task.detached(priority: .userInitiated) {
            try self.readSystemCredentialsSync()
        }.value
    }

    /// Writes Claude Code credentials to system Keychain using Security framework.
    /// Dispatches to a detached task so Security calls do not block the main thread.
    func writeSystemCredentials(_ jsonData: String) async throws {
        try await Task.detached(priority: .userInitiated) {
            try self.writeSystemCredentialsSync(jsonData)
        }.value
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

    /// Reads Claude Code credentials from the system Keychain using the Security framework.
    private nonisolated func readSystemCredentialsSync() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw ClaudeCodeError.invalidJSON
            }
            return value
        } else if status == errSecItemNotFound {
            return nil
        } else {
            LoggingService.shared.log("Failed to read keychain: OSStatus \(status)")
            throw ClaudeCodeError.keychainReadFailed(status: status)
        }
    }

    /// Writes Claude Code credentials to the system Keychain using the Security framework.
    /// Attempts an update first; falls back to add if the item does not yet exist.
    private nonisolated func writeSystemCredentialsSync(_ jsonData: String) throws {
        LoggingService.shared.log("Writing credentials to keychain using Security framework")

        guard let data = jsonData.data(using: .utf8) else {
            throw ClaudeCodeError.invalidJSON
        }

        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount
        ]

        let updateStatus = SecItemUpdate(searchQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)

        if updateStatus == errSecSuccess {
            LoggingService.shared.log("Updated Claude Code system credentials successfully")
            return
        }

        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: Self.keychainService,
                kSecAttrAccount as String: Self.keychainAccount,
                kSecValueData as String: data,
                kSecAttrSynchronizable as String: false
            ]

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            if addStatus == errSecSuccess {
                LoggingService.shared.log("Added Claude Code system credentials successfully")
            } else {
                LoggingService.shared.log("Failed to add credentials: OSStatus \(addStatus)")
                throw ClaudeCodeError.keychainWriteFailed(status: addStatus)
            }
        } else {
            LoggingService.shared.log("Failed to update credentials: OSStatus \(updateStatus)")
            throw ClaudeCodeError.keychainWriteFailed(status: updateStatus)
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
        }
    }
}
