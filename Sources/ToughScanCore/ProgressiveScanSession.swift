public struct ProgressiveScanSession: Equatable, Sendable {
    public private(set) var confidenceMap: TileConfidenceMap
    public private(set) var recognizedTextBlocks: [RecognizedTextBlock]

    public init(gridWidth: Int, gridHeight: Int) {
        self.confidenceMap = TileConfidenceMap(width: gridWidth, height: gridHeight)
        self.recognizedTextBlocks = []
    }

    public mutating func addFrame(_ observation: FrameObservation) {
        for evidence in observation.tileEvidence {
            confidenceMap.updateTile(
                at: evidence.coordinate,
                visualQuality: evidence.visualQuality,
                ocrConfidence: evidence.ocrConfidence,
                textCoverage: evidence.textCoverage
            )
        }

        recognizedTextBlocks.append(contentsOf: observation.recognizedTextBlocks)
    }

    public func guidanceSuggestion() -> ScanTile? {
        confidenceMap.weakestTiles(limit: 1).first
    }
}

