import Foundation

public struct RecognizedWord: Equatable, Sendable {
    public let text: String
    public let confidence: Double
    public let languageCode: String
    public let tileCoordinates: [TileCoordinate]
    public let boundingBox: NormalizedRect
    public let lineText: String?
    public let lineBoundingBox: NormalizedRect?

    public var state: ScanConfidenceState {
        ScanConfidenceState.state(for: confidence)
    }

    public init(
        text: String,
        confidence: Double,
        languageCode: String,
        tileCoordinates: [TileCoordinate],
        boundingBox: NormalizedRect,
        lineText: String? = nil,
        lineBoundingBox: NormalizedRect? = nil
    ) {
        self.text = text
        self.confidence = confidence.clampedToConfidenceRange
        self.languageCode = languageCode
        self.tileCoordinates = tileCoordinates
        self.boundingBox = boundingBox
        self.lineText = lineText
        self.lineBoundingBox = lineBoundingBox
    }

}

public struct WordEvidenceSummary: Equatable, Sendable {
    public let totalCount: Int
    public let successfulCount: Int
    public let reviewCount: Int
    public let rescanCount: Int
    public let neededCount: Int

    public var isReadyForReview: Bool {
        let minimumSuccessfulCount = max(
            Int((Double(totalCount) * 0.70).rounded(.up)),
            totalCount - 4,
            1
        )

        return totalCount > 0 &&
            neededCount == 0 &&
            (successfulCount + reviewCount) >= minimumSuccessfulCount
    }

    public init(words: [RecognizedWord]) {
        totalCount = words.count
        successfulCount = words.filter { $0.state == .successful }.count
        reviewCount = words.filter { $0.state == .uncertain }.count
        rescanCount = words.filter { $0.state == .veryUncertain }.count
        neededCount = words.filter { $0.state == .needsScan }.count
    }
}

