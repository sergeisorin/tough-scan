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

    func testConfirmedWordReplacesWeakWordInExportText() {
        let weakWord = makeWord("5▯4-7▮8-3▮1", confidence: 0.42)
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [makeTextBlock("Business #: 5▯4-7▮8-3▮1")],
                recognizedWords: [
                    makeWord("Business", confidence: 0.91),
                    makeWord("#:", confidence: 0.88),
                    weakWord
                ],
                confirmedWords: [
                    ConfirmedRecognizedWord(word: weakWord, resolvedText: "514-728-301")
                ]
            )
        ]

        XCTAssertEqual(ReviewTextSourceBuilder.makeSource(from: pages), "Page 1\nBusiness #: 514-728-301")
    }

    func testConfirmedWordTextTakesPrecedenceOverStructuredText() {
        let weakWord = makeWord("5▯4", confidence: 0.42)
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [makeTextBlock("Business #: 5▯4")],
                recognizedWords: [
                    makeWord("Business", confidence: 0.91),
                    makeWord("#:", confidence: 0.88),
                    weakWord
                ],
                confirmedWords: [
                    ConfirmedRecognizedWord(word: weakWord, resolvedText: "514")
                ],
                structuredDocument: StructuredDocument(
                    paragraphs: ["Structured stale business number 5▯4"],
                    tables: [],
                    lists: [],
                    barcodes: []
                )
            )
        ]

        XCTAssertEqual(ReviewTextSourceBuilder.makeSource(from: pages), "Page 1\nBusiness #: 514")
    }

    func testConfirmedWordStillAppliesAfterOCRTextChangesInSameLocation() {
        let weakWord = makeWord("5▯4", confidence: 0.42)
        let correctedWord = makeWord("S14", confidence: 0.72)
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [makeTextBlock("Business #: S14")],
                recognizedWords: [
                    makeWord("Business", confidence: 0.91),
                    makeWord("#:", confidence: 0.88),
                    correctedWord
                ],
                confirmedWords: [
                    ConfirmedRecognizedWord(word: weakWord, resolvedText: "514")
                ]
            )
        ]

        XCTAssertEqual(ReviewTextSourceBuilder.makeSource(from: pages), "Page 1\nBusiness #: 514")
    }

    func testPendingWeakWordStaysMarkedInExportText() {
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [makeTextBlock("VAT 17% ₪…")],
                recognizedWords: [
                    makeWord("VAT", confidence: 0.91),
                    makeWord("17%", confidence: 0.88),
                    makeWord("₪…", confidence: 0.35)
                ]
            )
        ]

        XCTAssertEqual(ReviewTextSourceBuilder.makeSource(from: pages), "Page 1\nVAT 17% [? ₪… ?]")
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

    func testSummaryDescribesStructuredAndOCRSources() {
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [makeTextBlock("OCR fallback")],
                structuredDocument: StructuredDocument(
                    paragraphs: ["Structured paragraph"],
                    tables: [],
                    lists: [],
                    barcodes: []
                )
            ),
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("OCR page")])
        ]

        let summary = ReviewTextSourceBuilder.makeSummary(from: pages)

        XCTAssertEqual(summary.text, "Page 1\nStructured paragraph\n\nPage 2\nOCR page")
        XCTAssertEqual(summary.copyablePageCount, 2)
        XCTAssertTrue(summary.usesStructuredText)
        XCTAssertTrue(summary.usesOCRText)
        XCTAssertEqual(summary.sourceDescription, "structured and OCR text")
        XCTAssertEqual(summary.copyablePageDescription, "2 pages")
    }

    func testSummaryDescribesEmptySource() {
        let pages = [
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("   ")])
        ]

        let summary = ReviewTextSourceBuilder.makeSummary(from: pages)

        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.copyablePageCount, 0)
        XCTAssertFalse(summary.usesStructuredText)
        XCTAssertFalse(summary.usesOCRText)
        XCTAssertEqual(summary.sourceDescription, "no copyable text")
        XCTAssertEqual(summary.copyablePageDescription, "0 pages")
    }

    private func makeTextBlock(_ text: String) -> RecognizedTextBlock {
        RecognizedTextBlock(
            text: text,
            confidence: 0.9,
            languageCode: "en",
            tileCoordinates: [TileCoordinate(column: 0, row: 0)]
        )
    }

    private func makeWord(_ text: String, confidence: Double) -> RecognizedWord {
        let x: Double
        if text == "Business" {
            x = 0.10
        } else if text == "#:" || text == "17%" {
            x = 0.24
        } else if text == "VAT" {
            x = 0.10
        } else {
            x = 0.38
        }

        return RecognizedWord(
            text: text,
            confidence: confidence,
            languageCode: "en",
            tileCoordinates: [TileCoordinate(column: 0, row: 0)],
            boundingBox: NormalizedRect(x: x, y: 0.7, width: 0.1, height: 0.05),
            lineText: text,
            lineBoundingBox: NormalizedRect(x: 0.1, y: 0.7, width: 0.4, height: 0.05)
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
