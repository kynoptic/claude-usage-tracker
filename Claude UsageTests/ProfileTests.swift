import XCTest
@testable import Claude_Usage

/// Unit tests for the Profile model.
///
/// Profile is a pure data struct — no service dependencies, no I/O.
/// These tests verify that `hasUsageCredentials` and `isValidOAuthJSON`
/// behave correctly without spawning subprocesses.
final class ProfileTests: XCTestCase {

    // MARK: - hasUsageCredentials

    func testHasUsageCredentials_noCredentials_returnsFalse() {
        let profile = Profile(name: "Empty")
        XCTAssertFalse(profile.hasUsageCredentials)
    }

    func testHasUsageCredentials_claudeAI_returnsTrue() {
        let profile = Profile(
            name: "Claude",
            claudeSessionKey: "sk-test",
            organizationId: "org-123"
        )
        XCTAssertTrue(profile.hasUsageCredentials)
    }

    func testHasUsageCredentials_apiConsole_returnsTrue() {
        let profile = Profile(
            name: "API",
            apiSessionKey: "sk-api",
            apiOrganizationId: "org-api"
        )
        XCTAssertTrue(profile.hasUsageCredentials)
    }

    func testHasUsageCredentials_validOAuth_returnsTrue() {
        let profile = Profile(
            name: "OAuth",
            hasValidOAuthCredentials: true
        )
        XCTAssertTrue(profile.hasUsageCredentials)
    }

    func testHasUsageCredentials_expiredOAuth_returnsFalse() {
        let profile = Profile(
            name: "Expired",
            cliCredentialsJSON: "{}",
            hasValidOAuthCredentials: false
        )
        XCTAssertFalse(profile.hasUsageCredentials)
    }

    // MARK: - isValidOAuthJSON

    func testIsValidOAuthJSON_validNotExpired_returnsTrue() {
        let futureEpoch = Date().timeIntervalSince1970 + 3600  // 1 hour from now
        let json = """
        {"claudeAiOauth":{"accessToken":"tok_test","expiresAt":\(futureEpoch)}}
        """
        XCTAssertTrue(Profile.isValidOAuthJSON(json))
    }

    func testIsValidOAuthJSON_expired_returnsFalse() {
        let pastEpoch = Date().timeIntervalSince1970 - 3600  // 1 hour ago
        let json = """
        {"claudeAiOauth":{"accessToken":"tok_test","expiresAt":\(pastEpoch)}}
        """
        XCTAssertFalse(Profile.isValidOAuthJSON(json))
    }

    func testIsValidOAuthJSON_noExpiry_returnsTrue() {
        let json = """
        {"claudeAiOauth":{"accessToken":"tok_test"}}
        """
        XCTAssertTrue(Profile.isValidOAuthJSON(json))
    }

    func testIsValidOAuthJSON_noAccessToken_returnsFalse() {
        let json = """
        {"claudeAiOauth":{"refreshToken":"ref_test"}}
        """
        XCTAssertFalse(Profile.isValidOAuthJSON(json))
    }

    func testIsValidOAuthJSON_invalidJSON_returnsFalse() {
        XCTAssertFalse(Profile.isValidOAuthJSON("not json"))
    }

    func testIsValidOAuthJSON_emptyJSON_returnsFalse() {
        XCTAssertFalse(Profile.isValidOAuthJSON("{}"))
    }

    func testIsValidOAuthJSON_millisecondEpoch_handledCorrectly() {
        // Millisecond epoch (> 1e12) should be normalized to seconds
        let futureMs = (Date().timeIntervalSince1970 + 3600) * 1000
        let json = """
        {"claudeAiOauth":{"accessToken":"tok_test","expiresAt":\(futureMs)}}
        """
        XCTAssertTrue(Profile.isValidOAuthJSON(json))
    }

    // MARK: - Pure data struct (no service dependency)

    func testProfileCanBeCreatedWithoutServices() {
        // Profile should be instantiable as a pure value type
        let profile = Profile(
            name: "Test",
            cliCredentialsJSON: "{\"claudeAiOauth\":{\"accessToken\":\"tok\"}}",
            hasValidOAuthCredentials: true
        )
        XCTAssertTrue(profile.hasUsageCredentials)
        XCTAssertEqual(profile.name, "Test")
    }

    func testProfileCodableRoundTrip() throws {
        let profile = Profile(
            name: "Codable",
            hasValidOAuthCredentials: true
        )
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)
        XCTAssertEqual(decoded.hasValidOAuthCredentials, true)
        XCTAssertEqual(decoded.name, "Codable")
    }

    // MARK: - Credential exclusion from Codable

    func testEncode_ExcludesCredentialFields() throws {
        let profile = Profile(
            name: "Secrets",
            claudeSessionKey: "sk-ant-sid01-secret",
            organizationId: "org-uuid-123",
            apiSessionKey: "sk-api-secret",
            apiOrganizationId: "org-api-456",
            cliCredentialsJSON: "{\"token\":\"secret\"}"
        )

        let data = try JSONEncoder().encode(profile)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Credential fields must NOT appear in encoded output
        XCTAssertNil(json["claudeSessionKey"], "claudeSessionKey must not be serialized")
        XCTAssertNil(json["organizationId"], "organizationId must not be serialized")
        XCTAssertNil(json["apiSessionKey"], "apiSessionKey must not be serialized")
        XCTAssertNil(json["apiOrganizationId"], "apiOrganizationId must not be serialized")
        XCTAssertNil(json["cliCredentialsJSON"], "cliCredentialsJSON must not be serialized")

        // Non-credential fields must still be present
        XCTAssertEqual(json["name"] as? String, "Secrets")
        XCTAssertNotNil(json["id"])
    }

    func testDecode_StillReadsLegacyCredentialFields() throws {
        // Simulate data written by older versions that included credentials
        let json: [String: Any] = [
            "id": UUID().uuidString,
            "name": "Legacy",
            "claudeSessionKey": "sk-legacy-key",
            "organizationId": "org-legacy",
            "hasCliAccount": false,
            "hasValidOAuthCredentials": false,
            "refreshInterval": 30.0,
            "autoStartSessionEnabled": false,
            "checkOverageLimitEnabled": true,
            "isSelectedForDisplay": true,
            "createdAt": Date().timeIntervalSince1970,
            "lastUsedAt": Date().timeIntervalSince1970
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)

        // Legacy credentials must still be readable for migration
        XCTAssertEqual(decoded.claudeSessionKey, "sk-legacy-key")
        XCTAssertEqual(decoded.organizationId, "org-legacy")
        XCTAssertEqual(decoded.name, "Legacy")
    }

    func testRoundTrip_CredentialsNotPersisted() throws {
        let original = Profile(
            name: "RoundTrip",
            claudeSessionKey: "sk-secret",
            organizationId: "org-123"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Profile.self, from: data)

        // Credentials should be nil after round-trip (excluded from encoding)
        XCTAssertNil(decoded.claudeSessionKey)
        XCTAssertNil(decoded.organizationId)
        // Non-credential fields preserved
        XCTAssertEqual(decoded.name, "RoundTrip")
    }
}
