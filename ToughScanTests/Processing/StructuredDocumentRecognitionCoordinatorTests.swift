import XCTest

final class StructuredDocumentRecognitionCoordinatorTests: XCTestCase {
    func testCompleteStoresDocumentForMatchingSnapshot() {
        var coordinator = StructuredDocumentRecognitionCoordinator()
        let snapshotID = UUID()
        let request = coordinator.begin(snapshotID: snapshotID)
        let document = StructuredDocument(paragraphs: ["Recognized"], tables: [], lists: [], barcodes: [])

        coordinator.complete(request, document: document)

        XCTAssertEqual(coordinator.document, document)
        XCTAssertNil(coordinator.message)
    }

    func testOlderCompletionDoesNotReplaceNewerSnapshot() {
        var coordinator = StructuredDocumentRecognitionCoordinator()
        let olderRequest = coordinator.begin(snapshotID: UUID())
        let newerRequest = coordinator.begin(snapshotID: UUID())
        let olderDocument = StructuredDocument(paragraphs: ["Old"], tables: [], lists: [], barcodes: [])
        let newerDocument = StructuredDocument(paragraphs: ["New"], tables: [], lists: [], barcodes: [])

        coordinator.complete(olderRequest, document: olderDocument)
        XCTAssertNil(coordinator.document)
        XCTAssertEqual(coordinator.message, StructuredDocumentRecognitionCoordinator.analyzingMessage)

        coordinator.complete(newerRequest, document: newerDocument)
        XCTAssertEqual(coordinator.document, newerDocument)
        XCTAssertNil(coordinator.message)
    }

    func testFailureOnlyAppliesForMatchingSnapshot() {
        var coordinator = StructuredDocumentRecognitionCoordinator()
        let olderRequest = coordinator.begin(snapshotID: UUID())
        _ = coordinator.begin(snapshotID: UUID())

        coordinator.fail(olderRequest)

        XCTAssertNil(coordinator.document)
        XCTAssertEqual(coordinator.message, StructuredDocumentRecognitionCoordinator.analyzingMessage)
    }

    func testClearRemovesDocumentAndMessage() {
        var coordinator = StructuredDocumentRecognitionCoordinator()
        let request = coordinator.begin(snapshotID: UUID())
        coordinator.complete(
            request,
            document: StructuredDocument(paragraphs: ["Recognized"], tables: [], lists: [], barcodes: [])
        )

        coordinator.clear()

        XCTAssertNil(coordinator.document)
        XCTAssertNil(coordinator.message)
    }
}
