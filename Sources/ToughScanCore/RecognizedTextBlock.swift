public struct RecognizedTextBlock: Equatable, Sendable {
    public let text: String
    public let confidence: Double
    public let languageCode: String
    public let tileCoordinates: [TileCoordinate]

    public init(
        text: String,
        confidence: Double,
        languageCode: String,
        tileCoordinates: [TileCoordinate]
    ) {
        self.text = text
        self.confidence = confidence.clampedToConfidenceRange
        self.languageCode = languageCode
        self.tileCoordinates = tileCoordinates
    }
}

