//
//  KeychainService.swift
//  Claude Usage
//
//  Created by Claude Code on 2025-12-28.
//

import Foundation
import Security

/// Service for secure storage and retrieval of sensitive data using macOS Keychain
@MainActor
final class KeychainService {
    static let shared = KeychainService()

    private init() {}

    /// Keychain item identifiers
    enum KeychainKey: String {
        case apiSessionKey = "com.claudeusagetracker.api-session-key"
        case claudeSessionKey = "com.claudeusagetracker.claude-session-key"

        var service: String {
            return rawValue
        }

        var account: String {
            return "session-key"
        }

        /// Human-readable label shown in Keychain Access.app and system prompts.
        var label: String {
            switch self {
            case .apiSessionKey:
                return "Claude Usage Tracker — API Console Key"
            case .claudeSessionKey:
                return "Claude Usage Tracker — Claude.ai Session Key"
            }
        }

        /// Description shown in the macOS keychain access dialog explaining
        /// what this credential is used for.
        var itemDescription: String {
            switch self {
            case .apiSessionKey:
                return "Authenticates with the Anthropic API Console to monitor credit usage."
            case .claudeSessionKey:
                return "Authenticates with Claude.ai to monitor session and weekly usage limits."
            }
        }
    }

    // MARK: - Public Methods

    /// Saves a string value to the Keychain
    /// - Parameters:
    ///   - value: The string value to save
    ///   - key: The keychain key identifier
    /// - Throws: KeychainError if save fails
    func save(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        // First, try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            LoggingService.shared.log("Keychain: Updated \(key.service)")
            return
        }

        // If update fails because item doesn't exist, add new item
        if updateStatus == errSecItemNotFound {
            // Create access control that doesn't require password
            var accessControlError: Unmanaged<CFError>?
            guard let accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleWhenUnlocked,
                [],
                &accessControlError
            ) else {
                if let error = accessControlError?.takeRetainedValue() {
                    LoggingService.shared.log("Failed to create access control: \(error)")
                }
                throw KeychainError.saveFailed(status: errSecParam)
            }

            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: key.service,
                kSecAttrAccount as String: key.account,
                kSecAttrLabel as String: key.label,
                kSecAttrDescription as String: key.itemDescription,
                kSecValueData as String: data,
                kSecAttrAccessControl as String: accessControl,
                kSecAttrSynchronizable as String: false
            ]

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            if addStatus == errSecSuccess {
                LoggingService.shared.log("Keychain: Added \(key.service)")
                return
            } else {
                throw KeychainError.saveFailed(status: addStatus)
            }
        } else {
            throw KeychainError.saveFailed(status: updateStatus)
        }
    }

    /// Loads a string value from the Keychain
    /// - Parameter key: The keychain key identifier
    /// - Returns: The stored string value, or nil if not found
    /// - Throws: KeychainError if load fails (other than item not found)
    func load(for key: KeychainKey) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            LoggingService.shared.log("Keychain: Loaded \(key.service)")
            return value
        } else if status == errSecItemNotFound {
            LoggingService.shared.log("Keychain: Item not found \(key.service)")
            return nil
        } else {
            throw KeychainError.loadFailed(status: status)
        }
    }

    /// Deletes a value from the Keychain
    /// - Parameter key: The keychain key identifier
    /// - Throws: KeychainError if delete fails (ignores item not found)
    func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess {
            LoggingService.shared.log("Keychain: Deleted \(key.service)")
        } else if status == errSecItemNotFound {
            // Item not found is not an error for delete
            LoggingService.shared.log("Keychain: Item not found for deletion \(key.service)")
        } else {
            throw KeychainError.deleteFailed(status: status)
        }
    }

    /// Checks if a value exists in the Keychain
    /// - Parameter key: The keychain key identifier
    /// - Returns: true if the item exists, false otherwise
    func exists(for key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Per-Profile Credential Methods (ADR-008)

    /// Credential types stored per-profile in the Keychain.
    /// Each type maps to a distinct `kSecAttrService`; `kSecAttrAccount` is the profile UUID string.
    enum PerProfileCredentialType: String, CaseIterable {
        case claudeSessionKey   = "com.claudeusagetracker.profile.claudeSessionKey"
        case organizationId     = "com.claudeusagetracker.profile.organizationId"
        case apiSessionKey      = "com.claudeusagetracker.profile.apiSessionKey"
        case apiOrganizationId  = "com.claudeusagetracker.profile.apiOrganizationId"
        case cliCredentialsJSON = "com.claudeusagetracker.profile.cliCredentialsJSON"

        /// The `kSecAttrService` value for this credential type.
        var service: String { rawValue }

        /// Human-readable label for Keychain Access.app and system prompts.
        var label: String {
            switch self {
            case .claudeSessionKey:
                return "Claude Usage Tracker — Claude.ai Session Key"
            case .organizationId:
                return "Claude Usage Tracker — Organization ID"
            case .apiSessionKey:
                return "Claude Usage Tracker — API Console Key"
            case .apiOrganizationId:
                return "Claude Usage Tracker — API Organization ID"
            case .cliCredentialsJSON:
                return "Claude Usage Tracker — CLI Credentials"
            }
        }

        /// Description shown in macOS keychain access dialogs.
        var itemDescription: String {
            switch self {
            case .claudeSessionKey:
                return "Authenticates with Claude.ai to monitor session and weekly usage limits."
            case .organizationId:
                return "Identifies your Claude.ai organization for usage tracking."
            case .apiSessionKey:
                return "Authenticates with the Anthropic API Console to monitor credit usage."
            case .apiOrganizationId:
                return "Identifies your Anthropic API organization for credit tracking."
            case .cliCredentialsJSON:
                return "OAuth credentials synced from Claude Code CLI for usage monitoring."
            }
        }
    }

    /// Saves a per-profile credential to the Keychain.
    /// - Parameters:
    ///   - value: The string value to store.
    ///   - profileId: The UUID of the profile that owns this credential.
    ///   - credentialType: The kind of credential being stored.
    /// - Throws: `KeychainError` if the save fails.
    func savePerProfile(_ value: String,
                        profileId: UUID,
                        credentialType: PerProfileCredentialType) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }

        let service = credentialType.service
        let account = profileId.uuidString

        // Attempt update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecSuccess {
            LoggingService.shared.log("Keychain: Updated per-profile \(credentialType) for \(profileId)")
            return
        }

        if updateStatus == errSecItemNotFound {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrLabel as String: credentialType.label,
                kSecAttrDescription as String: credentialType.itemDescription,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
                kSecAttrSynchronizable as String: false
            ]

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess {
                LoggingService.shared.log("Keychain: Added per-profile \(credentialType) for \(profileId)")
                return
            } else {
                throw KeychainError.saveFailed(status: addStatus)
            }
        } else {
            throw KeychainError.saveFailed(status: updateStatus)
        }
    }

    /// Loads a per-profile credential from the Keychain.
    /// - Parameters:
    ///   - profileId: The UUID of the profile that owns this credential.
    ///   - credentialType: The kind of credential to retrieve.
    /// - Returns: The stored string, or `nil` if not found.
    /// - Throws: `KeychainError` if the load fails (other than item not found).
    func loadPerProfile(profileId: UUID,
                        credentialType: PerProfileCredentialType) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credentialType.service,
            kSecAttrAccount as String: profileId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess {
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return value
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw KeychainError.loadFailed(status: status)
        }
    }

    /// Deletes a single per-profile credential from the Keychain.
    /// - Parameters:
    ///   - profileId: The UUID of the profile that owns this credential.
    ///   - credentialType: The kind of credential to delete.
    /// - Throws: `KeychainError` if the delete fails (ignores item not found).
    func deletePerProfile(profileId: UUID,
                          credentialType: PerProfileCredentialType) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credentialType.service,
            kSecAttrAccount as String: profileId.uuidString
        ]

        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            return
        }
        throw KeychainError.deleteFailed(status: status)
    }

    /// Deletes all per-profile credential types for a given profile.
    /// Called by `ProfileManager.deleteProfile(_:)` to prevent orphaned Keychain items.
    /// - Parameter profileId: The profile whose credentials should be erased.
    func deleteCredentials(for profileId: UUID) {
        for type_ in PerProfileCredentialType.allCases {
            do {
                try deletePerProfile(profileId: profileId, credentialType: type_)
            } catch {
                LoggingService.shared.logError(
                    "Keychain: Failed to delete \(type_) for \(profileId) (non-fatal)",
                    error: error
                )
            }
        }
        LoggingService.shared.log("Keychain: Deleted all credentials for profile \(profileId)")
    }

}

// MARK: - KeychainError

enum KeychainError: Error, LocalizedError {
    case invalidData
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid data format for Keychain storage"
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))"
        case .loadFailed(let status):
            return "Failed to load from Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))"
        }
    }
}
