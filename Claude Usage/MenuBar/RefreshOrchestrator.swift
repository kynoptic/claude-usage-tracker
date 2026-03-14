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
    var usageSuccess: Bool { usage != nil }
}

/// Result of a multi-profile refresh cycle.
struct MultiProfileRefreshResult {
    var status: ClaudeStatus?
    /// Keyed by profile ID.
    var profileUsage: [UUID: ClaudeUsage] = [:]
    var hitRateLimit: Bool = false
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

    /// Fetches usage, status, and (optionally) API usage for the active profile.
    func refreshSingleProfile(
        apiSessionKey: String? = nil,
        apiOrganizationId: String? = nil
    ) async -> SingleProfileRefreshResult {
        var result = SingleProfileRefreshResult()

        // Fetch usage and status in parallel
        async let usageResult = apiService.fetchUsageData()
        async let statusResult = statusService.fetchStatus()

        do {
            result.usage = try await usageResult
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
                    result.hitRateLimit = true
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
}
