public struct TileEvidence: Equatable, Sendable {
    public let coordinate: TileCoordinate
    public let visualQuality: Double
    public let ocrConfidence: Double
    public let textCoverage: Double

    public init(
        coordinate: TileCoordinate,
        visualQuality: Double,
        ocrConfidence: Double,
        textCoverage: Double
    ) {
        self.coordinate = coordinate
        self.visualQuality = visualQuality.clampedToConfidenceRange
        self.ocrConfidence = ocrConfidence.clampedToConfidenceRange
        self.textCoverage = textCoverage.clampedToConfidenceRange
    }
}

public struct FrameObservation: Equatable, Sendable {
    public let id: String
    public let tileEvidence: [TileEvidence]
    public let recognizedTextBlocks: [RecognizedTextBlock]
    public let recognizedWords: [RecognizedWord]

    public init(
        id: String,
        tileEvidence: [TileEvidence],
        recognizedTextBlocks: [RecognizedTextBlock],
        recognizedWords: [RecognizedWord] = []
    ) {
        self.id = id
        self.tileEvidence = tileEvidence
        self.recognizedTextBlocks = recognizedTextBlocks
        self.recognizedWords = recognizedWords
    }
}

