import XCTest
@testable import Claude_Usage

/// Tests for `ClaudeAPIService.oauthError(statusCode:data:context:)`.
///
/// Verifies that OAuth endpoint HTTP status codes are mapped to the correct
/// `ErrorCode` values — in particular that 429 produces `.apiRateLimited`
/// rather than `.apiUnauthorized` (the bug this branch fixes).
final class ClaudeAPIServiceOAuthErrorTests: XCTestCase {

    // MARK: - Properties

    private var service: ClaudeAPIService!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        service = ClaudeAPIService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Error Classification Tests

    /// A 429 from the OAuth endpoint must produce `.apiRateLimited`.
    func testOAuth429ProducesRateLimitedError() {
        let data = Data("{\"error\":\"rate_limited\"}".utf8)
        let error = service.oauthError(statusCode: 429, data: data, context: "OAuth fetch")

        XCTAssertEqual(error.code, .apiRateLimited,
                       "429 must map to .apiRateLimited, not .apiUnauthorized")
        XCTAssertTrue(error.message.contains("rate limited"),
                      "Message should include 'rate limited' qualifier")
        XCTAssertTrue(error.isRecoverable)
    }

    /// A 401 from the OAuth endpoint must produce `.apiUnauthorized`.
    func testOAuth401ProducesUnauthorizedError() {
        let data = Data("{\"error\":\"unauthorized\"}".utf8)
        let error = service.oauthError(statusCode: 401, data: data, context: "OAuth fetch")

        XCTAssertEqual(error.code, .apiUnauthorized)
        XCTAssertTrue(error.message.contains("authentication failed"))
    }

    /// A 403 from the OAuth endpoint must produce `.apiUnauthorized`.
    func testOAuth403ProducesUnauthorizedError() {
        let data = Data("{\"error\":\"forbidden\"}".utf8)
        let error = service.oauthError(statusCode: 403, data: data, context: "OAuth fetch")

        XCTAssertEqual(error.code, .apiUnauthorized)
        XCTAssertTrue(error.message.contains("authentication failed"))
    }

    /// A 5xx from the OAuth endpoint must produce `.apiServerError`.
    func testOAuth5xxProducesServerError() {
        let data = Data("bad gateway".utf8)
        let error = service.oauthError(statusCode: 502, data: data, context: "OAuth fetch")

        XCTAssertEqual(error.code, .apiServerError)
        XCTAssertTrue(error.message.contains("server error"))
    }

    /// An unexpected status code must produce `.apiGenericError`.
    func testOAuthUnexpectedStatusProducesGenericError() {
        let data = Data("not found".utf8)
        let error = service.oauthError(statusCode: 404, data: data, context: "OAuth fetch")

        XCTAssertEqual(error.code, .apiGenericError)
        XCTAssertTrue(error.message.contains("request failed"))
    }

    // MARK: - Message Format Tests

    /// The error message must include the context and a qualifier.
    func testErrorMessageIncludesContextAndQualifier() {
        let error = service.oauthError(statusCode: 429, data: Data(), context: "My context")

        XCTAssertEqual(error.message, "My context: rate limited")
    }

    // MARK: - Recovery Suggestion Consistency Tests

    /// All recovery suggestions must end with a period.
    func testAllRecoverySuggestionsEndWithPeriod() {
        let statusCodes = [401, 403, 429, 500, 502, 503, 404, 418]
        for code in statusCodes {
            let error = service.oauthError(statusCode: code, data: Data(), context: "test")
            XCTAssertTrue(error.recoverySuggestion?.hasSuffix(".") ?? false,
                          "Recovery suggestion for status \(code) should end with a period: \(error.recoverySuggestion ?? "nil")")
        }
    }
}
