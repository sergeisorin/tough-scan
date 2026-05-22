import ToughScanCore
import XCTest

final class ReviewTextSourceBuilderTests: XCTestCase {
    func testStructuredDocumentTextTakesPrecedenceOverOCRFallback() {
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [makeTextBlock("Raw OCR should not be used")],
                structuredDocument: StructuredDocument(
                    paragraphs: ["Structured paragraph"],
                    tables: [StructuredTable(rows: [["Name", "Amount"], ["Ari", "42"]])],
                    lists: [],
                    barcodes: []
                )
            )
        ]

        let source = ReviewTextSourceBuilder.makeSource(from: pages)

        XCTAssertTrue(source.contains("Page 1"))
        XCTAssertTrue(source.contains("Structured paragraph"))
        XCTAssertTrue(source.contains("Name\tAmount"))
        XCTAssertFalse(source.contains("Raw OCR should not be used"))
    }

    func testUsesOCRWhenStructuredDocumentIsMissing() {
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [
                    makeTextBlock("First OCR line"),
                    makeTextBlock("Second OCR line")
                ]
            )
        ]

        let source = ReviewTextSourceBuilder.makeSource(from: pages)

        XCTAssertTrue(source.contains("First OCR line"))
        XCTAssertTrue(source.contains("Second OCR line"))
    }

    func testOmitsPagesWithoutUsableText() {
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [],
                structuredDocument: StructuredDocument(paragraphs: [], tables: [], lists: [], barcodes: [])
            )
        ]

        XCTAssertEqual(ReviewTextSourceBuilder.makeSource(from: pages), "")
    }

    func testDropsWhitespaceOnlyOCRBlocks() {
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [
                    makeTextBlock("   "),
                    makeTextBlock("\n\t"),
                    makeTextBlock("Readable text")
                ]
            )
        ]

        XCTAssertEqual(ReviewTextSourceBuilder.makeSource(from: pages), "Page 1\nReadable text")
    }

    func testOmitsEmptyPagesWhilePreservingOriginalPageNumbers() {
        let pages = [
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("   ")]),
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("שלום readable")])
        ]

        XCTAssertEqual(ReviewTextSourceBuilder.makeSource(from: pages), "Page 2\nשלום readable")
    }

    func testJoinsMultiplePagesWithBlankLineSeparator() {
        let pages = [
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("First")]),
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("Second")])
        ]

        XCTAssertEqual(ReviewTextSourceBuilder.makeSource(from: pages), "Page 1\nFirst\n\nPage 2\nSecond")
    }

    private func makeTextBlock(_ text: String) -> RecognizedTextBlock {
        RecognizedTextBlock(
            text: text,
            confidence: 0.9,
            languageCode: "en",
            tileCoordinates: [TileCoordinate(column: 0, row: 0)]
        )
    }

    private func makeSnapshot() -> DocumentSnapshot {
        DocumentSnapshot(
            image: UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140)).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
            },
            visualQuality: 0.82
        )
    }
}
