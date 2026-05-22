import ToughScanCore
import XCTest

final class ScanExportModeAvailabilityTests: XCTestCase {
    func testOriginalImageModeIsAlwaysAvailableForEmptyPages() {
        let availability = ScanExportModeAvailability(
            selectedMode: .originalImagePDF,
            pages: []
        )

        XCTAssertFalse(availability.isSelectedModeUnavailable)
        XCTAssertEqual(availability.message, "Default. Preserves the recovered page image exactly as reviewed.")
    }

    func testRecomposedModeExplainsEmptyPages() {
        let availability = ScanExportModeAvailability(
            selectedMode: .recomposedPDFWithVisualMarks,
            pages: []
        )

        XCTAssertTrue(availability.isSelectedModeUnavailable)
        XCTAssertEqual(availability.message, "Cleaned/recomposed export becomes available after a page is ready.")
    }

    func testRecomposedModeExplainsNoEligiblePages() {
        let availability = ScanExportModeAvailability(
            selectedMode: .recomposedPDFWithVisualMarks,
            pages: [makePage(textBlocks: [])]
        )

        XCTAssertTrue(availability.isSelectedModeUnavailable)
        XCTAssertEqual(
            availability.message,
            "Cleaned/recomposed export needs positioned OCR text. Use original-image PDF for this scan."
        )
    }

    func testRecomposedModeExplainsPartiallyEligiblePages() {
        let availability = ScanExportModeAvailability(
            selectedMode: .recomposedPDFWithVisualMarks,
            pages: [
                makePage(textBlocks: [makePositionedTextBlock()]),
                makePage(textBlocks: [])
            ]
        )

        XCTAssertFalse(availability.isSelectedModeUnavailable)
        XCTAssertEqual(availability.recomposedEligiblePageCount, 1)
        XCTAssertEqual(
            availability.message,
            "Eligible pages will be recomposed; pages without positioned text will fall back to original-image PDF."
        )
    }

    func testRecomposedModeExplainsAllEligiblePages() {
        let availability = ScanExportModeAvailability(
            selectedMode: .recomposedPDFWithVisualMarks,
            pages: [makePage(textBlocks: [makePositionedTextBlock()])]
        )

        XCTAssertFalse(availability.isSelectedModeUnavailable)
        XCTAssertEqual(availability.message, "Experimental. Rebuilds text on a white page and overlays detected visual marks.")
    }

    private func makePage(textBlocks: [RecognizedTextBlock]) -> ScannedPage {
        ScannedPage(
            snapshot: DocumentSnapshot(image: makeImage(), visualQuality: 0.8),
            recognizedTextBlocks: textBlocks
        )
    }

    private func makePositionedTextBlock() -> RecognizedTextBlock {
        RecognizedTextBlock(
            text: "Positioned",
            confidence: 0.9,
            languageCode: "en",
            tileCoordinates: [],
            boundingBox: NormalizedRect(x: 0.1, y: 0.7, width: 0.4, height: 0.1)
        )
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
        }
    }
}
