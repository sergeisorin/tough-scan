public struct ScanTile: Equatable, Sendable {
    public let coordinate: TileCoordinate
    public let visualQuality: Double
    public let ocrConfidence: Double
    public let textCoverage: Double

    public var combinedConfidence: Double {
        TileConfidenceScoring.default.combinedConfidence(for: self)
    }

    public var state: ScanConfidenceState {
        ScanConfidenceState.state(for: combinedConfidence)
    }

    public init(
        coordinate: TileCoordinate,
        visualQuality: Double = 0,
        ocrConfidence: Double = 0,
        textCoverage: Double = 0
    ) {
        self.coordinate = coordinate
        self.visualQuality = visualQuality.clampedToConfidenceRange
        self.ocrConfidence = ocrConfidence.clampedToConfidenceRange
        self.textCoverage = textCoverage.clampedToConfidenceRange
    }
}

extension Double {
    var clampedToConfidenceRange: Double {
        min(max(self, 0), 1)
    }
}

