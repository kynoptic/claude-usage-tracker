//
//  StatuslineServiceTests.swift
//  Claude Usage Tests
//
//  Created on 2026-03-09.
//

import XCTest
@testable import Claude_Usage

final class StatuslineServiceTests: XCTestCase {

    private var service: StatuslineService!

    override func setUp() {
        super.setUp()
        service = StatuslineService.shared
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - isCredentialSafe: valid inputs

    func testTypicalSessionKeyIsAccepted() {
        // Standard sk-ant-* URL-safe Base64 format
        XCTAssertTrue(service.isCredentialSafe("sk-ant-sid01-abcdefghijklmnopqrstuvwxyz1234567890"))
    }

    func testTypicalOrgIdIsAccepted() {
        // UUID format: hex digits and hyphens only
        XCTAssertTrue(service.isCredentialSafe("a1b2c3d4-e5f6-7890-abcd-ef1234567890"))
    }

    func testAlphanumericWithHyphensAndUnderscoresIsAccepted() {
        XCTAssertTrue(service.isCredentialSafe("sk-ant-sid01-ABC_xyz-123.key:v1"))
    }

    // MARK: - isCredentialSafe: empty / whitespace

    func testEmptyStringIsRejected() {
        XCTAssertFalse(service.isCredentialSafe(""))
    }

    func testWhitespaceIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01 abc def"))
    }

    func testNewlineIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc\ndef"))
    }

    func testCarriageReturnIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc\rdef"))
    }

    // MARK: - isCredentialSafe: characters unsafe in Swift string literals

    func testBackslashIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc\\def"))
    }

    func testDoubleQuoteIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc\"def"))
    }

    func testStringInterpolationMarkerIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc$(injection)"))
    }

    func testSwiftInterpolationMarkerIsRejected() {
        // `\(` would be interpreted as Swift string interpolation in the generated script
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc\\(injection)"))
    }

    func testNullByteIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc\0def"))
    }

    // MARK: - isCredentialSafe: standard Base64 characters (intentionally excluded)

    /// `+` and `=` are standard Base64 alphabet but are excluded because
    /// Anthropic uses URL-safe Base64 (`-`/`_`) for session keys. Excluding
    /// them avoids widening the allow-list unnecessarily.
    func testPlusSignIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc+def"))
    }

    func testEqualsSignIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc=def"))
    }

    func testForwardSlashIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc/def"))
    }

    // MARK: - isCredentialSafe: other injection attempts

    func testAtSignIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-abc@evil.com"))
    }

    func testAngleBracketsAreRejected() {
        XCTAssertFalse(service.isCredentialSafe("<script>alert('xss')</script>"))
    }

    func testUnicodeIsRejected() {
        XCTAssertFalse(service.isCredentialSafe("sk-ant-sid01-héllo"))
    }
}
