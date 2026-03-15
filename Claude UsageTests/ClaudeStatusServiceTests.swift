import XCTest
@testable import Claude_Usage

/// Tests for `ClaudeStatusService.fetchStatus()` indicator parsing and
/// the `ClaudeStatus` model's color mapping and static convenience values.
final class ClaudeStatusServiceTests: XCTestCase {

    // MARK: - Mock URLProtocol

    private final class MockURLProtocol: URLProtocol {
        nonisolated(unsafe) static var statusCode: Int = 200
        nonisolated(unsafe) static var data: Data = Data()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: MockURLProtocol.statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: MockURLProtocol.data)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    // MARK: - Properties

    private var service: ClaudeStatusService!

    // MARK: - Helpers

    private func statusJSON(indicator: String, description: String) -> Data {
        Data("""
        {"status": {"indicator": "\(indicator)", "description": "\(description)"}}
        """.utf8)
    }

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        service = ClaudeStatusService()
        MockURLProtocol.statusCode = 200
        MockURLProtocol.data = Data()
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        service = nil
        super.tearDown()
    }

    // MARK: - Indicator parsing

    func testFetchStatus_NoneIndicator_ReturnsNoneWithDescription() async throws {
        MockURLProtocol.data = statusJSON(indicator: "none", description: "All Systems Operational")

        let status = try await service.fetchStatus()

        XCTAssertEqual(status.indicator, .none)
        XCTAssertEqual(status.description, "All Systems Operational")
    }

    func testFetchStatus_MinorIndicator_ReturnsMinor() async throws {
        MockURLProtocol.data = statusJSON(indicator: "minor", description: "Minor Service Degradation")

        let status = try await service.fetchStatus()

        XCTAssertEqual(status.indicator, .minor)
    }

    func testFetchStatus_MajorIndicator_ReturnsMajor() async throws {
        MockURLProtocol.data = statusJSON(indicator: "major", description: "Major Service Outage")

        let status = try await service.fetchStatus()

        XCTAssertEqual(status.indicator, .major)
    }

    func testFetchStatus_CriticalIndicator_ReturnsCritical() async throws {
        MockURLProtocol.data = statusJSON(indicator: "critical", description: "Critical Service Outage")

        let status = try await service.fetchStatus()

        XCTAssertEqual(status.indicator, .critical)
    }

    func testFetchStatus_UnknownIndicatorString_DefaultsToUnknown() async throws {
        MockURLProtocol.data = statusJSON(indicator: "maintenance", description: "Under Maintenance")

        let status = try await service.fetchStatus()

        XCTAssertEqual(status.indicator, .unknown)
    }

    func testFetchStatus_EmptyIndicatorString_DefaultsToUnknown() async throws {
        MockURLProtocol.data = statusJSON(indicator: "", description: "Unknown")

        let status = try await service.fetchStatus()

        XCTAssertEqual(status.indicator, .unknown)
    }

    func testFetchStatus_InvalidJSON_Throws() async {
        MockURLProtocol.data = Data("not json".utf8)

        do {
            _ = try await service.fetchStatus()
            XCTFail("Should have thrown for invalid JSON")
        } catch {
            XCTAssertTrue(error is DecodingError,
                          "Invalid JSON should throw a DecodingError, got \(type(of: error))")
        }
    }

    func testFetchStatus_PreservesDescription() async throws {
        let expectedDescription = "Partial Outage Affecting API"
        MockURLProtocol.data = statusJSON(indicator: "minor", description: expectedDescription)

        let status = try await service.fetchStatus()

        XCTAssertEqual(status.description, expectedDescription)
    }

    // MARK: - ClaudeStatus.StatusIndicator color mapping

    func testStatusIndicatorColor_None_IsGreen() {
        XCTAssertEqual(ClaudeStatus.StatusIndicator.none.color, .green)
    }

    func testStatusIndicatorColor_Minor_IsYellow() {
        XCTAssertEqual(ClaudeStatus.StatusIndicator.minor.color, .yellow)
    }

    func testStatusIndicatorColor_Major_IsOrange() {
        XCTAssertEqual(ClaudeStatus.StatusIndicator.major.color, .orange)
    }

    func testStatusIndicatorColor_Critical_IsRed() {
        XCTAssertEqual(ClaudeStatus.StatusIndicator.critical.color, .red)
    }

    func testStatusIndicatorColor_Unknown_IsGray() {
        XCTAssertEqual(ClaudeStatus.StatusIndicator.unknown.color, .gray)
    }

    // MARK: - ClaudeStatus static convenience values

    func testStaticUnknown_HasUnknownIndicator() {
        XCTAssertEqual(ClaudeStatus.unknown.indicator, .unknown)
    }

    func testStaticUnknown_HasNonEmptyDescription() {
        XCTAssertFalse(ClaudeStatus.unknown.description.isEmpty)
    }

    func testStaticOperational_HasNoneIndicator() {
        XCTAssertEqual(ClaudeStatus.operational.indicator, .none)
    }

    func testStaticOperational_HasNonEmptyDescription() {
        XCTAssertFalse(ClaudeStatus.operational.description.isEmpty)
    }

    // MARK: - ClaudeStatus Equatable

    func testClaudeStatus_EqualWhenSameIndicatorAndDescription() {
        let a = ClaudeStatus(indicator: .none, description: "OK")
        let b = ClaudeStatus(indicator: .none, description: "OK")
        XCTAssertEqual(a, b)
    }

    func testClaudeStatus_NotEqualWhenDifferentIndicator() {
        let a = ClaudeStatus(indicator: .none, description: "OK")
        let b = ClaudeStatus(indicator: .minor, description: "OK")
        XCTAssertNotEqual(a, b)
    }

    func testClaudeStatus_NotEqualWhenDifferentDescription() {
        let a = ClaudeStatus(indicator: .minor, description: "Minor A")
        let b = ClaudeStatus(indicator: .minor, description: "Minor B")
        XCTAssertNotEqual(a, b)
    }
}
