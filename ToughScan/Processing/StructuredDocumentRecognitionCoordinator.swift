import Foundation

struct StructuredDocumentRecognitionRequest: Equatable {
    let snapshotID: UUID
    let runID: UUID

    init(snapshotID: UUID, runID: UUID = UUID()) {
        self.snapshotID = snapshotID
        self.runID = runID
    }
}

struct StructuredDocumentRecognitionCoordinator: Equatable {
    static let analyzingMessage = "Analyzing document structure locally."
    static let unavailableMessage = "Structured document analysis is unavailable for this scan."

    private(set) var document: StructuredDocument?
    private(set) var message: String?
    private var snapshotID: UUID?
    private var runID: UUID?

    mutating func begin(snapshotID: UUID) -> StructuredDocumentRecognitionRequest {
        let request = StructuredDocumentRecognitionRequest(snapshotID: snapshotID)
        self.snapshotID = request.snapshotID
        self.runID = request.runID
        self.document = nil
        self.message = Self.analyzingMessage
        return request
    }

    mutating func complete(_ request: StructuredDocumentRecognitionRequest, document: StructuredDocument) {
        guard isCurrent(request) else {
            return
        }

        self.document = document
        self.message = nil
    }

    mutating func fail(_ request: StructuredDocumentRecognitionRequest) {
        guard isCurrent(request) else {
            return
        }

        self.document = nil
        self.message = Self.unavailableMessage
    }

    mutating func clear() {
        snapshotID = nil
        runID = nil
        document = nil
        message = nil
    }

    private func isCurrent(_ request: StructuredDocumentRecognitionRequest) -> Bool {
        snapshotID == request.snapshotID && runID == request.runID
    }
}
