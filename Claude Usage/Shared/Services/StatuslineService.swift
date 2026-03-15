import Foundation

/// Service for managing Claude Code statusline configuration.
/// This service handles installation, configuration, and management of the statusline feature
/// for Claude Code terminal integration.
@MainActor
final class StatuslineService {
    static let shared = StatuslineService()

    private init() {}

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

        return """
#!/usr/bin/env swift

import Foundation
func readSessionKey() -> String? {
    // Session key injected from Keychain by Claude Usage app
    let injectedKey = "\(sessionKey)"
    let trimmedKey = injectedKey.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedKey.isEmpty ? nil : trimmedKey
}
func readOrganizationId() -> String? {
    // Organization ID injected from settings by Claude Usage app
    let injectedOrgId = "\(organizationId)"
    let trimmedOrgId = injectedOrgId.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedOrgId.isEmpty ? nil : trimmedOrgId
}
func fetchUsageData(sessionKey: String, orgId: String) async throws -> (utilization: Int, resetsAt: String?) {
    // Build URL safely - validate orgId doesn't contain path traversal
    guard !orgId.contains(".."), !orgId.contains("/") else {
        throw NSError(domain: "ClaudeAPI", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid organization ID"])
    }

    guard let url = URL(string: "https://claude.ai/api/organizations/\\(orgId)/usage") else {
        throw NSError(domain: "ClaudeAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }

    var request = URLRequest(url: url)
    request.setValue("sessionKey=\\(sessionKey)", forHTTPHeaderField: "Cookie")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.httpMethod = "GET"

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NSError(domain: "ClaudeAPI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch usage"])
    }

    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let fiveHour = json["five_hour"] as? [String: Any],
       let utilization = fiveHour["utilization"] as? Int {
        let resetsAt = fiveHour["resets_at"] as? String
        return (utilization, resetsAt)
    }

    throw NSError(domain: "ClaudeAPI", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
}

// Main execution
// Use Task to run async code, RunLoop keeps script alive until exit() is called
Task {
    guard let sessionKey = readSessionKey() else {
        print("ERROR:NO_SESSION_KEY")
        exit(1)
    }

    guard let orgId = readOrganizationId() else {
        print("ERROR:NO_ORG_CONFIGURED")
        exit(1)
    }

    do {
        let (utilization, resetsAt) = try await fetchUsageData(sessionKey: sessionKey, orgId: orgId)

        // Output format: UTILIZATION|RESETS_AT
        if let resets = resetsAt {
            print("\\(utilization)|\\(resets)")
        } else {
            print("\\(utilization)|")
        }
        exit(0)
    } catch {
        print("ERROR:\\(error.localizedDescription)")
        exit(1)
    }
}

// Keep script alive while async Task executes
RunLoop.main.run()
"""
    }

    /// Placeholder Swift script for when statusline is disabled
    /// This script returns an error indicating no session key is available
    private let placeholderSwiftScript = """
#!/usr/bin/env swift

import Foundation

// No session key available - statusline is disabled
print("ERROR:NO_SESSION_KEY")
exit(1)
"""

    /// Bash script that builds the statusline display.
    /// Installed to ~/.claude/statusline-command.sh and configured in Claude Code settings.json.
    /// Reads user preferences from ~/.claude/statusline-config.txt and displays selected components.
    /// `internal` for threshold-parity testing via `@testable import`.
    let bashScript = """
#!/bin/bash
config_file="$HOME/.claude/statusline-config.txt"
if [ -f "$config_file" ]; then
  source "$config_file"
  show_dir=$SHOW_DIRECTORY
  show_branch=$SHOW_BRANCH
  show_usage=$SHOW_USAGE
  show_bar=$SHOW_PROGRESS_BAR
  show_reset=$SHOW_RESET_TIME
  show_time_marker=$SHOW_TIME_MARKER
  show_grey_zone=${SHOW_GREY_ZONE:-0}
  grey_threshold=${GREY_THRESHOLD:-50}
else
  show_dir=1
  show_branch=1
  show_usage=1
  show_bar=1
  show_reset=1
  show_time_marker=1
  show_grey_zone=0
  grey_threshold=50
fi

input=$(cat)
current_dir_path=$(echo "$input" | grep -o '"current_dir":"[^"]*"' | sed 's/"current_dir":"//;s/"$//')
current_dir=$(basename "$current_dir_path")
BLUE=$'\\033[0;34m'
GREEN=$'\\033[0;32m'
GRAY=$'\\033[0;90m'
YELLOW=$'\\033[0;33m'
RESET=$'\\033[0m'

# 10-level ANSI palette — five zones use levels 3 / 5 / 7 / 10.
# grey/green (< 90%)  → LEVEL_3
# yellow     (90–110%) → LEVEL_5
# orange     (110–150%)→ LEVEL_7
# red        (> 150%) → LEVEL_10
LEVEL_1=$'\\033[38;5;22m'   # dark green
LEVEL_2=$'\\033[38;5;28m'   # soft green
LEVEL_3=$'\\033[38;5;34m'   # medium green
LEVEL_4=$'\\033[38;5;190m'  # yellow-green
LEVEL_5=$'\\033[38;5;220m'  # gold/amber
LEVEL_6=$'\\033[38;5;214m'  # orange-yellow
LEVEL_7=$'\\033[38;5;208m'  # orange
LEVEL_8=$'\\033[38;5;202m'  # orange-red
LEVEL_9=$'\\033[38;5;160m'  # deep red
LEVEL_10=$'\\033[38;5;196m' # bright red
SESSION_SECS=18000  # 5-hour session window (Constants.sessionWindow)

# Build components (without separators)
dir_text=""
if [ "$show_dir" = "1" ]; then
  dir_text="${BLUE}${current_dir}${RESET}"
fi

branch_text=""
if [ "$show_branch" = "1" ]; then
  if git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] && branch_text="${GREEN}⎇ ${branch}${RESET}"
  fi
fi

usage_text=""
if [ "$show_usage" = "1" ]; then
  swift_result=$(swift "$HOME/.claude/fetch-claude-usage.swift" 2>/dev/null)

  if [ $? -eq 0 ] && [ -n "$swift_result" ]; then
    utilization=$(echo "$swift_result" | cut -d'|' -f1)
    resets_at=$(echo "$swift_result" | cut -d'|' -f2)

    if [ -n "$utilization" ] && [ "$utilization" != "ERROR" ]; then
      # Compute elapsed session fraction (integer %, -1 = unavailable)
      # Used for both pacing-aware color selection and the time marker.
      elapsed_secs=-1
      elapsed_frac_pct=-1
      if [ -n "$resets_at" ] && [ "$resets_at" != "null" ]; then
        _marker_iso=$(echo "$resets_at" | sed 's/\\.[0-9]*Z$//')
        _marker_epoch=$(date -ju -f "%Y-%m-%dT%H:%M:%S" "$_marker_iso" "+%s" 2>/dev/null)
        if [ -n "$_marker_epoch" ]; then
          _now_epoch=$(date "+%s")
          if [ "$_marker_epoch" -gt "$_now_epoch" ]; then
            _remaining=$((_marker_epoch - _now_epoch))
            _elapsed=$(($SESSION_SECS - _remaining))
            if [ "$_elapsed" -ge 0 ] && [ "$_elapsed" -le "$SESSION_SECS" ]; then
              elapsed_secs="$_elapsed"
              elapsed_frac_pct=$(( (_elapsed * 100) / SESSION_SECS ))
            fi
          fi
        fi
      fi

      # Select color level. Mirrors UsageStatusCalculator.colorLevel (Swift) — keep in sync.
      # Five zones: grey/green → LEVEL_3, yellow → LEVEL_5, orange → LEVEL_7, red → LEVEL_10.
      # Projection fires whenever elapsed > 0; no minimum-elapsed guard.
      # 2>/dev/null guards against the -1 sentinel so non-numeric values fall through to else.
      if [ "$elapsed_frac_pct" -gt 0 ] 2>/dev/null; then
        # Pacing mode: projected = utilization * 100 / elapsed_frac_pct (integer %)
        projected=$(( (utilization * 100) / elapsed_frac_pct ))
        if   [ "$show_grey_zone" = "1" ] && [ "$projected" -lt $grey_threshold ]; then usage_color="$GRAY"     # grey (< threshold)
        elif [ "$projected" -lt 90  ]; then usage_color="$LEVEL_3"   # green (threshold–90%)
        elif [ "$projected" -lt 110 ]; then usage_color="$LEVEL_5"   # yellow (90–110%)
        elif [ "$projected" -le 150 ]; then usage_color="$LEVEL_7"   # orange (110–150%)
        else                                 usage_color="$LEVEL_10"  # red (>150%)
        fi
      else
        # Fallback: raw utilization when timing data unavailable.
        if   [ "$show_grey_zone" = "1" ] && [ "$utilization" -lt $grey_threshold ]; then usage_color="$GRAY"     # grey (< threshold)
        elif [ "$utilization" -lt 90  ]; then usage_color="$LEVEL_3"   # green (threshold–90%)
        elif [ "$utilization" -lt 110 ]; then usage_color="$LEVEL_5"   # yellow (90–110%)
        elif [ "$utilization" -le 150 ]; then usage_color="$LEVEL_7"   # orange (110–150%)
        else                                   usage_color="$LEVEL_10"  # red (>150%)
        fi
      fi

      if [ "$show_bar" = "1" ]; then
        if [ "$utilization" -eq 0 ]; then
          filled_blocks=0
        elif [ "$utilization" -eq 100 ]; then
          filled_blocks=10
        else
          filled_blocks=$(( (utilization * 10 + 50) / 100 ))
        fi
        [ "$filled_blocks" -lt 0 ] && filled_blocks=0
        [ "$filled_blocks" -gt 10 ] && filled_blocks=10
        empty_blocks=$((10 - filled_blocks))

        # Calculate time marker position using pre-computed elapsed_secs
        marker_pos=-1
        # 2>/dev/null: same sentinel guard as the color selection block above.
        if [ "$show_time_marker" = "1" ] && [ "$elapsed_secs" -ge 0 ] 2>/dev/null; then
          # Floor-divide: map 0..$SESSION_SECS elapsed → 0..10 bar positions
          marker_pos=$(( (elapsed_secs * 10) / SESSION_SECS ))
          [ "$marker_pos" -gt 10 ] && marker_pos=10
        fi

        # Build progress bar safely without seq
        progress_bar=" "
        i=0
        while [ $i -lt $filled_blocks ]; do
          if [ $i -eq $marker_pos ]; then
            progress_bar="${progress_bar}│"
          else
            progress_bar="${progress_bar}▓"
          fi
          i=$((i + 1))
        done
        i=0
        while [ $i -lt $empty_blocks ]; do
          pos=$((filled_blocks + i))
          if [ $pos -eq $marker_pos ]; then
            progress_bar="${progress_bar}│"
          else
            progress_bar="${progress_bar}░"
          fi
          i=$((i + 1))
        done
      else
        progress_bar=""
      fi

      reset_time_display=""
      if [ "$show_reset" = "1" ] && [ -n "$resets_at" ] && [ "$resets_at" != "null" ]; then
        iso_time=$(echo "$resets_at" | sed 's/\\.[0-9]*Z$//')
        epoch=$(date -ju -f "%Y-%m-%dT%H:%M:%S" "$iso_time" "+%s" 2>/dev/null)

        if [ -n "$epoch" ]; then
          # Detect system time format (12h vs 24h) from macOS locale preferences
          time_format=$(defaults read -g AppleICUForce24HourTime 2>/dev/null)
          if [ "$time_format" = "1" ]; then
            # 24-hour format
            reset_time=$(date -r "$epoch" "+%H:%M" 2>/dev/null)
          else
            # 12-hour format (default)
            reset_time=$(date -r "$epoch" "+%I:%M %p" 2>/dev/null)
          fi
          [ -n "$reset_time" ] && reset_time_display=$(printf " → Reset: %s" "$reset_time")
        fi
      fi

      usage_text="${usage_color}Usage: ${utilization}%${progress_bar}${reset_time_display}${RESET}"
    else
      usage_text="${YELLOW}Usage: ~${RESET}"
    fi
  else
    usage_text="${YELLOW}Usage: ~${RESET}"
  fi
fi

output=""
separator="${GRAY} │ ${RESET}"

[ -n "$dir_text" ] && output="${dir_text}"

if [ -n "$branch_text" ]; then
  [ -n "$output" ] && output="${output}${separator}"
  output="${output}${branch_text}"
fi

if [ -n "$usage_text" ]; then
  [ -n "$output" ] && output="${output}${separator}"
  output="${output}${usage_text}"
fi

printf "%s\\n" "$output"
"""

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
        let store = SharedDataStore.shared
        try updateConfiguration(
            showDirectory: store.loadStatuslineShowDirectory(),
            showBranch: store.loadStatuslineShowBranch(),
            showUsage: store.loadStatuslineShowUsage(),
            showProgressBar: store.loadStatuslineShowProgressBar(),
            showResetTime: store.loadStatuslineShowResetTime(),
            showTimeMarker: store.loadStatuslineShowTimeMarker(),
            showGreyZone: DataStore.shared.loadShowGreyZone(),
            greyThreshold: DataStore.shared.loadGreyThreshold()
        )
    }

    /// Updates the grey zone setting in the statusline config file if statusline is installed.
    /// Reads all other statusline settings from SharedDataStore to preserve them.
    func updateGreyZoneIfInstalled(_ show: Bool) throws {
        guard isInstalled else { return }
        let store = SharedDataStore.shared
        try updateConfiguration(
            showDirectory: store.loadStatuslineShowDirectory(),
            showBranch: store.loadStatuslineShowBranch(),
            showUsage: store.loadStatuslineShowUsage(),
            showProgressBar: store.loadStatuslineShowProgressBar(),
            showResetTime: store.loadStatuslineShowResetTime(),
            showTimeMarker: store.loadStatuslineShowTimeMarker(),
            showGreyZone: show,
            greyThreshold: DataStore.shared.loadGreyThreshold()
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
        }
    }
}
