//
//  ProfileStoreErrorTests.swift
//  Claude UsageTests
//
//  Verifies that ProfileStore throws typed ProfileStoreError values instead of
//  raw NSError instances when a profile cannot be found.
//

import XCTest
@testable import Claude_Usage

@MainActor
final class ProfileStoreErrorTests: XCTestCase {

    private var store: ProfileStore!

    override func setUp() async throws {
        try await super.setUp()
        store = ProfileStore.shared
        // Seed the store with a known profile so baseline state is clean.
        let seed = Profile(name: "Error Test Profile")
        store.saveProfiles([seed])
    }

    override func tearDown() async throws {
        // Leave a single valid profile so other test suites find a clean state.
        let cleanup = Profile(name: "Cleanup Profile")
        store.saveProfiles([cleanup])
        try await super.tearDown()
    }

    // MARK: - loadProfileCredentials

    func testLoadProfileCredentials_UnknownId_ThrowsProfileNotFound() throws {
        let unknownId = UUID()
        XCTAssertThrowsError(try store.loadProfileCredentials(unknownId)) { error in
            guard case ProfileStoreError.profileNotFound(let id) = error else {
                XCTFail("Expected ProfileStoreError.profileNotFound, got \(error)")
                return
            }
            XCTAssertEqual(id, unknownId)
        }
    }

    func testLoadProfileCredentials_UnknownId_IsTypedError() throws {
        let unknownId = UUID()
        do {
            _ = try store.loadProfileCredentials(unknownId)
            XCTFail("Expected error to be thrown")
        } catch {
            // Must be matchable as ProfileStoreError (not a raw NSError)
            XCTAssertNotNil(error as? ProfileStoreError,
                            "Expected ProfileStoreError but got \(type(of: error))")
        }
    }

    // MARK: - saveProfileCredentials

    func testSaveProfileCredentials_UnknownId_ThrowsProfileNotFound() throws {
        let unknownId = UUID()
        let creds = ProfileCredentials()
        XCTAssertThrowsError(try store.saveProfileCredentials(unknownId, credentials: creds)) { error in
            guard case ProfileStoreError.profileNotFound(let id) = error else {
                XCTFail("Expected ProfileStoreError.profileNotFound, got \(error)")
                return
            }
            XCTAssertEqual(id, unknownId)
        }
    }

    // MARK: - ErrorDescription

    func testProfileStoreError_ErrorDescription_ContainsUUID() {
        let id = UUID()
        let error = ProfileStoreError.profileNotFound(id)
        XCTAssertTrue(error.errorDescription?.contains(id.uuidString) == true)
    }
}
