import Foundation
import ToughScanCore

struct ScannedPage: Identifiable {
    let id: UUID
    let snapshot: DocumentSnapshot
    let recognizedTextBlocks: [RecognizedTextBlock]
    let structuredDocument: StructuredDocument?

    init(
        id: UUID = UUID(),
        snapshot: DocumentSnapshot,
        recognizedTextBlocks: [RecognizedTextBlock],
        structuredDocument: StructuredDocument? = nil
    ) {
        self.id = id
        self.snapshot = snapshot
        self.recognizedTextBlocks = recognizedTextBlocks
        self.structuredDocument = structuredDocument
    }
}

