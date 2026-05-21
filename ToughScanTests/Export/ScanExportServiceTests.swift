import PDFKit
import ToughScanCore
import XCTest

final class ScanExportServiceTests: XCTestCase {
    func testMakeExportBundleWritesMultiPagePDFAndPageSeparatedText() throws {
        let service = ScanExportService()
        let pages = [
            makePage(text: "First page text", size: CGSize(width: 120, height: 180)),
            makePage(text: "Second page text", size: CGSize(width: 140, height: 200))
        ]

        let bundle = try service.makeExportBundle(from: pages)
        defer {
            bundle.cleanup()
        }

        XCTAssertEqual(bundle.fileURLs.count, 2)

        let pdfURL = try XCTUnwrap(bundle.fileURLs.first { $0.pathExtension == "pdf" })
        let textURL = try XCTUnwrap(bundle.fileURLs.first { $0.pathExtension == "txt" })
        let pdf = try XCTUnwrap(PDFDocument(url: pdfURL))
        let text = try String(contentsOf: textURL, encoding: .utf8)
        let exportDirectory = bundle.directoryURL

        XCTAssertEqual(pdf.pageCount, 2)
        XCTAssertTrue(text.contains("Page 1"))
        XCTAssertTrue(text.contains("First page text"))
        XCTAssertTrue(text.contains("Page 2"))
        XCTAssertTrue(text.contains("Second page text"))

        bundle.cleanup()
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportDirectory.path))
    }

    func testMakeExportBundleRejectsEmptyPages() {
        let service = ScanExportService()

        XCTAssertThrowsError(try service.makeExportBundle(from: []))
    }

    private func makePage(text: String, size: CGSize) -> ScannedPage {
        ScannedPage(
            snapshot: DocumentSnapshot(
                image: makeImage(size: size),
                visualQuality: 0.82
            ),
            recognizedTextBlocks: [
                RecognizedTextBlock(
                    text: text,
                    confidence: 0.91,
                    languageCode: "en",
                    tileCoordinates: [TileCoordinate(column: 0, row: 0)]
                )
            ]
        )
    }

    private func makeImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setFill()
            context.fill(CGRect(x: 12, y: 12, width: size.width - 24, height: 2))
        }
    }
}

