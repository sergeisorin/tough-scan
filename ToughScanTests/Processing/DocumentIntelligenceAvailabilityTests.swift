import FoundationModels
import XCTest

final class DocumentIntelligenceAvailabilityTests: XCTestCase {
    func testAvailableModelAndLocaleCanGenerate() {
        let availability = DocumentIntelligenceAvailability.map(
            modelAvailability: .available,
            supportsLocale: true
        )

        XCTAssertTrue(availability.canGenerate)
        XCTAssertEqual(availability.message, "Apple Intelligence is available for this document.")
    }

    func testUnsupportedLocaleBlocksGeneration() {
        let availability = DocumentIntelligenceAvailability.map(
            modelAvailability: .available,
            supportsLocale: false
        )

        XCTAssertFalse(availability.canGenerate)
        XCTAssertEqual(availability.message, "Apple Intelligence is not available for the current language or locale.")
    }

    func testDisabledAppleIntelligenceExplainsSettingsRequirement() {
        let availability = DocumentIntelligenceAvailability.map(
            modelAvailability: .unavailable(.appleIntelligenceNotEnabled),
            supportsLocale: true
        )

        XCTAssertFalse(availability.canGenerate)
        XCTAssertEqual(availability.title, "Apple Intelligence is off")
    }
}
