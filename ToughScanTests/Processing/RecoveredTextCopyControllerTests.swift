import ToughScanCore
import XCTest

final class RecoveredTextCopyControllerTests: XCTestCase {
    func testCopyRecoveredTextCopiesCanonicalSource() {
        let clipboard = SpyClipboard()
        let controller = RecoveredTextCopyController(clipboard: clipboard)
        let pages = [
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("   ")]),
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("Copy this")])
        ]

        XCTAssertTrue(controller.copyRecoveredText(from: pages))
        XCTAssertEqual(clipboard.copiedText, "Page 2\nCopy this")
    }

    func testCopyRecoveredTextResultDescribesCopiedSource() {
        let clipboard = SpyClipboard()
        let controller = RecoveredTextCopyController(clipboard: clipboard)
        let pages = [
            ScannedPage(
                snapshot: makeSnapshot(),
                recognizedTextBlocks: [makeTextBlock("Raw OCR")],
                structuredDocument: StructuredDocument(
                    paragraphs: ["Structured text"],
                    tables: [],
                    lists: [],
                    barcodes: []
                )
            ),
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("OCR text")])
        ]

        let result = controller.copyRecoveredTextResult(from: pages)

        XCTAssertTrue(result.didCopy)
        XCTAssertEqual(result.message, "Copied structured and OCR text from 2 pages.")
        XCTAssertEqual(result.summary.copyablePageCount, 2)
        XCTAssertEqual(clipboard.copiedText, "Page 1\nStructured text\n\nPage 2\nOCR text")
    }

    func testCopyRecoveredTextRejectsEmptySource() {
        let clipboard = SpyClipboard()
        let controller = RecoveredTextCopyController(clipboard: clipboard)
        let pages = [
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("   ")])
        ]

        XCTAssertFalse(controller.copyRecoveredText(from: pages))
        XCTAssertNil(clipboard.copiedText)
    }

    func testCopyRecoveredTextResultExplainsEmptySource() {
        let clipboard = SpyClipboard()
        let controller = RecoveredTextCopyController(clipboard: clipboard)
        let pages = [
            ScannedPage(snapshot: makeSnapshot(), recognizedTextBlocks: [makeTextBlock("\n\t")])
        ]

        let result = controller.copyRecoveredTextResult(from: pages)

        XCTAssertFalse(result.didCopy)
        XCTAssertEqual(result.message, "No recovered text is ready to copy yet.")
        XCTAssertTrue(result.summary.isEmpty)
        XCTAssertNil(clipboard.copiedText)
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

private final class SpyClipboard: ClipboardCopying {
    private(set) var copiedText: String?

    func copy(_ text: String) {
        copiedText = text
    }
}
