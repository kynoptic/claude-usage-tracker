import XCTest
@testable import Claude_Usage

/// Tests for `ClaudeAPIService.parseRetryAfter(from:)` and the
/// Retry-After propagation through `oauthError`.
@MainActor
final class RetryAfterParsingTests: XCTestCase {

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

    // MARK: - Helpers

    /// Creates an `HTTPURLResponse` with the given headers.
    private func makeResponse(headers: [String: String] = [:], statusCode: Int = 429) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.claude.ai/test")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
    }

    // MARK: - parseRetryAfter Tests

    func testParseRetryAfterWithValidIntegerSeconds() {
        let response = makeResponse(headers: ["Retry-After": "60"])
        let result = service.parseRetryAfter(from: response)

        XCTAssertEqual(result, 60.0, "Should parse integer seconds from Retry-After header")
    }

    func testParseRetryAfterWithZero() {
        let response = makeResponse(headers: ["Retry-After": "0"])
        let result = service.parseRetryAfter(from: response)

        XCTAssertEqual(result, 0.0, "Should parse zero Retry-After value")
    }

    func testParseRetryAfterWithMissingHeader() {
        let response = makeResponse(headers: [:])
        let result = service.parseRetryAfter(from: response)

        XCTAssertNil(result, "Should return nil when Retry-After header is absent")
    }

    func testParseRetryAfterWithNonNumericValue() {
        // RFC 7231 also allows HTTP-date format; we only support integer seconds
        let response = makeResponse(headers: ["Retry-After": "Thu, 01 Jan 2099 00:00:00 GMT"])
        let result = service.parseRetryAfter(from: response)

        XCTAssertNil(result, "Should return nil for non-numeric Retry-After values")
    }

    func testParseRetryAfterWithNegativeValue() {
        let response = makeResponse(headers: ["Retry-After": "-5"])
        let result = service.parseRetryAfter(from: response)

        XCTAssertNil(result, "Should return nil for negative Retry-After values")
    }

    func testParseRetryAfterWithLargeValue() {
        let response = makeResponse(headers: ["Retry-After": "3600"])
        let result = service.parseRetryAfter(from: response)

        XCTAssertEqual(result, 3600.0, "Should parse large Retry-After values")
    }

    // MARK: - oauthError Retry-After Propagation

    func testOAuthError429WithRetryAfterHeader() {
        let response = makeResponse(headers: ["Retry-After": "90"])
        let data = Data("{\"error\":\"rate_limited\"}".utf8)

        let error = service.oauthError(statusCode: 429, data: data, context: "test", httpResponse: response)

        XCTAssertEqual(error.code, .apiRateLimited)
        XCTAssertEqual(error.retryAfter, 90.0, "429 oauthError should propagate Retry-After value")
    }

    func testOAuthError429WithoutRetryAfterHeader() {
        let response = makeResponse(headers: [:])
        let data = Data("{\"error\":\"rate_limited\"}".utf8)

        let error = service.oauthError(statusCode: 429, data: data, context: "test", httpResponse: response)

        XCTAssertEqual(error.code, .apiRateLimited)
        XCTAssertNil(error.retryAfter, "429 oauthError without Retry-After header should have nil retryAfter")
    }

    func testOAuthError429WithoutHTTPResponse() {
        let data = Data("{\"error\":\"rate_limited\"}".utf8)

        let error = service.oauthError(statusCode: 429, data: data, context: "test")

        XCTAssertEqual(error.code, .apiRateLimited)
        XCTAssertNil(error.retryAfter, "429 oauthError without HTTPURLResponse should have nil retryAfter")
    }

    func testOAuthErrorNon429DoesNotSetRetryAfter() {
        let response = makeResponse(headers: ["Retry-After": "60"], statusCode: 503)
        let data = Data("server error".utf8)

        let error = service.oauthError(statusCode: 503, data: data, context: "test", httpResponse: response)

        XCTAssertEqual(error.code, .apiServerError)
        XCTAssertNil(error.retryAfter, "Non-429 errors should not set retryAfter even if header is present")
    }
}
