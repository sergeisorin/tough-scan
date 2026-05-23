import Foundation
import ToughScanCore

struct ScannedPage: Identifiable {
    let id: UUID
    let snapshot: DocumentSnapshot
    let recognizedTextBlocks: [RecognizedTextBlock]
    let recognizedWords: [RecognizedWord]
    let confirmedWords: [ConfirmedRecognizedWord]
    let structuredDocument: StructuredDocument?
    let visualRegions: [VisualDocumentRegion]

    init(
        id: UUID = UUID(),
        snapshot: DocumentSnapshot,
        recognizedTextBlocks: [RecognizedTextBlock],
        recognizedWords: [RecognizedWord] = [],
        confirmedWords: [ConfirmedRecognizedWord] = [],
        structuredDocument: StructuredDocument? = nil,
        visualRegions: [VisualDocumentRegion] = []
    ) {
        self.id = id
        self.snapshot = snapshot
        self.recognizedTextBlocks = recognizedTextBlocks
        self.recognizedWords = recognizedWords
        self.confirmedWords = confirmedWords
        self.structuredDocument = structuredDocument
        self.visualRegions = visualRegions
    }
}

struct ConfirmedRecognizedWord: Equatable {
    let word: RecognizedWord
    let resolvedText: String
}

