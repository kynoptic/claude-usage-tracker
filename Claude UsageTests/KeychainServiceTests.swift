import XCTest
import Security
@testable import Claude_Usage

/// Tests for `KeychainService` store/retrieve/delete/exists operations.
///
/// Uses `InMemoryKeychainBackend` to avoid macOS Keychain access prompts,
/// allowing tests to run unsigned and headlessly in CI.
@MainActor
final class KeychainServiceTests: XCTestCase {

    // MARK: - Properties

    private var mockBackend: InMemoryKeychainBackend!
    private var service: KeychainService!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockBackend = InMemoryKeychainBackend()
        service = KeychainService(backend: mockBackend)
    }

    override func tearDown() {
        mockBackend.reset()
        super.tearDown()
    }

    // MARK: - Save and Load

    func testSaveAndLoad_ApiSessionKey_RoundTrips() throws {

        try service.save("test-api-key-abc", for: .apiSessionKey)
        let loaded = try service.load(for: .apiSessionKey)
        XCTAssertEqual(loaded, "test-api-key-abc")
    }

    func testSaveAndLoad_ClaudeSessionKey_RoundTrips() throws {

        try service.save("test-claude-key-xyz", for: .claudeSessionKey)
        let loaded = try service.load(for: .claudeSessionKey)
        XCTAssertEqual(loaded, "test-claude-key-xyz")
    }

    func testSave_OverwritesExistingValue() throws {

        try service.save("first-value", for: .apiSessionKey)
        try service.save("second-value", for: .apiSessionKey)
        let loaded = try service.load(for: .apiSessionKey)
        XCTAssertEqual(loaded, "second-value")
    }

    func testSave_EmptyString_RoundTrips() throws {

        try service.save("", for: .apiSessionKey)
        let loaded = try service.load(for: .apiSessionKey)
        XCTAssertEqual(loaded, "")
    }

    func testSave_UnicodeValue_RoundTrips() throws {

        let unicode = "token-\u{1F511}-\u{00E9}-\u{4E2D}\u{6587}"
        try service.save(unicode, for: .claudeSessionKey)
        let loaded = try service.load(for: .claudeSessionKey)
        XCTAssertEqual(loaded, unicode)
    }

    func testSave_LongValue_RoundTrips() throws {

        let longValue = String(repeating: "a", count: 4096)
        try service.save(longValue, for: .apiSessionKey)
        let loaded = try service.load(for: .apiSessionKey)
        XCTAssertEqual(loaded, longValue)
    }

    // MARK: - Load: Item Not Found

    func testLoad_ItemNotFound_ReturnsNil() throws {

        let loaded = try service.load(for: .apiSessionKey)
        XCTAssertNil(loaded)
    }

    // MARK: - Delete

    func testDelete_ExistingItem_SucceedsAndItemIsGone() throws {

        try service.save("to-be-deleted", for: .apiSessionKey)
        try service.delete(for: .apiSessionKey)
        let loaded = try service.load(for: .apiSessionKey)
        XCTAssertNil(loaded)
    }

    func testDelete_NonExistentItem_DoesNotThrow() throws {

        XCTAssertNoThrow(try service.delete(for: .claudeSessionKey))
    }

    func testDelete_CalledTwice_DoesNotThrow() throws {

        try service.save("temp", for: .apiSessionKey)
        try service.delete(for: .apiSessionKey)
        XCTAssertNoThrow(try service.delete(for: .apiSessionKey))
    }

    // MARK: - Exists

    func testExists_AfterSave_ReturnsTrue() throws {

        try service.save("present", for: .apiSessionKey)
        XCTAssertTrue(service.exists(for: .apiSessionKey))
    }

    func testExists_BeforeSave_ReturnsFalse() throws {

        XCTAssertFalse(service.exists(for: .apiSessionKey))
    }

    func testExists_AfterDelete_ReturnsFalse() throws {

        try service.save("present", for: .apiSessionKey)
        try service.delete(for: .apiSessionKey)
        XCTAssertFalse(service.exists(for: .apiSessionKey))
    }

    // MARK: - Key Independence

    func testTwoKeys_AreStoredIndependently() throws {

        try service.save("api-value", for: .apiSessionKey)
        try service.save("claude-value", for: .claudeSessionKey)
        XCTAssertEqual(try service.load(for: .apiSessionKey), "api-value")
        XCTAssertEqual(try service.load(for: .claudeSessionKey), "claude-value")
    }

    func testDeleteOneKey_DoesNotAffectOther() throws {

        try service.save("api-value", for: .apiSessionKey)
        try service.save("claude-value", for: .claudeSessionKey)
        try service.delete(for: .apiSessionKey)
        XCTAssertNil(try service.load(for: .apiSessionKey))
        XCTAssertEqual(try service.load(for: .claudeSessionKey), "claude-value")
    }

    // MARK: - KeychainKey Metadata (always run — no Keychain I/O)

    func testKeychainKey_ApiSessionKey_HasExpectedServiceAndAccount() {
        let key = KeychainService.KeychainKey.apiSessionKey
        XCTAssertEqual(key.service, "com.claudeusagetracker.api-session-key")
        XCTAssertEqual(key.account, "session-key")
    }

    func testKeychainKey_ClaudeSessionKey_HasExpectedServiceAndAccount() {
        let key = KeychainService.KeychainKey.claudeSessionKey
        XCTAssertEqual(key.service, "com.claudeusagetracker.claude-session-key")
        XCTAssertEqual(key.account, "session-key")
    }

    // MARK: - KeychainError localizedDescription (always run — no Keychain I/O)

    func testKeychainError_InvalidData_HasDescription() {
        let error = KeychainError.invalidData
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testKeychainError_SaveFailed_IncludesStatus() {
        let error = KeychainError.saveFailed(status: -25299)
        XCTAssertTrue(error.errorDescription?.contains("-25299") ?? false)
    }

    func testKeychainError_LoadFailed_IncludesStatus() {
        let error = KeychainError.loadFailed(status: -25300)
        XCTAssertTrue(error.errorDescription?.contains("-25300") ?? false)
    }

    func testKeychainError_DeleteFailed_IncludesStatus() {
        let error = KeychainError.deleteFailed(status: -25293)
        XCTAssertTrue(error.errorDescription?.contains("-25293") ?? false)
    }
}
