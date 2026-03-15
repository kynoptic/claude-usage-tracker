import XCTest
@testable import Claude_Usage

/// Tests for `FormatterHelper` and `StatuslineError`.
final class FormatterHelperTests: XCTestCase {

    // MARK: - FormatterHelper.timeUntilReset

    func testTimeUntilReset_FutureDate_ReturnsNonEmptyString() {
        let future = Date().addingTimeInterval(3600)
        let result = FormatterHelper.timeUntilReset(from: future)
        XCTAssertFalse(result.isEmpty, "timeUntilReset should return a non-empty string for a future date")
    }

    func testTimeUntilReset_PastDate_ReturnsNonEmptyString() {
        let past = Date().addingTimeInterval(-3600)
        let result = FormatterHelper.timeUntilReset(from: past)
        XCTAssertFalse(result.isEmpty, "timeUntilReset should return a non-empty string for a past date")
    }

    func testTimeUntilReset_NearFuture_ContainsSomeTimeReference() {
        // A date 30 seconds in the future should produce a short relative string
        let nearFuture = Date().addingTimeInterval(30)
        let result = FormatterHelper.timeUntilReset(from: nearFuture)
        XCTAssertFalse(result.isEmpty)
    }

    func testTimeUntilReset_FarFuture_ReturnsString() {
        let farFuture = Date().addingTimeInterval(7 * 24 * 3600) // 1 week
        let result = FormatterHelper.timeUntilReset(from: farFuture)
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - StatuslineError descriptions

    func testStatuslineError_NoActiveProfile_HasDescription() {
        let error = StatuslineError.noActiveProfile
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testStatuslineError_SessionKeyNotFound_HasDescription() {
        let error = StatuslineError.sessionKeyNotFound
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testStatuslineError_OrganizationNotConfigured_HasDescription() {
        let error = StatuslineError.organizationNotConfigured
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testStatuslineError_UnsafeCredential_IncludesProvidedMessage() {
        let message = "Session key contains forbidden characters"
        let error = StatuslineError.unsafeCredential(message)
        XCTAssertEqual(error.errorDescription, message)
    }

    func testStatuslineError_AllCases_HaveDistinctDescriptions() {
        let errors: [StatuslineError] = [
            .noActiveProfile,
            .sessionKeyNotFound,
            .organizationNotConfigured,
            .unsafeCredential("test message")
        ]
        let descriptions = errors.compactMap { $0.errorDescription }
        let unique = Set(descriptions)
        XCTAssertEqual(unique.count, descriptions.count,
                       "Every StatuslineError case should have a distinct description")
    }
}
