import XCTest

final class StructuredDocumentRecognitionCoordinatorTests: XCTestCase {
    func testCompleteStoresDocumentForMatchingSnapshot() {
        var coordinator = StructuredDocumentRecognitionCoordinator()
        let snapshotID = UUID()
        let request = coordinator.begin(snapshotID: snapshotID)
        let document = StructuredDocument(paragraphs: ["Recognized"], tables: [], lists: [], barcodes: [])

        coordinator.complete(request, document: document)

        XCTAssertEqual(coordinator.document, document)
        XCTAssertEqual(coordinator.document(for: snapshotID), document)
        XCTAssertNil(coordinator.message)
    }

    func testDocumentLookupRejectsDifferentSnapshot() {
        var coordinator = StructuredDocumentRecognitionCoordinator()
        let snapshotID = UUID()
        let request = coordinator.begin(snapshotID: snapshotID)
        let document = StructuredDocument(paragraphs: ["Recognized"], tables: [], lists: [], barcodes: [])

        coordinator.complete(request, document: document)

        XCTAssertNil(coordinator.document(for: UUID()))
    }

    func testNewSnapshotClearsCompletedDocument() {
        var coordinator = StructuredDocumentRecognitionCoordinator()
        let request = coordinator.begin(snapshotID: UUID())
        coordinator.complete(
            request,
            document: StructuredDocument(paragraphs: ["Recognized"], tables: [], lists: [], barcodes: [])
        )

        _ = coordinator.begin(snapshotID: UUID())

        XCTAssertNil(coordinator.document)
        XCTAssertEqual(coordinator.message, StructuredDocumentRecognitionCoordinator.analyzingMessage)
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

    func testFailureAppliesForMatchingSnapshot() {
        var coordinator = StructuredDocumentRecognitionCoordinator()
        let request = coordinator.begin(snapshotID: UUID())

        coordinator.fail(request)

        XCTAssertNil(coordinator.document)
        XCTAssertEqual(coordinator.message, StructuredDocumentRecognitionCoordinator.unavailableMessage)
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
