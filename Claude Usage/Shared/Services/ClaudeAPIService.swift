import Foundation

/// Service for fetching usage data directly from Claude's API.
///
/// Explicitly `@MainActor`-isolated to document the concurrency contract:
/// all property access and method calls happen on the main actor. This was
/// previously inherited implicitly from `APIServiceProtocol`; the explicit
/// annotation prevents accidental isolation changes if the protocol evolves.
@MainActor
final class ClaudeAPIService: APIServiceProtocol {
    // MARK: - Types

    /// Backward-compatibility alias — callers may use either `AuthenticationType` or
    /// `ClaudeAPIService.AuthenticationType`; both resolve to the same top-level type.
    typealias AuthenticationType = Claude_Usage.AuthenticationType

    // MARK: - Properties

    private let sessionKeyPath: URL
    let sessionKeyValidator: SessionKeyValidator
    let baseURL = Constants.APIEndpoints.claudeBase
    let consoleBaseURL = Constants.APIEndpoints.consoleBase
    let session: URLSession

    // MARK: - Initialization

    init(
        sessionKeyPath: URL? = nil,
        sessionKeyValidator: SessionKeyValidator = SessionKeyValidator(),
        session: URLSession = .shared
    ) {
        // Default path: ~/.claude-session-key
        self.sessionKeyPath = sessionKeyPath ?? Constants.ClaudePaths.homeDirectory
            .appendingPathComponent(".claude-session-key")
        self.sessionKeyValidator = sessionKeyValidator
        self.session = session
    }

    // MARK: - Organization ID Caching

    /// Cache organization ID to reduce API calls
    private var cachedOrgId: String?
    private var cachedOrgIdSessionKey: String?

    /// Clears the cached organization ID (call when session key changes)
    func clearOrganizationIdCache() {
        cachedOrgId = nil
        cachedOrgIdSessionKey = nil
    }

    // MARK: - API Requests

    /// Fetches all organizations for the authenticated user
    /// - Parameter sessionKey: The claude.ai session key to authenticate with
    func fetchAllOrganizations(sessionKey: String) async throws -> [AccountInfo] {
        return try await ErrorRecovery.shared.executeWithRetry(maxAttempts: 3) {
            // Build URL safely
            let url: URL
            do {
                url = try URLBuilder(baseURL: self.baseURL)
                    .appendingPath("/organizations")
                    .build()
            } catch {
                throw AppError.wrap(error)
            }

            var request = URLRequest(url: url)
            request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.httpMethod = "GET"
            request.timeoutInterval = 30

            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await self.session.data(for: request)
            } catch {
                // Network errors
                let appError = AppError(
                    code: .networkGenericError,
                    message: "Failed to connect to Claude API",
                    technicalDetails: error.localizedDescription,
                    underlyingError: error,
                    isRecoverable: true,
                    recoverySuggestion: "Please check your internet connection and try again"
                )
                ErrorLogger.shared.log(appError)
                throw appError
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AppError(
                    code: .apiInvalidResponse,
                    message: "Invalid response from server",
                    isRecoverable: true
                )
            }

            switch httpResponse.statusCode {
            case 200:
                // Parse organizations array
                do {
                    let organizations = try JSONDecoder().decode([AccountInfo].self, from: data)
                    guard !organizations.isEmpty else {
                        throw AppError(
                            code: .apiParsingFailed,
                            message: "No organizations found",
                            technicalDetails: "Organizations array is empty",
                            isRecoverable: false,
                            recoverySuggestion: "Please ensure your Claude account has access to organizations"
                        )
                    }

                    // Log all available organizations for debugging
                    LoggingService.shared.logInfo("Found \(organizations.count) organization(s):")
                    for (index, org) in organizations.enumerated() {
                        LoggingService.shared.logInfo("  [\(index)] \(org.name) (ID: \(org.uuid))")
                    }

                    return organizations
                } catch {
                    let appError = AppError(
                        code: .apiParsingFailed,
                        message: "Failed to parse organizations",
                        technicalDetails: error.localizedDescription,
                        underlyingError: error,
                        isRecoverable: false
                    )
                    ErrorLogger.shared.log(appError)
                    throw appError
                }

            case 401, 403:
                throw AppError.apiUnauthorized()

            case 429:
                self.logRateLimitHeaders(from: httpResponse, context: "fetchAllOrganizations")
                let parsedRetryAfter = self.parseRetryAfter(from: httpResponse)
                throw AppError(
                    code: .apiRateLimited,
                    message: "Rate limited by Claude API",
                    technicalDetails: "Endpoint: /organizations\nRetry-After: \(parsedRetryAfter.map { "\($0)" } ?? "not set")",
                    isRecoverable: true,
                    recoverySuggestion: "Please wait a few minutes before trying again",
                    retryAfter: parsedRetryAfter
                )

            case 500...599:
                throw AppError.apiServerError(statusCode: httpResponse.statusCode)

            default:
                throw AppError(
                    code: .apiGenericError,
                    message: "Unexpected API response",
                    technicalDetails: "HTTP \(httpResponse.statusCode)",
                    isRecoverable: true
                )
            }
        }
    }

    // MARK: - Read-Only Testing

    /// Tests a session key without saving to Keychain
    /// Returns available organizations if successful
    func testSessionKey(_ key: String) async throws -> [AccountInfo] {
        // Validate using professional validator
        let validatedKey = try sessionKeyValidator.validate(key)

        // Fetch organizations using the test key (don't save it)
        let organizations = try await fetchAllOrganizations(sessionKey: validatedKey)

        LoggingService.shared.logInfo("Tested session key - found \(organizations.count) organization(s)")

        return organizations
    }

    /// Fetches the organization ID for the authenticated user
    /// Uses the provided stored org ID if available, otherwise fetches all orgs and auto-selects.
    /// Returns a tuple: the resolved org ID and whether it was newly fetched (so the caller can persist it).
    /// - Parameters:
    ///   - sessionKey: The session key for authentication
    ///   - storedOrgId: The previously stored organization ID, if any
    /// - Returns: A tuple of (orgId, isNewlyFetched) where isNewlyFetched indicates the caller should persist the org ID
    func fetchOrganizationId(sessionKey: String, storedOrgId: String? = nil) async throws -> (orgId: String, isNewlyFetched: Bool) {
        // Use stored org ID if available
        if let storedOrgId = storedOrgId {
            LoggingService.shared.logInfo("Using stored organization ID from profile: \(storedOrgId)")
            return (storedOrgId, false)
        }

        // No stored org ID - fetch all organizations
        LoggingService.shared.logInfo("No stored organization ID - fetching all organizations")
        let organizations = try await fetchAllOrganizations(sessionKey: sessionKey)

        // Auto-select organization (prefer first one for now - user can change later)
        guard let selectedOrg = organizations.first else {
            throw AppError(
                code: .apiParsingFailed,
                message: "No organizations found",
                technicalDetails: "Organizations array is empty after fetch",
                isRecoverable: false,
                recoverySuggestion: "Please ensure your Claude account has access to organizations"
            )
        }
        LoggingService.shared.logInfo("Auto-selected organization: \(selectedOrg.name) (ID: \(selectedOrg.uuid))")

        return (selectedOrg.uuid, true)
    }

    /// Fetches usage data for a specific profile using provided credentials
    /// - Parameters:
    ///   - sessionKey: The Claude.ai session key
    ///   - organizationId: The organization ID
    /// - Returns: ClaudeUsage data for the profile
    func fetchUsageData(sessionKey: String, organizationId: String) async throws -> ClaudeUsage {
        let usageData = try await performRequest(endpoint: "/organizations/\(organizationId)/usage", sessionKey: sessionKey)
        return try parseUsageResponse(usageData)
    }

    /// Fetches usage data using a CLI OAuth access token directly
    func fetchUsageData(oauthAccessToken: String) async throws -> ClaudeUsage {
        LoggingService.shared.log("ClaudeAPIService: Fetching usage via OAuth endpoint (explicit token)")

        guard let url = URL(string: Constants.APIEndpoints.oauthUsage) else {
            throw AppError(
                code: .urlMalformed,
                message: "Invalid OAuth usage endpoint",
                isRecoverable: false
            )
        }

        var request = buildAuthenticatedRequest(url: url, auth: .cliOAuth(oauthAccessToken))
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError(
                code: .apiInvalidResponse,
                message: "Invalid response from OAuth endpoint",
                isRecoverable: true
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw oauthError(statusCode: httpResponse.statusCode, data: data, context: "OAuth fetch failed", httpResponse: httpResponse)
        }

        return try parseUsageResponse(data)
    }

    /// Fetches usage data for a profile, trying CLI OAuth first then falling back to cookie session.
    ///
    /// This is the canonical fetch path — both `RefreshOrchestrator` and `AutoStartSessionService`
    /// should call this instead of implementing their own credential resolution.
    /// - Parameter profile: The profile whose credentials to use
    /// - Returns: Usage data for the profile
    func fetchUsage(for profile: Profile) async throws -> ClaudeUsage {
        // Try CLI OAuth first (auto-refreshing, most reliable)
        if let cliJSON = profile.cliCredentialsJSON,
           !ClaudeCodeSyncService.shared.isTokenExpired(cliJSON),
           let accessToken = ClaudeCodeSyncService.shared.extractAccessToken(from: cliJSON) {
            LoggingService.shared.log("Profile '\(profile.name)': Fetching via CLI OAuth")
            do {
                return try await fetchUsageData(oauthAccessToken: accessToken)
            } catch {
                LoggingService.shared.logError("Profile '\(profile.name)': CLI OAuth fetch failed, trying cookie fallback: \(error.localizedDescription)")
            }
        }

        // Fall back to cookie-based claude.ai session
        if let sessionKey = profile.claudeSessionKey,
           let orgId = profile.organizationId {
            LoggingService.shared.log("Profile '\(profile.name)': Fetching via cookie session")
            return try await fetchUsageData(sessionKey: sessionKey, organizationId: orgId)
        }

        throw AppError(
            code: .sessionKeyNotFound,
            message: "Missing credentials for profile '\(profile.name)'",
            isRecoverable: false
        )
    }

    /// Fetches usage data using a resolved authentication type.
    ///
    /// Coordinates between session-based, OAuth, and fallback auth flows.
    /// - Parameters:
    ///   - auth: The authentication method (resolved by the caller)
    ///   - storedOrgId: The stored organization ID for session-based auth (optional)
    ///   - checkOverageLimitEnabled: Whether to fetch overage limit data for session-based auth
    ///   - sessionKeyFallback: Optional session key for falling back on OAuth 429 errors
    /// - Returns: A tuple of (usage, newlyFetchedOrgId) where newlyFetchedOrgId is non-nil if the caller should persist it
    func fetchUsageData(
        auth: AuthenticationType,
        storedOrgId: String? = nil,
        checkOverageLimitEnabled: Bool = true,
        sessionKeyFallback: String? = nil
    ) async throws -> (usage: ClaudeUsage, newlyFetchedOrgId: String?) {
        switch auth {
        case .claudeAISession(let sessionKey):
            return try await fetchUsageDataViaSession(
                sessionKey: sessionKey,
                storedOrgId: storedOrgId,
                checkOverageLimitEnabled: checkOverageLimitEnabled
            )

        case .cliOAuth:
            return try await fetchUsageDataViaOAuth(
                auth: auth,
                storedOrgId: storedOrgId,
                sessionKeyFallback: sessionKeyFallback
            )

        case .consoleAPISession:
            throw AppError(
                code: .sessionKeyNotFound,
                message: "No valid credentials for usage data",
                technicalDetails: "Console API only provides billing data, not usage statistics",
                isRecoverable: true,
                recoverySuggestion: "Please add a claude.ai session key or sync your CLI account"
            )
        }
    }

    /// Fetches usage via the claude.ai session-key endpoint.
    ///
    /// Resolves the organization ID (using cached or freshly-fetched value), then
    /// fetches usage and optionally overage-limit data in parallel.
    private func fetchUsageDataViaSession(
        sessionKey: String,
        storedOrgId: String?,
        checkOverageLimitEnabled: Bool
    ) async throws -> (usage: ClaudeUsage, newlyFetchedOrgId: String?) {
        let (orgId, isNewlyFetched) = try await fetchOrganizationId(sessionKey: sessionKey, storedOrgId: storedOrgId)

        async let usageDataTask = performRequest(endpoint: "/organizations/\(orgId)/usage", sessionKey: sessionKey)

        async let overageDataTask: Data? = checkOverageLimitEnabled ? performRequest(endpoint: "/organizations/\(orgId)/overage_spend_limit", sessionKey: sessionKey) : nil

        let usageData = try await usageDataTask
        var claudeUsage = try parseUsageResponse(usageData)

        if checkOverageLimitEnabled,
           let data = try? await overageDataTask,
           let overage = try? JSONDecoder().decode(OverageSpendLimitResponse.self, from: data),
           overage.isEnabled == true {
            claudeUsage.costUsed = overage.usedCredits
            claudeUsage.costLimit = overage.monthlyCreditLimit
            claudeUsage.costCurrency = overage.currency
        }

        return (claudeUsage, isNewlyFetched ? orgId : nil)
    }

    /// Fetches usage via the CLI OAuth endpoint.
    ///
    /// On HTTP 429 (rate limit), falls back to the session-key endpoint if a
    /// valid `sessionKeyFallback` is available, since that endpoint has more
    /// lenient rate limits.
    private func fetchUsageDataViaOAuth(
        auth: AuthenticationType,
        storedOrgId: String?,
        sessionKeyFallback: String?
    ) async throws -> (usage: ClaudeUsage, newlyFetchedOrgId: String?) {
        LoggingService.shared.log("ClaudeAPIService: Fetching usage via OAuth endpoint")

        guard let url = URL(string: Constants.APIEndpoints.oauthUsage) else {
            throw AppError(
                code: .urlMalformed,
                message: "Invalid OAuth usage endpoint",
                isRecoverable: false
            )
        }

        var request = buildAuthenticatedRequest(url: url, auth: auth)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError(
                code: .apiInvalidResponse,
                message: "Invalid response from OAuth endpoint",
                isRecoverable: true
            )
        }

        guard httpResponse.statusCode == 200 else {
            if let result = try await fetchUsageDataWithSessionFallback(
                statusCode: httpResponse.statusCode,
                sessionKeyFallback: sessionKeyFallback,
                storedOrgId: storedOrgId
            ) {
                return result
            }
            throw oauthError(statusCode: httpResponse.statusCode, data: data, context: "OAuth authentication failed", httpResponse: httpResponse)
        }

        return (try parseUsageResponse(data), nil)
    }

    /// Falls back to session-key auth when OAuth returns 429.
    ///
    /// Returns `nil` when fallback is not applicable (non-429 status or no valid
    /// session key), signalling the caller to throw the original error.
    private func fetchUsageDataWithSessionFallback(
        statusCode: Int,
        sessionKeyFallback: String?,
        storedOrgId: String?
    ) async throws -> (usage: ClaudeUsage, newlyFetchedOrgId: String?)? {
        guard statusCode == 429,
              let sessionKey = sessionKeyFallback,
              (try? sessionKeyValidator.validate(sessionKey)) != nil else {
            return nil
        }

        LoggingService.shared.log("ClaudeAPIService: OAuth rate limited — falling back to claude.ai session endpoint")
        return try await fetchUsageDataViaSession(
            sessionKey: sessionKey,
            storedOrgId: storedOrgId,
            checkOverageLimitEnabled: false
        )
    }

    private func performRequest(endpoint: String, sessionKey: String) async throws -> Data {
        // Build URL safely
        let url = try URLBuilder(baseURL: baseURL)
            .appendingPath(endpoint)
            .build()

        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        LoggingService.shared.logAPIRequest(endpoint)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            // Network-level errors
            LoggingService.shared.logAPIError(endpoint, error: error)
            let appError = AppError(
                code: .networkGenericError,
                message: "Failed to connect to Claude API",
                technicalDetails: "Endpoint: \(endpoint)\nError: \(error.localizedDescription)",
                underlyingError: error,
                isRecoverable: true,
                recoverySuggestion: "Please check your internet connection and try again"
            )
            throw appError
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError(
                code: .apiInvalidResponse,
                message: "Invalid response from server",
                technicalDetails: "Endpoint: \(endpoint)",
                isRecoverable: true
            )
        }

        LoggingService.shared.logAPIResponse(endpoint, statusCode: httpResponse.statusCode)

        // Log raw response if debug logging is enabled
        if DataStore.shared.loadDebugAPILoggingEnabled() {
            if let responseString = String(data: data, encoding: .utf8) {
                // Truncate to first 500 chars to avoid huge logs
                let truncated = responseString.prefix(500)
                LoggingService.shared.logDebug("API Response [\(endpoint)]: \(truncated)...")
            }
        }

        switch httpResponse.statusCode {
        case 200:
            return data

        case 401, 403:
            // Include response body in error for debugging
            let responsePreview = String(data: data, encoding: .utf8)?.prefix(200) ?? "Unable to read response"
            throw AppError(
                code: .apiUnauthorized,
                message: "Unauthorized. Your session key may have expired.",
                technicalDetails: "Endpoint: \(endpoint)\nStatus: \(httpResponse.statusCode)\nResponse: \(responsePreview)",
                isRecoverable: true,
                recoverySuggestion: "Please update your session key in Settings"
            )

        case 429:
            logRateLimitHeaders(from: httpResponse, context: "performRequest(\(endpoint))")
            let parsedRetryAfter = parseRetryAfter(from: httpResponse)
            throw AppError(
                code: .apiRateLimited,
                message: "Rate limited by Claude API",
                technicalDetails: "Endpoint: \(endpoint)\nRetry-After: \(parsedRetryAfter.map { "\($0)" } ?? "not set")",
                isRecoverable: true,
                recoverySuggestion: "Please wait a few minutes before trying again",
                retryAfter: parsedRetryAfter
            )

        case 500...599:
            let responsePreview = String(data: data, encoding: .utf8)?.prefix(200) ?? "Unable to read response"
            throw AppError(
                code: .apiServerError,
                message: "Claude API server error",
                technicalDetails: "Endpoint: \(endpoint)\nStatus: \(httpResponse.statusCode)\nResponse: \(responsePreview)",
                isRecoverable: true,
                recoverySuggestion: "Please try again later"
            )

        default:
            let responsePreview = String(data: data, encoding: .utf8)?.prefix(200) ?? "Unable to read response"
            throw AppError(
                code: .apiGenericError,
                message: "Unexpected API response",
                technicalDetails: "Endpoint: \(endpoint)\nStatus: \(httpResponse.statusCode)\nResponse: \(responsePreview)",
                isRecoverable: true
            )
        }
    }

    /// Maps an HTTP status code from an OAuth endpoint to the appropriate AppError.
    /// Internal (not private) to allow unit testing via `@testable import`.
    func oauthError(statusCode: Int, data: Data, context: String, httpResponse: HTTPURLResponse? = nil) -> AppError {
        // Truncated to 200 chars as a privacy guard — OAuth responses may contain auth tokens.
        let responsePreview = String(data: data, encoding: .utf8)?.prefix(200) ?? "Unable to read response"

        // Log response body at error level so it persists in Release builds
        LoggingService.shared.logError("oauthError(\(context)): HTTP \(statusCode) — \(responsePreview)")

        let code: ErrorCode
        let qualifier: String
        let suggestion: String
        var parsedRetryAfter: TimeInterval? = nil
        switch statusCode {
        case 401, 403:
            code = .apiUnauthorized
            qualifier = "authentication failed"
            suggestion = "Please re-sync your CLI account in Settings."
        case 429:
            code = .apiRateLimited
            qualifier = "rate limited"
            suggestion = "Please wait a few minutes before trying again."
            if let httpResponse = httpResponse {
                logRateLimitHeaders(from: httpResponse, context: "oauthError(\(context))")
                parsedRetryAfter = parseRetryAfter(from: httpResponse)
            }
        case 500...599:
            code = .apiServerError
            qualifier = "server error"
            suggestion = "Claude's servers may be temporarily unavailable. Please try again later."
        default:
            code = .apiGenericError
            qualifier = "request failed"
            suggestion = "Please re-sync your CLI account in Settings."
        }
        return AppError(
            code: code,
            message: "\(context): \(qualifier)",
            technicalDetails: "Status: \(statusCode)\nResponse: \(responsePreview)",
            isRecoverable: true,
            recoverySuggestion: suggestion,
            retryAfter: parsedRetryAfter
        )
    }

    // MARK: - Session Initialization

    /// Sends a minimal message to Claude to initialize a new session
    /// Uses Claude 3.5 Haiku (cheapest model)
    /// Creates a temporary conversation that is deleted after initialization to avoid cluttering chat history
    /// - Parameters:
    ///   - sessionKey: The Claude.ai session key for authentication
    ///   - organizationId: The organization ID to create the conversation under
    /// - Returns: The raw SSE response data from the completion endpoint, or `nil` if unavailable.
    ///   The delete step is always attempted but non-fatal.
    @discardableResult
    func sendInitializationMessage(sessionKey: String, organizationId: String) async throws -> Data? {
        // Create a new conversation
        let conversationURL = try URLBuilder(baseURL: baseURL)
            .appendingPathComponents(["/organizations", organizationId, "/chat_conversations"])
            .build()

        var conversationRequest = URLRequest(url: conversationURL)
        conversationRequest.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        conversationRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        conversationRequest.httpMethod = "POST"

        let conversationBody: [String: Any] = [
            "uuid": UUID().uuidString.lowercased(),
            "name": ""
        ]
        conversationRequest.httpBody = try JSONSerialization.data(withJSONObject: conversationBody)

        let (conversationData, conversationResponse) = try await session.data(for: conversationRequest)

        guard let httpResponse = conversationResponse as? HTTPURLResponse else {
            throw AppError(
                code: .apiInvalidResponse,
                message: "Invalid response when creating conversation",
                isRecoverable: true
            )
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw AppError.apiServerError(statusCode: httpResponse.statusCode)
        }

        // Parse conversation UUID
        guard let json = try? JSONSerialization.jsonObject(with: conversationData) as? [String: Any],
              let conversationUUID = json["uuid"] as? String else {
            throw AppError(
                code: .apiInvalidResponse,
                message: "Failed to parse conversation UUID from response",
                isRecoverable: false
            )
        }

        // Send a minimal "Hi" message to initialize the session
        let messageURL = try URLBuilder(baseURL: baseURL)
            .appendingPathComponents(["/organizations", organizationId, "/chat_conversations", conversationUUID, "/completion"])
            .build()

        var messageRequest = URLRequest(url: messageURL)
        messageRequest.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        messageRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        messageRequest.httpMethod = "POST"

        let messageBody: [String: Any] = [
            "prompt": "Hi",
            "model": Constants.autoStartModel,
            "timezone": "UTC"
        ]
        messageRequest.httpBody = try JSONSerialization.data(withJSONObject: messageBody)

        let (messageData, messageResponse) = try await session.data(for: messageRequest)

        guard let messageHTTPResponse = messageResponse as? HTTPURLResponse else {
            throw AppError(
                code: .apiInvalidResponse,
                message: "Invalid response when sending initialization message",
                isRecoverable: true
            )
        }

        guard messageHTTPResponse.statusCode == 200 else {
            throw AppError.apiServerError(statusCode: messageHTTPResponse.statusCode)
        }

        // Delete the conversation to keep it out of chat history (incognito mode)
        let deleteURL = try URLBuilder(baseURL: baseURL)
            .appendingPathComponents(["/organizations", organizationId, "/chat_conversations", conversationUUID])
            .build()

        var deleteRequest = URLRequest(url: deleteURL)
        deleteRequest.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
        deleteRequest.httpMethod = "DELETE"

        // Attempt to delete, but don't fail if deletion fails
        // The session is already initialized, which is the primary goal
        do {
            _ = try await session.data(for: deleteRequest)
        } catch {
            // Silently ignore deletion errors - session is already initialized
        }

        return messageData
    }

}
