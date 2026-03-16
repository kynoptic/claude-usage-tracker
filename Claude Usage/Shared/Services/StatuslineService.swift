import Foundation

/// Service for managing Claude Code statusline configuration.
/// This service handles installation, configuration, and management of the statusline feature
/// for Claude Code terminal integration.
@MainActor
final class StatuslineService {
    static let shared = StatuslineService()

    private init() {}

    // MARK: - Script Loading

    /// Loads a bundle resource file as a String.
    /// - Parameters:
    ///   - name: Resource file name (without extension).
    ///   - ext: File extension.
    /// - Returns: File contents as a String.
    private func loadBundleScript(name: String, withExtension ext: String) throws -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw StatuslineError.bundleResourceNotFound(name + "." + ext)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - Embedded Scripts

    /// Swift script that fetches Claude usage data from the API.
    /// Installed to ~/.claude/fetch-claude-usage.swift and executed by the bash statusline script.
    /// The session key and organization ID are injected into this script when statusline is enabled.

    /// Characters safe to embed verbatim in a Swift string literal.
    ///
    /// Covers the full alphabet of current Anthropic credential formats:
    /// - Session keys (`sk-ant-sid01-…`): alphanumeric + `-` + `_`
    /// - Organization IDs (UUID format): hex digits + `-`
    ///
    /// `.` and `:` are included as forward-compatibility for versioned key
    /// formats (e.g. `sk-ant-sid01-v2.0:token…`) that have appeared in
    /// Anthropic's tooling. Both are inert inside a Swift string literal.
    ///
    /// `+` and `=` are intentionally excluded. Anthropic uses URL-safe Base64
    /// (`-` / `_`) for session keys, never standard Base64 (`+` / `=`), so
    /// including them would widen the allow-list without any real-world benefit
    /// while creating risk if a key with those characters is somehow injected.
    /// Backslash, double-quote, `$`, `\n`, etc. would corrupt the generated
    /// Swift literal and are blocked here.
    private static let safeCredentialCharacters: CharacterSet = {
        // ASCII alphanumerics only — CharacterSet.alphanumerics includes Unicode
        // letters (e.g. é), which must not appear in embedded script literals.
        var cs = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        cs.insert(charactersIn: "-_.:") // hyphens, underscores, dots, colons
        return cs
    }()

    /// Returns true when every character in `value` is safe to embed as a
    /// Swift string literal without escaping or transformation.
    /// `internal` for testability.
    func isCredentialSafe(_ value: String) -> Bool {
        guard !value.isEmpty else { return false }
        return value.unicodeScalars.allSatisfy {
            StatuslineService.safeCredentialCharacters.contains($0)
        }
    }

    private func generateSwiftScript(sessionKey: String, organizationId: String) throws -> String {
        guard isCredentialSafe(sessionKey) else {
            throw StatuslineError.unsafeCredential("Session key contains characters that are not safe to embed in a script. Aborting write.")
        }
        guard isCredentialSafe(organizationId) else {
            throw StatuslineError.unsafeCredential("Organization ID contains characters that are not safe to embed in a script. Aborting write.")
        }

        let template = try loadBundleScript(name: "statusline-template", withExtension: "txt")
        return template
            .replacingOccurrences(of: "{{SESSION_KEY}}", with: sessionKey)
            .replacingOccurrences(of: "{{ORGANIZATION_ID}}", with: organizationId)
    }

    /// Placeholder Swift script for when statusline is disabled.
    /// Loaded from the bundle resource `statusline-placeholder.txt`.
    /// This script returns an error indicating no session key is available.
    private var placeholderSwiftScript: String {
        // swiftlint:disable:next force_try
        return (try? loadBundleScript(name: "statusline-placeholder", withExtension: "txt"))
            ?? "#!/usr/bin/env swift\nprint(\"ERROR:NO_SESSION_KEY\")\nexit(1)\n"
    }

    /// Bash script that builds the statusline display.
    /// Loaded from the bundle resource `statusline.sh` at runtime.
    /// Installed to ~/.claude/statusline-command.sh and configured in Claude Code settings.json.
    /// Reads user preferences from ~/.claude/statusline-config.txt and displays selected components.
    /// `internal` for threshold-parity testing via `@testable import`.
    var bashScript: String {
        get throws {
            try loadBundleScript(name: "statusline", withExtension: "sh")
        }
    }

    // MARK: - Installation

    /// Installs statusline scripts with session key injection from active profile
    /// - Parameter injectSessionKey: If true, injects the session key from active profile into the Swift script
    func installScripts(injectSessionKey: Bool = false) throws {
        let claudeDir = Constants.ClaudePaths.claudeDirectory

        if !FileManager.default.fileExists(atPath: claudeDir.path) {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        }

        // Install Swift script (with or without session key)
        let swiftDestination = claudeDir.appendingPathComponent("fetch-claude-usage.swift")
        let swiftScriptContent: String

        if injectSessionKey {
            // Load session key and org ID from active profile
            guard let activeProfile = ProfileManager.shared.activeProfile else {
                throw StatuslineError.noActiveProfile
            }

            guard let sessionKey = activeProfile.claudeSessionKey else {
                throw StatuslineError.sessionKeyNotFound
            }

            guard let organizationId = activeProfile.organizationId else {
                throw StatuslineError.organizationNotConfigured
            }

            do {
                swiftScriptContent = try generateSwiftScript(sessionKey: sessionKey, organizationId: organizationId)
                LoggingService.shared.log("Injected session key and org ID from profile '\(activeProfile.name)' into statusline")
            } catch {
                // Credential safety check failed — best-effort: install placeholder to
                // replace any stale credential script already on disk. Use try? so that a
                // secondary filesystem failure doesn't shadow the original safety error.
                LoggingService.shared.logWarning("Credential safety check failed; installing placeholder script: \(error.localizedDescription)")
                try? placeholderSwiftScript.write(to: swiftDestination, atomically: true, encoding: .utf8)
                try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: swiftDestination.path)
                throw error
            }
        } else {
            // Install placeholder script
            swiftScriptContent = placeholderSwiftScript
            LoggingService.shared.log("Installed placeholder statusline Swift script")
        }

        try swiftScriptContent.write(to: swiftDestination, atomically: true, encoding: .utf8)
        // 0o600: owner read/write only — the Swift script is passed as an argument to `swift`,
        // so it does not need execute permission. Restricting access limits exposure of the
        // embedded session key to the owning user process only.
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: swiftDestination.path
        )

        // Install bash script
        let bashDestination = claudeDir.appendingPathComponent("statusline-command.sh")
        try bashScript.write(to: bashDestination, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: bashDestination.path
        )
    }

    /// Removes the session key from the statusline Swift script
    func removeSessionKeyFromScript() throws {
        let swiftDestination = Constants.ClaudePaths.claudeDirectory
            .appendingPathComponent("fetch-claude-usage.swift")

        // Replace with placeholder script that returns error
        try placeholderSwiftScript.write(to: swiftDestination, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: swiftDestination.path
        )

        LoggingService.shared.log("Removed session key from statusline Swift script")
    }

    // MARK: - Configuration

    func updateConfiguration(
        showDirectory: Bool,
        showBranch: Bool,
        showUsage: Bool,
        showProgressBar: Bool,
        showResetTime: Bool,
        showTimeMarker: Bool = true,
        showGreyZone: Bool = false,
        greyThreshold: Double = Constants.greyThresholdDefault
    ) throws {
        let configPath = Constants.ClaudePaths.claudeDirectory
            .appendingPathComponent("statusline-config.txt")

        let config = """
SHOW_DIRECTORY=\(showDirectory ? "1" : "0")
SHOW_BRANCH=\(showBranch ? "1" : "0")
SHOW_USAGE=\(showUsage ? "1" : "0")
SHOW_PROGRESS_BAR=\(showProgressBar ? "1" : "0")
SHOW_RESET_TIME=\(showResetTime ? "1" : "0")
SHOW_TIME_MARKER=\(showTimeMarker ? "1" : "0")
SHOW_GREY_ZONE=\(showGreyZone ? "1" : "0")
GREY_THRESHOLD=\(Int(greyThreshold * 100))
"""

        try config.write(to: configPath, atomically: true, encoding: .utf8)
    }

    /// Enables or disables statusline in Claude Code settings.json
    /// When enabling, also injects the session key into the Swift script
    /// When disabling, removes the session key from the Swift script
    func updateClaudeCodeSettings(enabled: Bool) throws {
        let settingsPath = Constants.ClaudePaths.claudeDirectory
            .appendingPathComponent("settings.json")

        let homeDir = Constants.ClaudePaths.homeDirectory.path
        let commandPath = "\(homeDir)/.claude/statusline-command.sh"

        if enabled {
            // Install scripts with session key injection
            try installScripts(injectSessionKey: true)

            // Update settings.json
            var settings: [String: Any] = [:]

            if FileManager.default.fileExists(atPath: settingsPath.path) {
                let existingData = try Data(contentsOf: settingsPath)
                if let existing = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
                    settings = existing
                }
            }

            settings["statusLine"] = [
                "type": "command",
                "command": "bash \(commandPath)"
            ]

            let jsonData = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try jsonData.write(to: settingsPath)
        } else {
            // Remove session key from Swift script
            try removeSessionKeyFromScript()

            // Update settings.json
            if FileManager.default.fileExists(atPath: settingsPath.path) {
                let existingData = try Data(contentsOf: settingsPath)
                if var settings = try JSONSerialization.jsonObject(with: existingData) as? [String: Any] {
                    settings.removeValue(forKey: "statusLine")

                    let jsonData = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
                    try jsonData.write(to: settingsPath)
                }
            }
        }
    }

    // MARK: - Status

    var isInstalled: Bool {
        let swiftScript = Constants.ClaudePaths.claudeDirectory
            .appendingPathComponent("fetch-claude-usage.swift")

        let bashScript = Constants.ClaudePaths.claudeDirectory
            .appendingPathComponent("statusline-command.sh")

        return FileManager.default.fileExists(atPath: swiftScript.path) &&
               FileManager.default.fileExists(atPath: bashScript.path)
    }

    /// Updates scripts only if already installed (installation is optional).
    /// Also syncs the config file so UserDefaults settings (including greyThreshold) are reflected.
    func updateScriptsIfInstalled() throws {
        guard isInstalled else { return }
        try installScripts(injectSessionKey: true)
        let store = StatuslineConfigStore.shared
        try updateConfiguration(
            showDirectory: store.loadStatuslineShowDirectory(),
            showBranch: store.loadStatuslineShowBranch(),
            showUsage: store.loadStatuslineShowUsage(),
            showProgressBar: store.loadStatuslineShowProgressBar(),
            showResetTime: store.loadStatuslineShowResetTime(),
            showTimeMarker: store.loadStatuslineShowTimeMarker(),
            showGreyZone: AppearanceStore.shared.loadShowGreyZone(),
            greyThreshold: AppearanceStore.shared.loadGreyThreshold()
        )
    }

    /// Updates the grey zone setting in the statusline config file if statusline is installed.
    /// Reads all other statusline settings from DataStore to preserve them.
    func updateGreyZoneIfInstalled(_ show: Bool) throws {
        guard isInstalled else { return }
        let store = StatuslineConfigStore.shared
        try updateConfiguration(
            showDirectory: store.loadStatuslineShowDirectory(),
            showBranch: store.loadStatuslineShowBranch(),
            showUsage: store.loadStatuslineShowUsage(),
            showProgressBar: store.loadStatuslineShowProgressBar(),
            showResetTime: store.loadStatuslineShowResetTime(),
            showTimeMarker: store.loadStatuslineShowTimeMarker(),
            showGreyZone: show,
            greyThreshold: AppearanceStore.shared.loadGreyThreshold()
        )
    }

    /// Checks if active profile has a valid session key
    func hasValidSessionKey() -> Bool {
        guard let activeProfile = ProfileManager.shared.activeProfile,
              let key = activeProfile.claudeSessionKey else {
            return false
        }

        // Use professional validator for comprehensive validation
        let validator = SessionKeyValidator()
        return validator.isValid(key)
    }
}

// MARK: - StatuslineError

enum StatuslineError: Error, LocalizedError {
    case noActiveProfile
    case sessionKeyNotFound
    case organizationNotConfigured
    case unsafeCredential(String)
    case bundleResourceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noActiveProfile:
            return "No active profile found. Please create or select a profile first."
        case .sessionKeyNotFound:
            return "Session key not found in active profile. Please configure your session key first."
        case .organizationNotConfigured:
            return "Organization not configured in active profile. Please select an organization in the app settings."
        case .unsafeCredential(let message):
            return message
        case .bundleResourceNotFound(let filename):
            return "Required bundle resource not found: \(filename). The app bundle may be corrupted."
        }
    }
}
