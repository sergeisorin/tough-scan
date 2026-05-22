import Foundation
import ToughScanCore

struct ScannedPage: Identifiable {
    let id: UUID
    let snapshot: DocumentSnapshot
    let recognizedTextBlocks: [RecognizedTextBlock]
    let structuredDocument: StructuredDocument?
    let visualRegions: [VisualDocumentRegion]

    init(
        id: UUID = UUID(),
        snapshot: DocumentSnapshot,
        recognizedTextBlocks: [RecognizedTextBlock],
        structuredDocument: StructuredDocument? = nil,
        visualRegions: [VisualDocumentRegion] = []
    ) {
        self.id = id
        self.snapshot = snapshot
        self.recognizedTextBlocks = recognizedTextBlocks
        self.structuredDocument = structuredDocument
        self.visualRegions = visualRegions
    }
}

