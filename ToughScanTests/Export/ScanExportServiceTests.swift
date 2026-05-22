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

    func testMakeExportBundleRemovesDirectoryWhenWriteFails() throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("tough-scan-export-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }

        let writer = FailingExportDataWriter(failsOnWriteNumber: 2)
        let service = ScanExportService(
            temporaryDirectory: temporaryRoot,
            dataWriter: writer
        )

        XCTAssertThrowsError(
            try service.makeExportBundle(from: [makePage(text: "Original text", size: CGSize(width: 120, height: 180))])
        )

        let remainingItems = try FileManager.default.contentsOfDirectory(
            at: temporaryRoot,
            includingPropertiesForKeys: nil
        )
        XCTAssertEqual(remainingItems, [])
    }

    func testMakeExportBundleUsesStructuredDocumentTextWhenAvailable() throws {
        let service = ScanExportService()
        let page = ScannedPage(
            snapshot: DocumentSnapshot(
                image: makeImage(size: CGSize(width: 120, height: 180)),
                visualQuality: 0.82
            ),
            recognizedTextBlocks: [
                RecognizedTextBlock(
                    text: "Raw OCR fallback",
                    confidence: 0.62,
                    languageCode: "en",
                    tileCoordinates: [TileCoordinate(column: 0, row: 0)]
                )
            ],
            structuredDocument: StructuredDocument(
                paragraphs: ["Structured paragraph"],
                tables: [
                    StructuredTable(rows: [["Name", "Amount"], ["Ari", "42"]])
                ],
                lists: [],
                barcodes: []
            )
        )

        let bundle = try service.makeExportBundle(from: [page])
        defer {
            bundle.cleanup()
        }

        let textURL = try XCTUnwrap(bundle.fileURLs.first { $0.pathExtension == "txt" })
        let text = try String(contentsOf: textURL, encoding: .utf8)

        XCTAssertTrue(text.contains("Structured paragraph"))
        XCTAssertTrue(text.contains("Name\tAmount"))
        XCTAssertTrue(text.contains("Ari\t42"))
        XCTAssertFalse(text.contains("Raw OCR fallback"))
    }

    func testMakeExportBundleUsesCanonicalRecoveredTextSource() throws {
        let service = ScanExportService()
        let pages = [
            makePage(text: "   ", size: CGSize(width: 100, height: 160)),
            makePage(text: "Second page text", size: CGSize(width: 120, height: 180))
        ]

        let bundle = try service.makeExportBundle(from: pages)
        defer {
            bundle.cleanup()
        }

        let textURL = try XCTUnwrap(bundle.fileURLs.first { $0.pathExtension == "txt" })
        let text = try String(contentsOf: textURL, encoding: .utf8)

        XCTAssertEqual(text, ReviewTextSourceBuilder.makeSource(from: pages))
        XCTAssertFalse(text.contains("Page 1\n"))
        XCTAssertTrue(text.contains("Page 2\nSecond page text"))
    }

    func testMakeExportBundleExcludesIntelligenceNotesByDefault() throws {
        let service = ScanExportService()
        let notes = DocumentIntelligenceNotes(summary: "AI summary")

        let bundle = try service.makeExportBundle(
            from: [makePage(text: "Original text", size: CGSize(width: 120, height: 180))],
            intelligenceNotes: notes
        )
        defer {
            bundle.cleanup()
        }

        let textURL = try XCTUnwrap(bundle.fileURLs.first { $0.pathExtension == "txt" })
        let text = try String(contentsOf: textURL, encoding: .utf8)

        XCTAssertTrue(text.contains("Original text"))
        XCTAssertFalse(text.contains("AI summary"))
    }

    func testMakeExportBundleIncludesIntelligenceNotesWhenRequested() throws {
        let service = ScanExportService()
        let notes = DocumentIntelligenceNotes(
            summary: "AI summary",
            keyDetails: "Names: Ari",
            cleanedTextSuggestion: "Clean text"
        )

        let bundle = try service.makeExportBundle(
            from: [makePage(text: "Original text", size: CGSize(width: 120, height: 180))],
            intelligenceNotes: notes,
            includesIntelligenceNotes: true
        )
        defer {
            bundle.cleanup()
        }

        let textURL = try XCTUnwrap(bundle.fileURLs.first { $0.pathExtension == "txt" })
        let text = try String(contentsOf: textURL, encoding: .utf8)

        XCTAssertTrue(text.contains("Original text"))
        XCTAssertTrue(text.contains("Apple Intelligence suggestions"))
        XCTAssertTrue(text.contains("AI summary"))
        XCTAssertTrue(text.contains("Names: Ari"))
        XCTAssertTrue(text.contains("Clean text"))
    }

    func testDefaultExportStillUsesOriginalImagePDF() throws {
        let service = ScanExportService()
        let page = makePage(
            text: "Selectable recomposed text",
            size: CGSize(width: 120, height: 180),
            boundingBox: NormalizedRect(x: 0.10, y: 0.20, width: 0.70, height: 0.14)
        )

        let bundle = try service.makeExportBundle(from: [page])
        defer {
            bundle.cleanup()
        }

        let pdfURL = try XCTUnwrap(bundle.fileURLs.first { $0.pathExtension == "pdf" })
        let pdf = try XCTUnwrap(PDFDocument(url: pdfURL))

        XCTAssertFalse(pdf.string?.contains("Selectable recomposed text") == true)
    }

    func testRecomposedExportWritesSelectablePDFWhenEligible() throws {
        let service = ScanExportService()
        let page = makePage(
            text: "Selectable recomposed text",
            size: CGSize(width: 120, height: 180),
            boundingBox: NormalizedRect(x: 0.10, y: 0.20, width: 0.70, height: 0.14)
        )

        let bundle = try service.makeExportBundle(
            from: [page],
            exportMode: .recomposedPDFWithVisualMarks
        )
        defer {
            bundle.cleanup()
        }

        let pdfURL = try XCTUnwrap(bundle.fileURLs.first { $0.pathExtension == "pdf" })
        let pdf = try XCTUnwrap(PDFDocument(url: pdfURL))

        XCTAssertEqual(pdf.string, "Selectable recomposed text")
    }

    func testTextExportStillUsesReviewTextSourceBuilderForRecomposedMode() throws {
        let service = ScanExportService()
        let pages = [
            makePage(
                text: "Recomposed page text",
                size: CGSize(width: 120, height: 180),
                boundingBox: NormalizedRect(x: 0.10, y: 0.20, width: 0.70, height: 0.14)
            )
        ]

        let bundle = try service.makeExportBundle(
            from: pages,
            exportMode: .recomposedPDFWithVisualMarks
        )
        defer {
            bundle.cleanup()
        }

        let textURL = try XCTUnwrap(bundle.fileURLs.first { $0.pathExtension == "txt" })
        let text = try String(contentsOf: textURL, encoding: .utf8)

        XCTAssertEqual(text, ReviewTextSourceBuilder.makeSource(from: pages))
    }

    func testRecomposedExportCleanupRemovesTemporaryFiles() throws {
        let service = ScanExportService()
        let bundle = try service.makeExportBundle(
            from: [
                makePage(
                    text: "Recomposed page text",
                    size: CGSize(width: 120, height: 180),
                    boundingBox: NormalizedRect(x: 0.10, y: 0.20, width: 0.70, height: 0.14)
                )
            ],
            exportMode: .recomposedPDFWithVisualMarks
        )
        let exportDirectory = bundle.directoryURL

        bundle.cleanup()

        XCTAssertFalse(FileManager.default.fileExists(atPath: exportDirectory.path))
    }

    private func makePage(
        text: String,
        size: CGSize,
        boundingBox: NormalizedRect? = nil
    ) -> ScannedPage {
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
                    tileCoordinates: [TileCoordinate(column: 0, row: 0)],
                    boundingBox: boundingBox
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

private final class FailingExportDataWriter: ExportDataWriting {
    enum Error: Swift.Error {
        case writeFailed
    }

    private let failsOnWriteNumber: Int
    private var writeCount = 0

    init(failsOnWriteNumber: Int) {
        self.failsOnWriteNumber = failsOnWriteNumber
    }

    func write(_ data: Data, to url: URL) throws {
        writeCount += 1
        if writeCount == failsOnWriteNumber {
            throw Error.writeFailed
        }

        try data.write(to: url, options: .atomic)
    }
}

