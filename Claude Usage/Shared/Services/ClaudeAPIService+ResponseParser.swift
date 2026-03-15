import Foundation

// MARK: - Response Parsing

extension ClaudeAPIService {

    // Date.ISO8601FormatStyle is a value type (struct) — safe for concurrent access
    // from overlapping async tasks. ISO8601DateFormatter (a Formatter subclass) is not.
    static let iso8601ParseStrategy = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    /// Parses a raw API response body into a `ClaudeUsage` value.
    ///
    /// Handles Claude's nested JSON structure with five_hour, seven_day,
    /// seven_day_opus, and seven_day_sonnet utilization buckets.
    func parseUsageResponse(_ data: Data) throws -> ClaudeUsage {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Extract session usage (five_hour)
            var sessionPercentage = 0.0
            var sessionResetTime = Date().addingTimeInterval(5 * 3600)
            if let fiveHour = json["five_hour"] as? [String: Any] {
                if let utilization = fiveHour["utilization"] {
                    sessionPercentage = parseUtilization(utilization)
                }
                if let resetsAt = fiveHour["resets_at"] as? String {
                    sessionResetTime = (try? ClaudeAPIService.iso8601ParseStrategy.parse(resetsAt)) ?? sessionResetTime
                }
            }

            // Extract weekly usage (seven_day)
            var weeklyPercentage = 0.0
            var weeklyResetTime = Date().nextMonday1259pm()
            if let sevenDay = json["seven_day"] as? [String: Any] {
                if let utilization = sevenDay["utilization"] {
                    weeklyPercentage = parseUtilization(utilization)
                }
                if let resetsAt = sevenDay["resets_at"] as? String {
                    weeklyResetTime = (try? ClaudeAPIService.iso8601ParseStrategy.parse(resetsAt)) ?? weeklyResetTime
                }
            }

            // Extract Opus weekly usage (seven_day_opus)
            var opusPercentage = 0.0
            if let sevenDayOpus = json["seven_day_opus"] as? [String: Any] {
                if let utilization = sevenDayOpus["utilization"] {
                    opusPercentage = parseUtilization(utilization)
                }
            }

            // Extract Sonnet weekly usage (seven_day_sonnet)
            var sonnetPercentage = 0.0
            var sonnetResetTime: Date? = nil
            if let sevenDaySonnet = json["seven_day_sonnet"] as? [String: Any] {
                if let utilization = sevenDaySonnet["utilization"] {
                    sonnetPercentage = parseUtilization(utilization)
                }
                if let resetsAt = sevenDaySonnet["resets_at"] as? String {
                    sonnetResetTime = try? ClaudeAPIService.iso8601ParseStrategy.parse(resetsAt)
                }
            }

            // We don't know user's plan, so we use 0 for limits we can't determine
            let weeklyLimit = Constants.weeklyLimit

            // Calculate token counts from percentages (using weekly limit as reference)
            let sessionTokens = 0  // Can't calculate without knowing plan
            let sessionLimit = 0   // Unknown without plan
            let weeklyTokens = Int(Double(weeklyLimit) * (weeklyPercentage / 100.0))
            let opusTokens = Int(Double(weeklyLimit) * (opusPercentage / 100.0))
            let sonnetTokens = Int(Double(weeklyLimit) * (sonnetPercentage / 100.0))

            let usage = ClaudeUsage(
                sessionTokensUsed: sessionTokens,
                sessionLimit: sessionLimit,
                sessionPercentage: sessionPercentage,
                sessionResetTime: sessionResetTime,
                weeklyTokensUsed: weeklyTokens,
                weeklyLimit: weeklyLimit,
                weeklyPercentage: weeklyPercentage,
                weeklyResetTime: weeklyResetTime,
                opusWeeklyTokensUsed: opusTokens,
                opusWeeklyPercentage: opusPercentage,
                sonnetWeeklyTokensUsed: sonnetTokens,
                sonnetWeeklyPercentage: sonnetPercentage,
                sonnetWeeklyResetTime: sonnetResetTime,
                costUsed: nil,
                costLimit: nil,
                costCurrency: nil,
                lastUpdated: Date(),
                userTimezone: .current
            )

            return usage
        }

        // Log the actual response for debugging
        if DataStore.shared.loadDebugAPILoggingEnabled() {
            if let responseString = String(data: data, encoding: .utf8) {
                LoggingService.shared.logDebug("Failed to parse usage response: \(responseString)")
            }
        }

        throw AppError(
            code: .apiParsingFailed,
            message: "Failed to parse usage data",
            technicalDetails: "Unable to parse JSON response structure",
            isRecoverable: false,
            recoverySuggestion: "Please check the error log and report this issue"
        )
    }

    // MARK: - Parsing Helpers

    /// Robust utilization parser that handles Int, Double, or String types.
    /// - Parameter value: The utilization value from API (can be Int, Double, or String)
    /// - Returns: Parsed percentage as Double, or 0.0 if parsing fails
    func parseUtilization(_ value: Any) -> Double {
        // Try Int first (most common)
        if let intValue = value as? Int {
            return Double(intValue)
        }

        // Try Double
        if let doubleValue = value as? Double {
            return doubleValue
        }

        // Try String
        if let stringValue = value as? String {
            // Remove any percentage symbols or whitespace
            let cleaned = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "%", with: "")

            if let parsed = Double(cleaned) {
                return parsed
            }
        }

        // Log warning if we couldn't parse
        LoggingService.shared.logWarning("Failed to parse utilization value: \(value) (type: \(type(of: value)))")
        return 0.0
    }
}
