import ToughScanCore
import XCTest

final class ScanReviewStateTests: XCTestCase {
    func testCurrentPageIncludesStructuredDocumentAndVisualRegions() throws {
        let snapshotID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let snapshot = DocumentSnapshot(
            id: snapshotID,
            image: makeImage(),
            visualQuality: 0.88
        )
        let structuredDocument = StructuredDocument(paragraphs: ["Structured"], tables: [], lists: [], barcodes: [])
        let visualRegion = makeVisualRegion()
        var structuredCoordinator = StructuredDocumentRecognitionCoordinator()
        let structuredRequest = structuredCoordinator.begin(snapshotID: snapshotID)
        structuredCoordinator.complete(structuredRequest, document: structuredDocument)
        var visualCoordinator = VisualDocumentRegionDetectionCoordinator()
        let visualRequest = visualCoordinator.begin(snapshotID: snapshotID)
        visualCoordinator.complete(visualRequest, regions: [visualRegion])

        let state = ScanReviewState(
            session: makeSession(text: "OCR text"),
            snapshot: snapshot,
            capturedPages: [],
            structuredRecognitionCoordinator: structuredCoordinator,
            visualRegionDetectionCoordinator: visualCoordinator,
            selectedExportMode: .originalImagePDF
        )

        let currentPage = try XCTUnwrap(state.currentPage)
        XCTAssertEqual(currentPage.id, snapshotID)
        XCTAssertEqual(currentPage.structuredDocument, structuredDocument)
        XCTAssertEqual(currentPage.visualRegions, [visualRegion])
        XCTAssertEqual(state.pagesForExport.map(\.id), [snapshotID])
    }

    func testExportModeAvailabilityDescribesUnavailableRecomposedMode() {
        let state = ScanReviewState(
            session: makeSession(text: "OCR text"),
            snapshot: DocumentSnapshot(image: makeImage(), visualQuality: 0.88),
            capturedPages: [],
            structuredRecognitionCoordinator: StructuredDocumentRecognitionCoordinator(),
            visualRegionDetectionCoordinator: VisualDocumentRegionDetectionCoordinator(),
            selectedExportMode: .recomposedPDFWithVisualMarks
        )

        XCTAssertTrue(state.isSelectedExportModeUnavailable)
        XCTAssertEqual(
            state.exportModeMessage,
            "Cleaned/recomposed export needs positioned OCR text. Use original-image PDF for this scan."
        )
    }

    private func makeSession(text: String) -> ProgressiveScanSession {
        var session = ProgressiveScanSession(gridWidth: 1, gridHeight: 1)
        session.addFrame(
            FrameObservation(
                id: "frame",
                tileEvidence: [],
                recognizedTextBlocks: [
                    RecognizedTextBlock(
                        text: text,
                        confidence: 0.90,
                        languageCode: "en",
                        tileCoordinates: []
                    )
                ]
            )
        )
        return session
    }

    private func makeVisualRegion() -> VisualDocumentRegion {
        VisualDocumentRegion(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            kind: .stampOrSignature,
            boundingBox: NormalizedRect(x: 0.2, y: 0.3, width: 0.2, height: 0.1),
            confidence: 0.8,
            image: makeImage()
        )
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
        }
    }
}
