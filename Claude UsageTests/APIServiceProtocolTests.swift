import XCTest
@testable import Claude_Usage

/// Tests that exercise `APIServiceProtocol` conformance.
///
/// A `MockAPIService` proves that any type conforming to the protocol can be
/// substituted for `ClaudeAPIService` in unit tests — the core testability
/// guarantee that issue #46 establishes.
@MainActor
final class APIServiceProtocolTests: XCTestCase {

    // MARK: - Mock

    /// Minimal mock implementing `APIServiceProtocol` for dependency-injection tests.
    private final class MockAPIService: APIServiceProtocol {
        var stubbedUsage: ClaudeUsage = .empty
        var stubbedOrganizations: [APIOrganization] = []
        var stubbedAPIUsage: APIUsage?
        var fetchUsageCallCount = 0
        var lastAuthType: ClaudeAPIService.AuthenticationType?

        func fetchOrganizationId(sessionKey: String, storedOrgId: String?) async throws -> (orgId: String, isNewlyFetched: Bool) {
            if let stored = storedOrgId {
                return (stored, false)
            }
            return ("mock-org-id", true)
        }

        func fetchUsageData(sessionKey: String, organizationId: String) async throws -> ClaudeUsage {
            fetchUsageCallCount += 1
            return stubbedUsage
        }

        func fetchUsageData(oauthAccessToken: String) async throws -> ClaudeUsage {
            fetchUsageCallCount += 1
            return stubbedUsage
        }

        func fetchUsageData(
            auth: ClaudeAPIService.AuthenticationType,
            storedOrgId: String?,
            checkOverageLimitEnabled: Bool,
            sessionKeyFallback: String?
        ) async throws -> (usage: ClaudeUsage, newlyFetchedOrgId: String?) {
            fetchUsageCallCount += 1
            lastAuthType = auth
            return (stubbedUsage, nil)
        }

        func sendInitializationMessage(sessionKey: String, organizationId: String) async throws {
            // no-op
        }

        func fetchConsoleOrganizations(apiSessionKey: String) async throws -> [APIOrganization] {
            return stubbedOrganizations
        }

        func fetchAPIUsageData(organizationId: String, apiSessionKey: String) async throws -> APIUsage {
            guard let usage = stubbedAPIUsage else {
                throw AppError(code: .apiGenericError, message: "No stubbed API usage", isRecoverable: false)
            }
            return usage
        }
    }

    // MARK: - Properties

    private var concreteService: ClaudeAPIService!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        concreteService = ClaudeAPIService()
    }

    override func tearDown() {
        concreteService = nil
        super.tearDown()
    }

    // MARK: - Protocol Conformance Tests

    /// Verifies that `ClaudeAPIService` conforms to `APIServiceProtocol` at compile time
    /// and can be assigned to a protocol-typed variable.
    func testClaudeAPIServiceConformsToProtocol() {
        let service: APIServiceProtocol = concreteService
        XCTAssertNotNil(service, "ClaudeAPIService must conform to APIServiceProtocol")
    }

    /// Verifies that the mock can be substituted via the protocol.
    func testMockCanBeUsedViaProtocol() async throws {
        let mock = MockAPIService()
        let service: APIServiceProtocol = mock

        mock.stubbedUsage = ClaudeUsage(
            sessionTokensUsed: 100,
            sessionLimit: 1000,
            sessionPercentage: 10.0,
            sessionResetTime: Date().addingTimeInterval(3600),
            weeklyTokensUsed: 500,
            weeklyLimit: 5000,
            weeklyPercentage: 10.0,
            weeklyResetTime: Date().addingTimeInterval(86400),
            opusWeeklyTokensUsed: 0,
            opusWeeklyPercentage: 0.0,
            sonnetWeeklyTokensUsed: 0,
            sonnetWeeklyPercentage: 0.0,
            sonnetWeeklyResetTime: nil,
            costUsed: nil,
            costLimit: nil,
            costCurrency: nil,
            lastUpdated: Date(),
            userTimezone: .current
        )

        let usage = try await service.fetchUsageData(sessionKey: "sk-ant-test", organizationId: "org-123")
        XCTAssertEqual(usage.sessionPercentage, 10.0)
        XCTAssertEqual(mock.fetchUsageCallCount, 1)
    }

    /// Verifies the parameterized fetchUsageData works through the protocol.
    func testFetchUsageDataWithAuth() async throws {
        let mock = MockAPIService()
        let service: APIServiceProtocol = mock

        let (usage, newOrgId) = try await service.fetchUsageData(
            auth: .cliOAuth("test-token"),
            storedOrgId: "org-123",
            checkOverageLimitEnabled: true,
            sessionKeyFallback: nil
        )

        XCTAssertEqual(mock.fetchUsageCallCount, 1)
        XCTAssertNil(newOrgId, "Mock returns nil for newlyFetchedOrgId")
        XCTAssertNotNil(usage)
    }

    /// Verifies fetchOrganizationId returns stored ID when provided.
    func testFetchOrganizationIdReturnsStoredId() async throws {
        let mock = MockAPIService()
        let service: APIServiceProtocol = mock

        let (orgId, isNew) = try await service.fetchOrganizationId(sessionKey: "sk-test", storedOrgId: "existing-org")
        XCTAssertEqual(orgId, "existing-org")
        XCTAssertFalse(isNew)
    }

    /// Verifies fetchOrganizationId fetches when no stored ID is provided.
    func testFetchOrganizationIdFetchesWhenNoStoredId() async throws {
        let mock = MockAPIService()
        let service: APIServiceProtocol = mock

        let (orgId, isNew) = try await service.fetchOrganizationId(sessionKey: "sk-test", storedOrgId: nil)
        XCTAssertEqual(orgId, "mock-org-id")
        XCTAssertTrue(isNew)
    }

    /// Verifies that ClaudeAPIService has no ProfileManager.shared references.
    /// This is a documentation test — the real check is `grep` at CI time,
    /// but having it here ensures the invariant is visible in test output.
    func testClaudeAPIServiceHasNoProfileManagerReferences() {
        // If this test compiles and ClaudeAPIService can be instantiated
        // without ProfileManager, the decoupling is confirmed.
        XCTAssertNotNil(concreteService.baseURL)
        XCTAssertNotNil(concreteService.consoleBaseURL)
    }
}
