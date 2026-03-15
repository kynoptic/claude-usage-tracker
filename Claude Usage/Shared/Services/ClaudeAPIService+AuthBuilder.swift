import Foundation

// MARK: - Authenticated Request Building

extension ClaudeAPIService {

    /// Builds an authenticated URLRequest with the appropriate headers for the given auth type.
    ///
    /// This is a pure transformation: URL + auth → URLRequest. No network calls are made.
    func buildAuthenticatedRequest(url: URL, auth: AuthenticationType) -> URLRequest {
        var request = URLRequest(url: url)

        switch auth {
        case .claudeAISession(let sessionKey):
            // Existing claude.ai authentication
            request.setValue("sessionKey=\(sessionKey)", forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Accept")

        case .cliOAuth(let accessToken):
            // CLI OAuth authentication (requires specific headers)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(Constants.claudeCodeUserAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        case .consoleAPISession(let apiKey):
            // Console API authentication
            request.setValue("sessionKey=\(apiKey)", forHTTPHeaderField: "Cookie")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
        }

        return request
    }

    // MARK: - Rate-Limit Header Parsing

    /// Parses the Retry-After header value (integer seconds) from an HTTP 429 response.
    func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After"),
              let parsed = TimeInterval(value),
              parsed >= 0 else { return nil }
        return parsed  // Anthropic uses integer seconds
    }

    /// Logs all rate-limit-related headers from an HTTP 429 response for debugging.
    func logRateLimitHeaders(from response: HTTPURLResponse, context: String) {
        let headers = response.allHeaderFields
        var rateLimitHeaders: [String: String] = [:]
        for (key, value) in headers {
            let keyStr = "\(key)".lowercased()
            if keyStr.hasPrefix("anthropic-ratelimit") || keyStr == "retry-after" {
                rateLimitHeaders["\(key)"] = "\(value)"
            }
        }
        if rateLimitHeaders.isEmpty {
            LoggingService.shared.logWarning("429 [\(context)]: No rate-limit headers present")
        } else {
            LoggingService.shared.logWarning("429 [\(context)] rate-limit headers: \(rateLimitHeaders)")
        }
    }
}
