import XCTest
@testable import Claude_Usage

/// Tests for `CLICredentials` — the canonical OAuth JSON extraction point.
///
/// Covers parsing, expiry normalization (seconds vs milliseconds),
/// validity checks, and edge cases (missing fields, malformed JSON).
final class CLICredentialsTests: XCTestCase {

    // MARK: - Parsing

    func testInit_validJSON_extractsAccessToken() {
        let json = """
        {"claudeAiOauth":{"accessToken":"sk-ant-test123"}}
        """
        let creds = CLICredentials(jsonString: json)
        XCTAssertEqual(creds?.accessToken, "sk-ant-test123")
    }

    func testInit_missingAccessToken_returnsNil() {
        let json = """
        {"claudeAiOauth":{"expiresAt":9999999999}}
        """
        XCTAssertNil(CLICredentials(jsonString: json))
    }

    func testInit_missingOAuthKey_returnsNil() {
        let json = """
        {"other":{"accessToken":"sk-ant-test123"}}
        """
        XCTAssertNil(CLICredentials(jsonString: json))
    }

    func testInit_invalidJSON_returnsNil() {
        XCTAssertNil(CLICredentials(jsonString: "not json"))
    }

    func testInit_emptyJSON_returnsNil() {
        XCTAssertNil(CLICredentials(jsonString: "{}"))
    }

    // MARK: - Expiry (seconds epoch)

    func testIsExpired_secondsEpoch_expired() {
        let past = Date().addingTimeInterval(-3600).timeIntervalSince1970
        let json = makeJSON(expiresAt: past)
        let creds = CLICredentials(jsonString: json)
        XCTAssertTrue(creds?.isExpired ?? false)
    }

    func testIsExpired_secondsEpoch_valid() {
        let future = Date().addingTimeInterval(3600).timeIntervalSince1970
        let json = makeJSON(expiresAt: future)
        let creds = CLICredentials(jsonString: json)
        XCTAssertFalse(creds?.isExpired ?? true)
    }

    // MARK: - Expiry (milliseconds epoch)

    func testIsExpired_millisecondsEpoch_expired() {
        let pastMs = Date().addingTimeInterval(-3600).timeIntervalSince1970 * 1000
        let json = makeJSON(expiresAt: pastMs)
        let creds = CLICredentials(jsonString: json)
        XCTAssertTrue(creds?.isExpired ?? false)
    }

    func testIsExpired_millisecondsEpoch_valid() {
        let futureMs = Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000
        let json = makeJSON(expiresAt: futureMs)
        let creds = CLICredentials(jsonString: json)
        XCTAssertFalse(creds?.isExpired ?? true)
    }

    // MARK: - Expiry normalization

    func testExpiryDate_normalizesMilliseconds() {
        let nowSeconds = Date().timeIntervalSince1970
        let nowMs = nowSeconds * 1000
        let json = makeJSON(expiresAt: nowMs)

        guard let creds = CLICredentials(jsonString: json),
              let expiry = creds.expiryDate else {
            XCTFail("Expected non-nil credentials and expiry")
            return
        }

        XCTAssertEqual(expiry.timeIntervalSince1970, nowSeconds, accuracy: 1.0)
    }

    func testExpiryDate_passthroughSeconds() {
        let nowSeconds = Date().timeIntervalSince1970
        let json = makeJSON(expiresAt: nowSeconds)

        guard let creds = CLICredentials(jsonString: json),
              let expiry = creds.expiryDate else {
            XCTFail("Expected non-nil credentials and expiry")
            return
        }

        XCTAssertEqual(expiry.timeIntervalSince1970, nowSeconds, accuracy: 0.01)
    }

    // MARK: - No expiry

    func testIsExpired_noExpiresAt_assumesValid() {
        let json = """
        {"claudeAiOauth":{"accessToken":"test"}}
        """
        let creds = CLICredentials(jsonString: json)
        XCTAssertNotNil(creds)
        XCTAssertFalse(creds!.isExpired)
        XCTAssertNil(creds!.expiryDate)
    }

    // MARK: - isValid

    func testIsValid_notExpired_returnsTrue() {
        let future = Date().addingTimeInterval(3600).timeIntervalSince1970
        let json = makeJSON(expiresAt: future)
        let creds = CLICredentials(jsonString: json)
        XCTAssertTrue(creds?.isValid ?? false)
    }

    func testIsValid_expired_returnsFalse() {
        let past = Date().addingTimeInterval(-3600).timeIntervalSince1970
        let json = makeJSON(expiresAt: past)
        let creds = CLICredentials(jsonString: json)
        XCTAssertFalse(creds?.isValid ?? true)
    }

    // MARK: - Subscription info

    func testSubscriptionInfo_validJSON_extractsTypeAndScopes() {
        let json = """
        {"claudeAiOauth":{"accessToken":"t","subscriptionType":"claude_pro","scopes":["read","write"]}}
        """
        let creds = CLICredentials(jsonString: json)
        XCTAssertEqual(creds?.subscriptionType, "claude_pro")
        XCTAssertEqual(creds?.scopes, ["read", "write"])
    }

    func testSubscriptionInfo_missingType_defaultsToUnknown() {
        let json = """
        {"claudeAiOauth":{"accessToken":"t","scopes":["read"]}}
        """
        let creds = CLICredentials(jsonString: json)
        XCTAssertEqual(creds?.subscriptionType, "unknown")
    }

    func testSubscriptionInfo_missingScopes_defaultsToEmpty() {
        let json = """
        {"claudeAiOauth":{"accessToken":"t","subscriptionType":"free"}}
        """
        let creds = CLICredentials(jsonString: json)
        XCTAssertEqual(creds?.scopes, [])
    }

    // MARK: - Equatable

    func testEquatable_sameValues_areEqual() {
        let json = """
        {"claudeAiOauth":{"accessToken":"tok","subscriptionType":"pro","scopes":["read"]}}
        """
        let a = CLICredentials(jsonString: json)
        let b = CLICredentials(jsonString: json)
        XCTAssertEqual(a, b)
    }

    // MARK: - Helpers

    private func makeJSON(expiresAt: TimeInterval) -> String {
        """
        {"claudeAiOauth":{"accessToken":"test-token","expiresAt":\(expiresAt)}}
        """
    }
}
