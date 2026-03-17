//
//  KeychainServicePerProfileTests.swift
//  Claude UsageTests
//
//  Tests for the per-profile Keychain CRUD methods added to KeychainService
//  as part of ADR-008.
//
//  Keychain I/O tests require the keychain-access-groups entitlement.
//  Unsigned CI builds call XCTSkipUnless on the same probe used by
//  KeychainServiceTests. Pure-metadata tests always run.

import XCTest
import Security
@testable import Claude_Usage

@MainActor
final class KeychainServicePerProfileTests: XCTestCase {

    // MARK: - Properties

    private var mockBackend: InMemoryKeychainBackend!
    private var service: KeychainService!
    private var testProfileId: UUID!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockBackend = InMemoryKeychainBackend()
        service = KeychainService(backend: mockBackend)
        testProfileId = UUID()
    }

    override func tearDown() async throws {
        mockBackend.reset()
        try await super.tearDown()
    }

    // MARK: - PerProfileCredentialType metadata (always run)

    func testPerProfileCredentialType_ClaudeSessionKey_HasExpectedService() {
        let svc = KeychainService.PerProfileCredentialType.claudeSessionKey.service
        XCTAssertEqual(svc, "com.claudeusagetracker.profile.claudeSessionKey")
    }

    func testPerProfileCredentialType_OrganizationId_HasExpectedService() {
        let svc = KeychainService.PerProfileCredentialType.organizationId.service
        XCTAssertEqual(svc, "com.claudeusagetracker.profile.organizationId")
    }

    func testPerProfileCredentialType_APISessionKey_HasExpectedService() {
        let svc = KeychainService.PerProfileCredentialType.apiSessionKey.service
        XCTAssertEqual(svc, "com.claudeusagetracker.profile.apiSessionKey")
    }

    func testPerProfileCredentialType_APIOrganizationId_HasExpectedService() {
        let svc = KeychainService.PerProfileCredentialType.apiOrganizationId.service
        XCTAssertEqual(svc, "com.claudeusagetracker.profile.apiOrganizationId")
    }

    func testPerProfileCredentialType_CLICredentialsJSON_HasExpectedService() {
        let svc = KeychainService.PerProfileCredentialType.cliCredentialsJSON.service
        XCTAssertEqual(svc, "com.claudeusagetracker.profile.cliCredentialsJSON")
    }

    func testPerProfileCredentialType_AllCasesCount_IsFive() {
        XCTAssertEqual(KeychainService.PerProfileCredentialType.allCases.count, 5)
    }

    // MARK: - Save + Load round-trips

    func testSaveAndLoadPerProfile_ClaudeSessionKey_RoundTrips() throws {
        try service.savePerProfile(
            "test-claude-key",
            profileId: testProfileId,
            credentialType: .claudeSessionKey
        )
        let loaded = try service.loadPerProfile(
            profileId: testProfileId,
            credentialType: .claudeSessionKey
        )
        XCTAssertEqual(loaded, "test-claude-key")
    }

    func testSaveAndLoadPerProfile_APISessionKey_RoundTrips() throws {
        try service.savePerProfile(
            "test-api-key",
            profileId: testProfileId,
            credentialType: .apiSessionKey
        )
        let loaded = try service.loadPerProfile(
            profileId: testProfileId,
            credentialType: .apiSessionKey
        )
        XCTAssertEqual(loaded, "test-api-key")
    }

    func testSaveAndLoadPerProfile_CLICredentialsJSON_RoundTrips() throws {
        let json = """
        {"claudeAiOauth":{"accessToken":"tok-abc"}}
        """
        try service.savePerProfile(
            json,
            profileId: testProfileId,
            credentialType: .cliCredentialsJSON
        )
        let loaded = try service.loadPerProfile(
            profileId: testProfileId,
            credentialType: .cliCredentialsJSON
        )
        XCTAssertEqual(loaded, json)
    }

    func testSavePerProfile_OverwritesExistingValue() throws {
        try service.savePerProfile("first", profileId: testProfileId, credentialType: .claudeSessionKey)
        try service.savePerProfile("second", profileId: testProfileId, credentialType: .claudeSessionKey)
        let loaded = try service.loadPerProfile(profileId: testProfileId, credentialType: .claudeSessionKey)
        XCTAssertEqual(loaded, "second")
    }

    // MARK: - Load: item not found

    func testLoadPerProfile_ItemNotFound_ReturnsNil() throws {
        let result = try service.loadPerProfile(
            profileId: testProfileId,
            credentialType: .claudeSessionKey
        )
        XCTAssertNil(result)
    }

    // MARK: - Delete

    func testDeletePerProfile_ExistingItem_SucceedsAndItemIsGone() throws {
        try service.savePerProfile("to-delete", profileId: testProfileId, credentialType: .apiSessionKey)
        try service.deletePerProfile(profileId: testProfileId, credentialType: .apiSessionKey)
        let loaded = try service.loadPerProfile(profileId: testProfileId, credentialType: .apiSessionKey)
        XCTAssertNil(loaded)
    }

    func testDeletePerProfile_NonExistentItem_DoesNotThrow() throws {
        XCTAssertNoThrow(
            try service.deletePerProfile(profileId: testProfileId, credentialType: .claudeSessionKey)
        )
    }

    // MARK: - deleteCredentials (bulk delete)

    func testDeleteCredentials_RemovesAllCredentialTypes() throws {
        try service.savePerProfile("key", profileId: testProfileId, credentialType: .claudeSessionKey)
        try service.savePerProfile("org", profileId: testProfileId, credentialType: .organizationId)
        try service.savePerProfile("api", profileId: testProfileId, credentialType: .apiSessionKey)

        service.deleteCredentials(for: testProfileId)

        for type_ in KeychainService.PerProfileCredentialType.allCases {
            let val = try service.loadPerProfile(profileId: testProfileId, credentialType: type_)
            XCTAssertNil(val, "\(type_) must be nil after deleteCredentials")
        }
    }

    func testDeleteCredentials_OnlyAffectsTargetProfile() throws {
        let otherProfileId = UUID()
        defer {
            try? service.deletePerProfile(profileId: otherProfileId, credentialType: .claudeSessionKey)
        }

        try service.savePerProfile("target", profileId: testProfileId, credentialType: .claudeSessionKey)
        try service.savePerProfile("other", profileId: otherProfileId, credentialType: .claudeSessionKey)

        service.deleteCredentials(for: testProfileId)

        let targetVal = try service.loadPerProfile(profileId: testProfileId, credentialType: .claudeSessionKey)
        let otherVal = try service.loadPerProfile(profileId: otherProfileId, credentialType: .claudeSessionKey)

        XCTAssertNil(targetVal, "Target profile credential must be removed")
        XCTAssertEqual(otherVal, "other", "Other profile credential must be unaffected")
    }

    // MARK: - Two profiles share same credential type independently

    func testTwoProfiles_SameCredentialType_AreStoredIndependently() throws {
        let profileIdB = UUID()
        defer {
            try? service.deletePerProfile(profileId: profileIdB, credentialType: .claudeSessionKey)
        }

        try service.savePerProfile("value-A", profileId: testProfileId, credentialType: .claudeSessionKey)
        try service.savePerProfile("value-B", profileId: profileIdB, credentialType: .claudeSessionKey)

        let valA = try service.loadPerProfile(profileId: testProfileId, credentialType: .claudeSessionKey)
        let valB = try service.loadPerProfile(profileId: profileIdB, credentialType: .claudeSessionKey)

        XCTAssertEqual(valA, "value-A")
        XCTAssertEqual(valB, "value-B")
    }
}
