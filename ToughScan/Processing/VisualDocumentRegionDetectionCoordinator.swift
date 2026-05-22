import Foundation

struct VisualDocumentRegionDetectionRequest: Equatable {
    let snapshotID: UUID
    let runID: UUID

    init(snapshotID: UUID, runID: UUID = UUID()) {
        self.snapshotID = snapshotID
        self.runID = runID
    }
}

struct VisualDocumentRegionDetectionCoordinator: Equatable {
    static let analyzingMessage = "Looking for stamps, signatures, and non-text marks locally."

    private(set) var regions: [VisualDocumentRegion] = []
    private(set) var message: String?
    private var snapshotID: UUID?
    private var runID: UUID?

    mutating func begin(snapshotID: UUID) -> VisualDocumentRegionDetectionRequest {
        let request = VisualDocumentRegionDetectionRequest(snapshotID: snapshotID)
        self.snapshotID = request.snapshotID
        self.runID = request.runID
        self.regions = []
        self.message = Self.analyzingMessage
        return request
    }

    mutating func complete(_ request: VisualDocumentRegionDetectionRequest, regions: [VisualDocumentRegion]) {
        guard isCurrent(request) else {
            return
        }

        self.regions = regions
        self.message = nil
    }

    mutating func clear() {
        snapshotID = nil
        runID = nil
        regions = []
        message = nil
    }

    func regions(for snapshotID: UUID) -> [VisualDocumentRegion] {
        guard self.snapshotID == snapshotID else {
            return []
        }

        return regions
    }

    private func isCurrent(_ request: VisualDocumentRegionDetectionRequest) -> Bool {
        snapshotID == request.snapshotID && runID == request.runID
    }
}
