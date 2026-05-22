public struct ProgressiveScanSession: Equatable, Sendable {
    public private(set) var confidenceMap: TileConfidenceMap
    public private(set) var recognizedTextBlocks: [RecognizedTextBlock]
    private let readinessThresholds: ScanReadinessThresholds

    public init(
        gridWidth: Int,
        gridHeight: Int,
        readinessThresholds: ScanReadinessThresholds = .default
    ) {
        self.confidenceMap = TileConfidenceMap(width: gridWidth, height: gridHeight)
        self.recognizedTextBlocks = []
        self.readinessThresholds = readinessThresholds
    }

    public var isReadyForReview: Bool {
        confidenceMap.tiles.allSatisfy(isReviewable)
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

        for block in observation.recognizedTextBlocks {
            mergeRecognizedTextBlock(block)
        }
    }

    public func guidanceSuggestion() -> ScanTile? {
        confidenceMap.weakestTiles(limit: 1).first
    }

    public func scanGuidance() -> ScanGuidance {
        if let missingTile = weakestTile(where: isMissing) {
            return ScanGuidance(
                action: .scanMissingRegion,
                targetTile: missingTile,
                readyForReview: false
            )
        }

        if let veryUncertainTile = weakestTile(where: isWeakText) {
            return ScanGuidance(
                action: .rescanWeakText,
                targetTile: veryUncertainTile,
                readyForReview: false
            )
        }

        guard isReadyForReview else {
            return ScanGuidance(
                action: .holdSteady,
                targetTile: guidanceSuggestion(),
                readyForReview: false
            )
        }

        return ScanGuidance(
            action: .readyForReview,
            targetTile: nil,
            readyForReview: true
        )
    }

    private func weakestTile(where isIncluded: (ScanTile) -> Bool) -> ScanTile? {
        confidenceMap
            .weakestTiles(limit: confidenceMap.tiles.count)
            .first(where: isIncluded)
    }

    private func isReviewable(_ tile: ScanTile) -> Bool {
        tile.state == .successful ||
            tile.state == .uncertain ||
            isVisuallyCoveredBlankRegion(tile)
    }

    private func isMissing(_ tile: ScanTile) -> Bool {
        tile.state == .needsScan ||
            (isBlankRegion(tile) && tile.visualQuality < readinessThresholds.minimumVisualQualityForBlankRegion)
    }

    private func isWeakText(_ tile: ScanTile) -> Bool {
        tile.state == .veryUncertain && !isBlankRegion(tile)
    }

    private func isVisuallyCoveredBlankRegion(_ tile: ScanTile) -> Bool {
        isBlankRegion(tile) && tile.visualQuality >= readinessThresholds.minimumVisualQualityForBlankRegion
    }

    private func isBlankRegion(_ tile: ScanTile) -> Bool {
        tile.ocrConfidence == 0 && tile.textCoverage == 0
    }

    private mutating func mergeRecognizedTextBlock(_ block: RecognizedTextBlock) {
        guard let existingIndex = recognizedTextBlocks.firstIndex(where: { existing in
            existing.text == block.text &&
                existing.languageCode == block.languageCode &&
                existing.tileCoordinates == block.tileCoordinates
        }) else {
            recognizedTextBlocks.append(block)
            return
        }

        if block.confidence > recognizedTextBlocks[existingIndex].confidence {
            recognizedTextBlocks[existingIndex] = block
        }
    }
}

