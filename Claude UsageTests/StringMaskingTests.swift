import XCTest
@testable import Claude_Usage

/// Tests for String+Masking: `maskedKey()` and `profileInitials()`.
final class StringMaskingTests: XCTestCase {

    // MARK: - maskedKey: placeholder cases

    func testMaskedKey_EmptyString_ReturnsPlaceholder() {
        XCTAssertEqual("".maskedKey(), "•••••••••")
    }

    func testMaskedKey_ShortKey_ReturnsPlaceholder() {
        XCTAssertEqual("short".maskedKey(), "•••••••••")
    }

    func testMaskedKey_ExactlyTwentyChars_ReturnsPlaceholder() {
        let key = String(repeating: "a", count: 20)
        XCTAssertEqual(key.maskedKey(), "•••••••••")
    }

    // MARK: - maskedKey: masked cases (> 20 chars)

    func testMaskedKey_TwentyOneChars_ReturnsMaskedNotPlaceholder() {
        let key = String(repeating: "a", count: 21)
        XCTAssertNotEqual(key.maskedKey(), "•••••••••",
                          "A 21-char key should be masked, not replaced with the placeholder")
    }

    func testMaskedKey_LongKey_PreservesFirst12Chars() {
        let key = "sk-ant-sid01-abcdefghijklmnop"
        XCTAssertTrue(key.maskedKey().hasPrefix("sk-ant-sid01"),
                      "Expected first 12 chars to be preserved")
    }

    func testMaskedKey_LongKey_PreservesLast4Chars() {
        let key = "sk-ant-sid01-abcdefghijklmnop"
        XCTAssertTrue(key.maskedKey().hasSuffix("mnop"),
                      "Expected last 4 chars to be preserved")
    }

    func testMaskedKey_LongKey_ContainsBulletSeparator() {
        let key = "sk-ant-sid01-abcdefghijklmnop"
        XCTAssertTrue(key.maskedKey().contains("•••••"))
    }

    func testMaskedKey_DoesNotLeakMiddleSection() {
        // The middle portion between prefix and suffix must not appear
        let key = "sk-ant-sid01-SECRETSECRET-tail"
        let masked = key.maskedKey()
        XCTAssertFalse(masked.contains("SECRET"),
                       "Middle portion must not appear in masked output")
    }

    func testMaskedKey_ExactFormat() {
        // prefix(12) = "sk-ant-sid01", suffix(4) = "1234"
        let key = "sk-ant-sid01-MIDDLE-PART-1234"
        let masked = key.maskedKey()
        XCTAssertEqual(masked, "sk-ant-sid01•••••1234")
    }

    // MARK: - profileInitials: two-word names

    func testProfileInitials_TwoWords_TakesFirstLetterEach() {
        XCTAssertEqual("John Doe".profileInitials(), "JD")
    }

    func testProfileInitials_TwoWords_Uppercased() {
        XCTAssertEqual("john doe".profileInitials(), "JD")
    }

    func testProfileInitials_ThreeWords_TakesFirstTwo() {
        XCTAssertEqual("Alice Bob Charlie".profileInitials(), "AB")
    }

    // MARK: - profileInitials: single-word names

    func testProfileInitials_OneWord_TakesFirstTwoChars() {
        XCTAssertEqual("Claude".profileInitials(), "CL")
    }

    func testProfileInitials_OneWord_TwoChars_ReturnsAll() {
        XCTAssertEqual("Al".profileInitials(), "AL")
    }

    func testProfileInitials_OneWord_SingleChar_ReturnsThatChar() {
        XCTAssertEqual("A".profileInitials(), "A")
    }

    func testProfileInitials_OneWord_Lowercased_Uppercases() {
        XCTAssertEqual("hello".profileInitials(), "HE")
    }

    // MARK: - profileInitials: empty

    func testProfileInitials_EmptyString_ReturnsQuestionMark() {
        XCTAssertEqual("".profileInitials(), "?")
    }
}
