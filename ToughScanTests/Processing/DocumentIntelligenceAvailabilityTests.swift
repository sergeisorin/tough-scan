import FoundationModels
import XCTest

final class DocumentIntelligenceAvailabilityTests: XCTestCase {
    func testAvailableModelAndLocaleCanGenerate() {
        let availability = DocumentIntelligenceAvailability.map(
            modelAvailability: .available,
            supportsLocale: true
        )

        XCTAssertTrue(availability.canGenerate)
        XCTAssertEqual(availability.title, "AI-assisted review ready")
        XCTAssertEqual(availability.message, "AI-assisted review is ready for this recovered text.")
    }

    func testUnsupportedLocaleBlocksGeneration() {
        let availability = DocumentIntelligenceAvailability.map(
            modelAvailability: .available,
            supportsLocale: false
        )

        XCTAssertFalse(availability.canGenerate)
        XCTAssertEqual(
            availability.message,
            "AI-assisted review is not available for the current language or locale. You can still copy and export recovered text."
        )
    }

    func testDisabledAppleIntelligenceExplainsSettingsRequirement() {
        let availability = DocumentIntelligenceAvailability.map(
            modelAvailability: .unavailable(.appleIntelligenceNotEnabled),
            supportsLocale: true
        )

        XCTAssertFalse(availability.canGenerate)
        XCTAssertEqual(availability.title, "Apple Intelligence is off")
        XCTAssertEqual(
            availability.message,
            "Turn on Apple Intelligence in Settings to summarize, extract, or clean recovered text. Scan, copy, and export still work without it."
        )
    }

    func testModelNotReadyExplainsNonBlockingFallback() {
        let availability = DocumentIntelligenceAvailability.map(
            modelAvailability: .unavailable(.modelNotReady),
            supportsLocale: true
        )

        XCTAssertFalse(availability.canGenerate)
        XCTAssertEqual(availability.title, "AI-assisted review is preparing")
        XCTAssertEqual(
            availability.message,
            "Apple Intelligence is still downloading or preparing. Try again later. Recovered text can still be copied and exported."
        )
    }

    func testStaticProviderCanSimulateAllReviewStates() {
        let states: [DocumentIntelligenceAvailability] = [
            .available,
            .deviceNotEligible,
            .appleIntelligenceNotEnabled,
            .modelNotReady,
            .unsupportedLocale,
            .unknown
        ]

        for state in states {
            let provider = StaticDocumentIntelligenceAvailabilityProvider(availability: state)
            XCTAssertEqual(provider.currentAvailability(), state)
        }
    }
}
