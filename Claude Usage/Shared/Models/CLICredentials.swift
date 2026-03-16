//
//  CLICredentials.swift
//  Claude Usage
//
//  Created by Claude Code on 2026-03-16.
//

import Foundation

/// Canonical parse point for OAuth credentials from the Claude Code CLI config JSON.
///
/// Consolidates the duplicate extraction logic that previously lived in both
/// `ClaudeCodeSyncService` and `Profile.isValidOAuthJSON`. All OAuth field
/// extraction now flows through this single value type.
///
/// Usage:
/// ```swift
/// if let creds = CLICredentials(jsonString: rawJSON) {
///     print(creds.accessToken)
///     print(creds.isExpired)
/// }
/// ```
struct CLICredentials: Equatable {

    // MARK: - Properties

    /// The OAuth access token (`claudeAiOauth.accessToken`)
    let accessToken: String

    /// Token expiry date, normalized from either seconds or milliseconds epoch.
    /// `nil` when the JSON contains no `expiresAt` field.
    let expiryDate: Date?

    /// Subscription type (`claudeAiOauth.subscriptionType`), defaults to `"unknown"`.
    let subscriptionType: String

    /// OAuth scopes (`claudeAiOauth.scopes`), defaults to empty array.
    let scopes: [String]

    // MARK: - Initialization

    /// Parses CLI credentials JSON and extracts OAuth fields.
    ///
    /// Returns `nil` when the JSON is malformed or missing the
    /// `claudeAiOauth.accessToken` path.
    init?(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }

        self.accessToken = token
        self.subscriptionType = oauth["subscriptionType"] as? String ?? "unknown"
        self.scopes = oauth["scopes"] as? [String] ?? []

        if let expiresAt = oauth["expiresAt"] as? TimeInterval {
            // Normalize milliseconds to seconds: ms epoch values are > 1e12
            let epoch = expiresAt > 1e12 ? expiresAt / 1000.0 : expiresAt
            self.expiryDate = Date(timeIntervalSince1970: epoch)
        } else {
            self.expiryDate = nil
        }
    }

    // MARK: - Computed Properties

    /// Whether the token has expired. Returns `false` when no expiry date is present.
    var isExpired: Bool {
        guard let expiryDate else { return false }
        return Date() > expiryDate
    }

    /// Whether the token is valid (present and not expired).
    var isValid: Bool {
        !isExpired
    }
}
