import XCTest
@testable import Claude_Usage

final class ClaudeCodeSyncServiceTests: XCTestCase {

    private let service = ClaudeCodeSyncService.shared

    // MARK: - Token Expiry Normalization (ms vs s)

    func testIsTokenExpired_SecondsEpoch_Expired() {
        // expiresAt in seconds, 1 hour ago → expired
        let past = Date().addingTimeInterval(-3600).timeIntervalSince1970
        let json = makeCredentialsJSON(expiresAt: past)
        XCTAssertTrue(service.isTokenExpired(json))
    }

    func testIsTokenExpired_SecondsEpoch_Valid() {
        // expiresAt in seconds, 1 hour from now → valid
        let future = Date().addingTimeInterval(3600).timeIntervalSince1970
        let json = makeCredentialsJSON(expiresAt: future)
        XCTAssertFalse(service.isTokenExpired(json))
    }

    func testIsTokenExpired_MillisecondsEpoch_Expired() {
        // expiresAt in milliseconds, 1 hour ago → should normalize and detect as expired
        let pastMs = Date().addingTimeInterval(-3600).timeIntervalSince1970 * 1000
        let json = makeCredentialsJSON(expiresAt: pastMs)
        XCTAssertTrue(service.isTokenExpired(json))
    }

    func testIsTokenExpired_MillisecondsEpoch_Valid() {
        // expiresAt in milliseconds, 1 hour from now → should normalize and detect as valid
        let futureMs = Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000
        let json = makeCredentialsJSON(expiresAt: futureMs)
        XCTAssertFalse(service.isTokenExpired(json))
    }

    func testIsTokenExpired_NoExpiresAt_AssumesValid() {
        let json = """
        {"claudeAiOauth":{"accessToken":"test"}}
        """
        XCTAssertFalse(service.isTokenExpired(json))
    }

    func testIsTokenExpired_InvalidJSON_AssumesValid() {
        XCTAssertFalse(service.isTokenExpired("not json"))
    }

    // MARK: - extractTokenExpiry normalization

    func testExtractTokenExpiry_NormalizesMilliseconds() {
        let nowSeconds = Date().timeIntervalSince1970
        let nowMs = nowSeconds * 1000
        let json = makeCredentialsJSON(expiresAt: nowMs)

        guard let expiry = service.extractTokenExpiry(from: json) else {
            XCTFail("Expected non-nil expiry")
            return
        }

        // Should be within 1 second of now (normalized from ms)
        XCTAssertEqual(expiry.timeIntervalSince1970, nowSeconds, accuracy: 1.0)
    }

    func testExtractTokenExpiry_PassthroughSeconds() {
        let nowSeconds = Date().timeIntervalSince1970
        let json = makeCredentialsJSON(expiresAt: nowSeconds)

        guard let expiry = service.extractTokenExpiry(from: json) else {
            XCTFail("Expected non-nil expiry")
            return
        }

        XCTAssertEqual(expiry.timeIntervalSince1970, nowSeconds, accuracy: 0.01)
    }

    // MARK: - extractAccessToken

    func testExtractAccessToken_ValidJSON_ReturnsToken() {
        let json = """
        {"claudeAiOauth":{"accessToken":"sk-ant-test123"}}
        """
        XCTAssertEqual(service.extractAccessToken(from: json), "sk-ant-test123")
    }

    func testExtractAccessToken_MissingToken_ReturnsNil() {
        let json = """
        {"claudeAiOauth":{"expiresAt":9999999999}}
        """
        XCTAssertNil(service.extractAccessToken(from: json))
    }

    func testExtractAccessToken_MissingOAuthKey_ReturnsNil() {
        let json = """
        {"other":{"accessToken":"sk-ant-test123"}}
        """
        XCTAssertNil(service.extractAccessToken(from: json))
    }

    func testExtractAccessToken_InvalidJSON_ReturnsNil() {
        XCTAssertNil(service.extractAccessToken(from: "not json"))
    }

    func testExtractAccessToken_EmptyJSON_ReturnsNil() {
        XCTAssertNil(service.extractAccessToken(from: "{}"))
    }

    // MARK: - extractSubscriptionInfo

    func testExtractSubscriptionInfo_ValidJSON_ReturnsTypeAndScopes() {
        let json = """
        {"claudeAiOauth":{"accessToken":"t","subscriptionType":"claude_pro","scopes":["read","write"]}}
        """
        guard let info = service.extractSubscriptionInfo(from: json) else {
            XCTFail("Expected non-nil subscription info")
            return
        }
        XCTAssertEqual(info.type, "claude_pro")
        XCTAssertEqual(info.scopes, ["read", "write"])
    }

    func testExtractSubscriptionInfo_MissingSubscriptionType_DefaultsToUnknown() {
        let json = """
        {"claudeAiOauth":{"accessToken":"t","scopes":["read"]}}
        """
        guard let info = service.extractSubscriptionInfo(from: json) else {
            XCTFail("Expected non-nil subscription info")
            return
        }
        XCTAssertEqual(info.type, "unknown")
    }

    func testExtractSubscriptionInfo_MissingScopes_DefaultsToEmptyArray() {
        let json = """
        {"claudeAiOauth":{"accessToken":"t","subscriptionType":"free"}}
        """
        guard let info = service.extractSubscriptionInfo(from: json) else {
            XCTFail("Expected non-nil subscription info")
            return
        }
        XCTAssertEqual(info.scopes, [])
    }

    func testExtractSubscriptionInfo_MissingOAuthKey_ReturnsNil() {
        let json = """
        {"other":{"subscriptionType":"pro"}}
        """
        XCTAssertNil(service.extractSubscriptionInfo(from: json))
    }

    func testExtractSubscriptionInfo_InvalidJSON_ReturnsNil() {
        XCTAssertNil(service.extractSubscriptionInfo(from: "not json"))
    }

    // MARK: - ClaudeCodeError localizedDescription

    func testClaudeCodeError_NoCredentialsFound_HasDescription() {
        let error = ClaudeCodeError.noCredentialsFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testClaudeCodeError_InvalidJSON_HasDescription() {
        let error = ClaudeCodeError.invalidJSON
        XCTAssertNotNil(error.errorDescription)
    }

    func testClaudeCodeError_KeychainReadFailed_IncludesStatus() {
        let status = errSecItemNotFound // -25300
        let error = ClaudeCodeError.keychainReadFailed(status: status)
        XCTAssertTrue(error.errorDescription?.contains("\(status)") ?? false)
    }

    func testClaudeCodeError_KeychainWriteFailed_IncludesStatus() {
        let status = errSecDuplicateItem // -25299
        let error = ClaudeCodeError.keychainWriteFailed(status: status)
        XCTAssertTrue(error.errorDescription?.contains("\(status)") ?? false)
    }

    func testClaudeCodeError_NoProfileCredentials_HasDescription() {
        let error = ClaudeCodeError.noProfileCredentials
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    // MARK: - Helpers

    private func makeCredentialsJSON(expiresAt: TimeInterval) -> String {
        """
        {"claudeAiOauth":{"accessToken":"test-token","expiresAt":\(expiresAt)}}
        """
    }
}
