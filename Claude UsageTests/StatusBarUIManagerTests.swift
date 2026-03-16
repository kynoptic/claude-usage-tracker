import XCTest
@testable import Claude_Usage

/// Tests for StatusBarUIManager dependency injection.
///
/// Verifies that `updateMultiProfileButtons`, `updateAllButtons`,
/// `updateButton`, and `primaryButton` receive all data via parameters
/// rather than reading from global singletons.
@MainActor
final class StatusBarUIManagerTests: XCTestCase {

    private var sut: StatusBarUIManager!

    override func setUp() {
        super.setUp()
        sut = StatusBarUIManager()
    }

    override func tearDown() {
        sut.cleanup()
        sut = nil
        super.tearDown()
    }

    // MARK: - updateMultiProfileButtons accepts appearance parameters

    /// Grey-zone settings are passed as parameters, not read from AppearanceStore.
    func testUpdateMultiProfileButtonsAcceptsGreyZoneParameters() {
        // Given: no profiles selected — method should return early but compile with new signature
        let profiles: [Profile] = []
        let config = MultiProfileDisplayConfig()

        // When/Then: calling with explicit showGrey/greyThreshold compiles and doesn't crash
        sut.updateMultiProfileButtons(
            profiles: profiles,
            config: config,
            showGrey: true,
            greyThreshold: 0.1
        )
    }

    // MARK: - updateAllButtons accepts icon config parameter

    /// Icon config is passed as a parameter, not read from ProfileManager.shared.
    func testUpdateAllButtonsAcceptsIconConfigParameter() {
        let usage = ClaudeUsage.empty
        let iconConfig = MenuBarIconConfiguration.default

        // Should compile and not crash (no status items set up = no-op)
        sut.updateAllButtons(
            usage: usage,
            apiUsage: nil,
            iconConfig: iconConfig,
            hasUsageCredentials: false
        )
    }

    // MARK: - updateButton accepts icon config parameter

    /// Per-metric update receives icon config as a parameter.
    func testUpdateButtonAcceptsIconConfigParameter() {
        let usage = ClaudeUsage.empty
        let iconConfig = MenuBarIconConfiguration.default

        sut.updateButton(
            for: .session,
            usage: usage,
            apiUsage: nil,
            iconConfig: iconConfig
        )
    }

    // MARK: - primaryButton accepts config parameter

    /// primaryButton receives config as a parameter instead of reading AppearanceStore.
    func testPrimaryButtonAcceptsConfigParameter() {
        let config = MenuBarIconConfiguration.default

        // No status items set up — should return nil
        let button = sut.primaryButton(for: config)
        XCTAssertNil(button)
    }
}
