import XCTest
@testable import Claude_Usage

/// Tests for `ClaudeAPIService.fetchUsageData(auth:...)` covering the three
/// primary fetch paths: OAuth, session key, and 429 fallback.
///
/// Uses a `URLProtocol`-backed mock `URLSession` injected into `ClaudeAPIService`
/// so that network calls never reach the live API.
@MainActor
final class ClaudeAPIServiceFetchTests: XCTestCase {

    // MARK: - Mock URLProtocol

    /// Intercepts all HTTP requests and returns a configurable stub response.
    private final class MockURLProtocol: URLProtocol {
        /// Map of URL path patterns to (statusCode, responseData, headers).
        /// Checked in order; first match wins.
        nonisolated(unsafe) static var handlers: [(pathContains: String, statusCode: Int, data: Data, headers: [String: String])] = []

        /// Fallback handler for unmatched requests.
        nonisolated(unsafe) static var fallbackStatusCode: Int = 200
        nonisolated(unsafe) static var fallbackData: Data = Data()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let url = request.url?.absoluteString ?? ""

            var matched = false
            for handler in MockURLProtocol.handlers {
                if url.contains(handler.pathContains) {
                    let response = HTTPURLResponse(
                        url: request.url!,
                        statusCode: handler.statusCode,
                        httpVersion: nil,
                        headerFields: handler.headers
                    )!
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                    client?.urlProtocol(self, didLoad: handler.data)
                    client?.urlProtocolDidFinishLoading(self)
                    matched = true
                    break
                }
            }

            if !matched {
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: MockURLProtocol.fallbackStatusCode,
                    httpVersion: nil,
                    headerFields: nil
                )!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: MockURLProtocol.fallbackData)
                client?.urlProtocolDidFinishLoading(self)
            }
        }

        override func stopLoading() {}
    }

    // MARK: - Properties

    private var service: ClaudeAPIService!
    private var mockSession: URLSession!

    // Valid session key that passes SessionKeyValidator
    private let validSessionKey = "sk-ant-sid01-test-key-abcdefghij"
    private let testOrgId = "org-test-12345"

    // MARK: - Test Fixtures

    /// Minimal valid usage JSON matching the API response structure.
    private var usageJSON: Data {
        Data("""
        {
            "five_hour": {
                "utilization": 42.5,
                "resets_at": "2026-03-14T18:00:00.000Z"
            },
            "seven_day": {
                "utilization": 15.0,
                "resets_at": "2026-03-17T11:59:00.000Z"
            },
            "seven_day_opus": {
                "utilization": 10.0
            },
            "seven_day_sonnet": {
                "utilization": 5.0
            }
        }
        """.utf8)
    }

    /// Organization list JSON.
    private var organizationsJSON: Data {
        Data("""
        [{"uuid": "\(testOrgId)", "name": "Test Org", "capabilities": ["chat"]}]
        """.utf8)
    }

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        MockURLProtocol.handlers = []
        MockURLProtocol.fallbackStatusCode = 200
        MockURLProtocol.fallbackData = usageJSON
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)
        service = ClaudeAPIService(session: mockSession)
    }

    override func tearDown() {
        MockURLProtocol.handlers = []
        mockSession = nil
        service = nil
        super.tearDown()
    }

    // MARK: - OAuth Path Tests

    /// OAuth path fetches from the `/api/oauth/usage` endpoint and parses usage.
    func testOAuthPathReturnsUsage() async throws {
        MockURLProtocol.handlers = [
            (pathContains: "oauth/usage", statusCode: 200, data: usageJSON, headers: [:])
        ]

        let (usage, newOrgId) = try await service.fetchUsageData(
            auth: .cliOAuth("test-access-token"),
            storedOrgId: nil,
            checkOverageLimitEnabled: false,
            sessionKeyFallback: nil
        )

        XCTAssertEqual(usage.sessionPercentage, 42.5)
        XCTAssertEqual(usage.weeklyPercentage, 15.0)
        XCTAssertEqual(usage.opusWeeklyPercentage, 10.0)
        XCTAssertEqual(usage.sonnetWeeklyPercentage, 5.0)
        XCTAssertNil(newOrgId, "OAuth path should not return an org ID")
    }

    /// OAuth path with a non-200 status (not 429) throws an error.
    func testOAuthPathThrowsOnNon200() async {
        MockURLProtocol.handlers = [
            (pathContains: "oauth/usage", statusCode: 401, data: Data("unauthorized".utf8), headers: [:])
        ]

        do {
            _ = try await service.fetchUsageData(
                auth: .cliOAuth("test-access-token"),
                storedOrgId: nil,
                checkOverageLimitEnabled: false,
                sessionKeyFallback: nil
            )
            XCTFail("Should have thrown for 401")
        } catch let error as AppError {
            XCTAssertEqual(error.code, .apiUnauthorized)
        } catch {
            XCTFail("Expected AppError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - Session Key Path Tests

    /// Session key path fetches from `/organizations/<orgId>/usage` and parses usage.
    func testSessionKeyPathReturnsUsage() async throws {
        MockURLProtocol.handlers = [
            (pathContains: "/usage", statusCode: 200, data: usageJSON, headers: [:])
        ]

        let (usage, newOrgId) = try await service.fetchUsageData(
            auth: .claudeAISession(validSessionKey),
            storedOrgId: testOrgId,
            checkOverageLimitEnabled: false,
            sessionKeyFallback: nil
        )

        XCTAssertEqual(usage.sessionPercentage, 42.5)
        XCTAssertEqual(usage.weeklyPercentage, 15.0)
        XCTAssertNil(newOrgId, "Should not return new org ID when storedOrgId is provided")
    }

    /// Session key path with stored org ID returns it as not newly fetched.
    func testSessionKeyPathUsesStoredOrgId() async throws {
        MockURLProtocol.handlers = [
            (pathContains: "/usage", statusCode: 200, data: usageJSON, headers: [:])
        ]

        let (_, newOrgId) = try await service.fetchUsageData(
            auth: .claudeAISession(validSessionKey),
            storedOrgId: testOrgId,
            checkOverageLimitEnabled: false,
            sessionKeyFallback: nil
        )

        XCTAssertNil(newOrgId, "Stored org ID should not be reported as newly fetched")
    }

    // MARK: - 429 Fallback Path Tests

    /// OAuth 429 with a valid session key fallback falls back to session key path.
    func testOAuth429FallsBackToSessionKey() async throws {
        MockURLProtocol.handlers = [
            (pathContains: "oauth/usage", statusCode: 429, data: Data("rate limited".utf8), headers: ["Retry-After": "60"]),
            (pathContains: "/usage", statusCode: 200, data: usageJSON, headers: [:])
        ]

        let (usage, _) = try await service.fetchUsageData(
            auth: .cliOAuth("test-access-token"),
            storedOrgId: testOrgId,
            checkOverageLimitEnabled: false,
            sessionKeyFallback: validSessionKey
        )

        XCTAssertEqual(usage.sessionPercentage, 42.5,
                       "Should successfully fall back to session key endpoint on OAuth 429")
    }

    /// OAuth 429 without a session key fallback throws rate-limited error.
    func testOAuth429WithoutFallbackThrows() async {
        MockURLProtocol.handlers = [
            (pathContains: "oauth/usage", statusCode: 429, data: Data("rate limited".utf8), headers: ["Retry-After": "60"])
        ]

        do {
            _ = try await service.fetchUsageData(
                auth: .cliOAuth("test-access-token"),
                storedOrgId: nil,
                checkOverageLimitEnabled: false,
                sessionKeyFallback: nil
            )
            XCTFail("Should have thrown for 429 without fallback")
        } catch let error as AppError {
            XCTAssertEqual(error.code, .apiRateLimited)
        } catch {
            XCTFail("Expected AppError, got \(type(of: error)): \(error)")
        }
    }

    /// OAuth 429 with an invalid session key fallback throws rate-limited error.
    func testOAuth429WithInvalidFallbackThrows() async {
        MockURLProtocol.handlers = [
            (pathContains: "oauth/usage", statusCode: 429, data: Data("rate limited".utf8), headers: [:])
        ]

        do {
            _ = try await service.fetchUsageData(
                auth: .cliOAuth("test-access-token"),
                storedOrgId: nil,
                checkOverageLimitEnabled: false,
                sessionKeyFallback: "invalid-key"  // Won't pass SessionKeyValidator
            )
            XCTFail("Should have thrown for 429 with invalid fallback key")
        } catch let error as AppError {
            XCTAssertEqual(error.code, .apiRateLimited)
        } catch {
            XCTFail("Expected AppError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - Console API Path Tests

    /// Console API auth type throws because it doesn't support usage data.
    func testConsoleAPIAuthThrows() async {
        do {
            _ = try await service.fetchUsageData(
                auth: .consoleAPISession("console-key"),
                storedOrgId: nil,
                checkOverageLimitEnabled: false,
                sessionKeyFallback: nil
            )
            XCTFail("Console API should not support usage data")
        } catch let error as AppError {
            XCTAssertEqual(error.code, .sessionKeyNotFound)
        } catch {
            XCTFail("Expected AppError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - Usage Parsing Tests

    /// Zero utilization values parse correctly.
    func testZeroUtilizationParses() async throws {
        let zeroJSON = Data("""
        {
            "five_hour": { "utilization": 0 },
            "seven_day": { "utilization": 0 }
        }
        """.utf8)

        MockURLProtocol.handlers = [
            (pathContains: "oauth/usage", statusCode: 200, data: zeroJSON, headers: [:])
        ]

        let (usage, _) = try await service.fetchUsageData(
            auth: .cliOAuth("test-token"),
            storedOrgId: nil,
            checkOverageLimitEnabled: false,
            sessionKeyFallback: nil
        )

        XCTAssertEqual(usage.sessionPercentage, 0.0)
        XCTAssertEqual(usage.weeklyPercentage, 0.0)
    }

    /// String utilization values (e.g., "42.5%") parse correctly.
    func testStringUtilizationParses() async throws {
        let stringJSON = Data("""
        {
            "five_hour": { "utilization": "75.5%" },
            "seven_day": { "utilization": "25" }
        }
        """.utf8)

        MockURLProtocol.handlers = [
            (pathContains: "oauth/usage", statusCode: 200, data: stringJSON, headers: [:])
        ]

        let (usage, _) = try await service.fetchUsageData(
            auth: .cliOAuth("test-token"),
            storedOrgId: nil,
            checkOverageLimitEnabled: false,
            sessionKeyFallback: nil
        )

        XCTAssertEqual(usage.sessionPercentage, 75.5)
        XCTAssertEqual(usage.weeklyPercentage, 25.0)
    }

    /// Invalid JSON throws a parsing error.
    func testInvalidJSONThrowsParsingError() async {
        MockURLProtocol.handlers = [
            (pathContains: "oauth/usage", statusCode: 200, data: Data("not json".utf8), headers: [:])
        ]

        do {
            _ = try await service.fetchUsageData(
                auth: .cliOAuth("test-token"),
                storedOrgId: nil,
                checkOverageLimitEnabled: false,
                sessionKeyFallback: nil
            )
            XCTFail("Should have thrown for invalid JSON")
        } catch let error as AppError {
            XCTAssertEqual(error.code, .apiParsingFailed)
        } catch {
            XCTFail("Expected AppError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - fetchOrganizationId Tests

    /// Returns stored org ID without making a network call.
    func testFetchOrganizationIdReturnsStoredId() async throws {
        let (orgId, isNew) = try await service.fetchOrganizationId(
            sessionKey: validSessionKey,
            storedOrgId: testOrgId
        )

        XCTAssertEqual(orgId, testOrgId)
        XCTAssertFalse(isNew)
    }

    /// Fetches org list when no stored ID is provided.
    func testFetchOrganizationIdFetchesWhenNoStoredId() async throws {
        MockURLProtocol.handlers = [
            (pathContains: "/organizations", statusCode: 200, data: organizationsJSON, headers: [:])
        ]

        let (orgId, isNew) = try await service.fetchOrganizationId(
            sessionKey: validSessionKey,
            storedOrgId: nil
        )

        XCTAssertEqual(orgId, testOrgId)
        XCTAssertTrue(isNew)
    }

    // MARK: - HTTP Error Status Tests

    /// 401 from session key endpoint throws unauthorized.
    func testSessionKeyPath401ThrowsUnauthorized() async {
        MockURLProtocol.handlers = [
            (pathContains: "/usage", statusCode: 401, data: Data("unauthorized".utf8), headers: [:])
        ]

        do {
            _ = try await service.fetchUsageData(
                auth: .claudeAISession(validSessionKey),
                storedOrgId: testOrgId,
                checkOverageLimitEnabled: false,
                sessionKeyFallback: nil
            )
            XCTFail("Should have thrown for 401")
        } catch let error as AppError {
            XCTAssertEqual(error.code, .apiUnauthorized)
        } catch {
            XCTFail("Expected AppError, got \(type(of: error)): \(error)")
        }
    }

    /// 500 from session key endpoint throws server error.
    func testSessionKeyPath500ThrowsServerError() async {
        MockURLProtocol.handlers = [
            (pathContains: "/usage", statusCode: 500, data: Data("server error".utf8), headers: [:])
        ]

        do {
            _ = try await service.fetchUsageData(
                auth: .claudeAISession(validSessionKey),
                storedOrgId: testOrgId,
                checkOverageLimitEnabled: false,
                sessionKeyFallback: nil
            )
            XCTFail("Should have thrown for 500")
        } catch let error as AppError {
            XCTAssertEqual(error.code, .apiServerError)
        } catch {
            XCTFail("Expected AppError, got \(type(of: error)): \(error)")
        }
    }

    // MARK: - URLSession Injection Tests

    /// Verifies that the injected URLSession is used: a separate service instance
    /// with its own mock session receives different stub data and parses it correctly.
    func testInjectedSessionIsUsed() async throws {
        // Configure a second mock session returning a distinct utilization value
        let altJSON = Data("""
        {
            "five_hour": { "utilization": 99.9 },
            "seven_day": { "utilization": 88.8 }
        }
        """.utf8)

        final class AltMockURLProtocol: URLProtocol {
            nonisolated(unsafe) static var data: Data = Data()
            override class func canInit(with request: URLRequest) -> Bool { true }
            override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
            override func startLoading() {
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: AltMockURLProtocol.data)
                client?.urlProtocolDidFinishLoading(self)
            }
            override func stopLoading() {}
        }

        AltMockURLProtocol.data = altJSON
        let altConfig = URLSessionConfiguration.ephemeral
        altConfig.protocolClasses = [AltMockURLProtocol.self]
        let altSession = URLSession(configuration: altConfig)
        let altService = ClaudeAPIService(session: altSession)

        let (usage, _) = try await altService.fetchUsageData(
            auth: .cliOAuth("test-token"),
            storedOrgId: nil,
            checkOverageLimitEnabled: false,
            sessionKeyFallback: nil
        )

        XCTAssertEqual(usage.sessionPercentage, 99.9,
                       "Service should use the injected session, not URLSession.shared")
        XCTAssertEqual(usage.weeklyPercentage, 88.8)
    }
}
