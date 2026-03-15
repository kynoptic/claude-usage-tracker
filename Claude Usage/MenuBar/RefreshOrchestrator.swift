//
//  RefreshOrchestrator.swift
//  Claude Usage
//
//  Handles fetching usage/status data for single and multi-profile modes.
//

import Foundation

/// Result of a single-profile refresh cycle.
struct SingleProfileRefreshResult {
    var usage: ClaudeUsage?
    var usageError: AppError?
    var status: ClaudeStatus?
    var apiUsage: APIUsage?
    /// Non-nil when the orchestrator auto-discovered an org ID that the caller should persist.
    var newlyFetchedOrgId: String?
    var usageSuccess: Bool { usage != nil }
}

/// Result of a multi-profile refresh cycle.
struct MultiProfileRefreshResult {
    var status: ClaudeStatus?
    /// Keyed by profile ID.
    var profileUsage: [UUID: ClaudeUsage] = [:]
    /// True if at least one profile fetch was blocked by a 429 rate-limit response.
    var encounteredRateLimit: Bool = false
    var rateLimitRetryAfter: TimeInterval?
}

/// Orchestrates usage and status data fetching, independent of UI state.
///
/// `MenuBarManager` owns and drives this orchestrator; the orchestrator
/// returns structured results without mutating any published properties.
final class RefreshOrchestrator {
    private let apiService = ClaudeAPIService()
    private let statusService = ClaudeStatusService()

    // MARK: - Single Profile

    /// Fetches usage, status, and (optionally) API usage for the given profile.
    /// - Parameters:
    ///   - profile: The active profile to fetch usage for (provides credentials)
    ///   - apiSessionKey: Optional Console API session key
    ///   - apiOrganizationId: Optional Console API organization ID
    func refreshSingleProfile(
        profile: Profile,
        apiSessionKey: String? = nil,
        apiOrganizationId: String? = nil
    ) async -> SingleProfileRefreshResult {
        var result = SingleProfileRefreshResult()

        // Short-circuit if too many recent failures have opened the circuit breaker
        if ErrorRecovery.shared.isCircuitOpen(for: .api) {
            result.usageError = AppError(
                code: .apiServiceUnavailable,
                message: "Service temporarily unavailable — too many recent failures",
                isRecoverable: true
            )
            return result
        }

        // Resolve authentication from the profile
        let auth: AuthenticationType
        do {
            auth = try await resolveAuthentication(for: profile)
        } catch {
            let appError = AppError.wrap(error)
            ErrorLogger.shared.log(appError, severity: .error)
            ErrorRecovery.shared.recordFailure(for: .api)
            result.usageError = appError
            return result
        }

        // Fetch usage and status in parallel
        async let usageResult = apiService.fetchUsageData(
            auth: auth,
            storedOrgId: profile.organizationId,
            checkOverageLimitEnabled: profile.checkOverageLimitEnabled,
            sessionKeyFallback: profile.claudeSessionKey
        )
        async let statusResult = statusService.fetchStatus()

        do {
            let (usage, newOrgId) = try await usageResult
            result.usage = usage
            result.newlyFetchedOrgId = newOrgId
            ErrorRecovery.shared.recordSuccess(for: .api)
        } catch {
            let appError = AppError.wrap(error)
            ErrorLogger.shared.log(appError, severity: .error)
            ErrorRecovery.shared.recordFailure(for: .api)
            result.usageError = appError
        }

        do {
            result.status = try await statusResult
        } catch {
            let appError = AppError.wrap(error)
            ErrorLogger.shared.log(appError, severity: .info)
            LoggingService.shared.log("RefreshOrchestrator: Failed to fetch status - [\(appError.code.rawValue)] \(appError.message)")
        }

        // Fetch API usage if credentials provided
        if let apiSessionKey, let orgId = apiOrganizationId {
            do {
                result.apiUsage = try await apiService.fetchAPIUsageData(organizationId: orgId, apiSessionKey: apiSessionKey)
            } catch {
                let appError = AppError.wrap(error)
                ErrorLogger.shared.log(appError, severity: .info)
                LoggingService.shared.log("RefreshOrchestrator: Failed to fetch API usage - [\(appError.code.rawValue)] \(appError.message)")
            }
        }

        return result
    }

    // MARK: - Multi Profile

    /// Fetches usage for each selected profile, plus global status.
    func refreshMultipleProfiles(_ profiles: [Profile]) async -> MultiProfileRefreshResult {
        var result = MultiProfileRefreshResult()

        // Fetch status
        do {
            result.status = try await statusService.fetchStatus()
        } catch {
            let appError = AppError.wrap(error)
            LoggingService.shared.log("RefreshOrchestrator: Failed to fetch status - [\(appError.code.rawValue)] \(appError.message)")
        }

        // Fetch usage per profile
        for profile in profiles {
            LoggingService.shared.log("RefreshOrchestrator: Fetching usage for profile '\(profile.name)'")
            do {
                let usage = try await fetchUsageForProfile(profile)
                result.profileUsage[profile.id] = usage
                LoggingService.shared.log("RefreshOrchestrator: Fetched usage for '\(profile.name)' - session: \(usage.sessionPercentage)%")
            } catch {
                let appError = AppError.wrap(error)
                if appError.code == .apiRateLimited {
                    result.encounteredRateLimit = true
                    if let ra = appError.retryAfter {
                        result.rateLimitRetryAfter = max(ra, result.rateLimitRetryAfter ?? 0)
                    }
                }
                LoggingService.shared.logError("Failed to refresh profile '\(profile.name)': \(error.localizedDescription)")
            }
        }

        return result
    }

    // MARK: - Per-Profile Fetch

    /// Fetches usage data for a specific profile using its credentials.
    /// Tries CLI OAuth first, then falls back to cookie-based session.
    func fetchUsageForProfile(_ profile: Profile) async throws -> ClaudeUsage {
        // Try CLI OAuth first (auto-refreshing, most reliable)
        if let cliJSON = profile.cliCredentialsJSON,
           !ClaudeCodeSyncService.shared.isTokenExpired(cliJSON),
           let accessToken = ClaudeCodeSyncService.shared.extractAccessToken(from: cliJSON) {
            LoggingService.shared.log("Profile '\(profile.name)': Fetching via CLI OAuth")
            do {
                return try await apiService.fetchUsageData(oauthAccessToken: accessToken)
            } catch {
                LoggingService.shared.logError("Profile '\(profile.name)': CLI OAuth fetch failed, trying cookie fallback: \(error.localizedDescription)")
            }
        }

        // Fall back to cookie-based claude.ai session
        if let sessionKey = profile.claudeSessionKey,
           let orgId = profile.organizationId {
            LoggingService.shared.log("Profile '\(profile.name)': Fetching via cookie session")
            return try await apiService.fetchUsageData(sessionKey: sessionKey, organizationId: orgId)
        }

        throw AppError(
            code: .sessionKeyNotFound,
            message: "Missing credentials for profile '\(profile.name)'",
            isRecoverable: false
        )
    }

    // MARK: - Authentication Resolution

    /// Resolves the best available authentication method for a profile.
    /// Priority: 1) CLI OAuth (auto-refreshing) -> 2) system Keychain CLI OAuth -> 3) claude.ai session
    private func resolveAuthentication(for profile: Profile) async throws -> AuthenticationType {
        // Try saved CLI OAuth token first (auto-refreshing, most reliable)
        if let cliJSON = profile.cliCredentialsJSON {
            if !ClaudeCodeSyncService.shared.isTokenExpired(cliJSON),
               let accessToken = ClaudeCodeSyncService.shared.extractAccessToken(from: cliJSON) {
                LoggingService.shared.log("RefreshOrchestrator: Using saved CLI OAuth token")
                return .cliOAuth(accessToken)
            } else {
                LoggingService.shared.log("RefreshOrchestrator: Saved CLI OAuth token is expired or invalid")
            }
        }

        // Fall back to reading CLI credentials directly from system Keychain
        do {
            if let systemCredentials = try await ClaudeCodeSyncService.shared.readSystemCredentials() {
                LoggingService.shared.log("RefreshOrchestrator: Found CLI credentials in system Keychain")

                if ClaudeCodeSyncService.shared.isTokenExpired(systemCredentials) {
                    LoggingService.shared.log("RefreshOrchestrator: System Keychain CLI token is expired")
                } else if let accessToken = ClaudeCodeSyncService.shared.extractAccessToken(from: systemCredentials) {
                    LoggingService.shared.log("RefreshOrchestrator: Using CLI credentials from system Keychain")
                    return .cliOAuth(accessToken)
                } else {
                    LoggingService.shared.log("RefreshOrchestrator: Could not extract access token from system Keychain credentials")
                }
            } else {
                LoggingService.shared.log("RefreshOrchestrator: No CLI credentials found in system Keychain")
            }
        } catch {
            LoggingService.shared.log("RefreshOrchestrator: Could not read system CLI credentials: \(error.localizedDescription)")
        }

        // Fall back to claude.ai session key
        if let sessionKey = profile.claudeSessionKey {
            do {
                let validatedKey = try apiService.sessionKeyValidator.validate(sessionKey)
                LoggingService.shared.log("RefreshOrchestrator: Falling back to claude.ai session key")
                return .claudeAISession(validatedKey)
            } catch {
                LoggingService.shared.logError("RefreshOrchestrator: claude.ai session key validation failed: \(error.localizedDescription)")
            }
        }

        LoggingService.shared.logError("RefreshOrchestrator: No valid credentials for usage data")
        throw AppError.sessionKeyNotFound()
    }
}
