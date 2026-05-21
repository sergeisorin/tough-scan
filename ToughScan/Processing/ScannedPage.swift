import Foundation
import ToughScanCore

struct ScannedPage: Identifiable {
    let id: UUID
    let snapshot: DocumentSnapshot
    let recognizedTextBlocks: [RecognizedTextBlock]

    init(
        id: UUID = UUID(),
        snapshot: DocumentSnapshot,
        recognizedTextBlocks: [RecognizedTextBlock]
    ) {
        self.id = id
        self.snapshot = snapshot
        self.recognizedTextBlocks = recognizedTextBlocks
    }
}

