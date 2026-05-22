public struct TileConfidenceScoring: Equatable, Sendable {
    public static let `default` = TileConfidenceScoring(
        visualQualityWeight: 0.45,
        ocrConfidenceWeight: 0.40,
        textCoverageWeight: 0.15
    )

    public let visualQualityWeight: Double
    public let ocrConfidenceWeight: Double
    public let textCoverageWeight: Double

    public init(
        visualQualityWeight: Double,
        ocrConfidenceWeight: Double,
        textCoverageWeight: Double
    ) {
        self.visualQualityWeight = visualQualityWeight
        self.ocrConfidenceWeight = ocrConfidenceWeight
        self.textCoverageWeight = textCoverageWeight
    }

    public func combinedConfidence(for tile: ScanTile) -> Double {
        (tile.visualQuality * visualQualityWeight) +
            (tile.ocrConfidence * ocrConfidenceWeight) +
            (tile.textCoverage * textCoverageWeight)
    }
}

public struct ScanReadinessThresholds: Equatable, Sendable {
    public static let `default` = ScanReadinessThresholds(
        minimumVisualQualityForBlankRegion: 0.65
    )

    public let minimumVisualQualityForBlankRegion: Double

    public init(minimumVisualQualityForBlankRegion: Double) {
        self.minimumVisualQualityForBlankRegion = minimumVisualQualityForBlankRegion.clampedToConfidenceRange
    }
}
