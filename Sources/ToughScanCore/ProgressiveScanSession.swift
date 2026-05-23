public struct ProgressiveScanSession: Equatable, Sendable {
    public private(set) var confidenceMap: TileConfidenceMap
    public private(set) var recognizedTextBlocks: [RecognizedTextBlock]
    public private(set) var recognizedWords: [RecognizedWord]
    private let readinessThresholds: ScanReadinessThresholds

    public init(
        gridWidth: Int,
        gridHeight: Int,
        readinessThresholds: ScanReadinessThresholds = .default
    ) {
        self.confidenceMap = TileConfidenceMap(width: gridWidth, height: gridHeight)
        self.recognizedTextBlocks = []
        self.recognizedWords = []
        self.readinessThresholds = readinessThresholds
    }

    public var isReadyForReview: Bool {
        if !recognizedWords.isEmpty {
            return wordEvidenceSummary.isReadyForReview && confidenceMap.tiles.allSatisfy(isReviewableForWordReadiness)
        }

        return confidenceMap.tiles.allSatisfy(isReviewable)
    }

    public var wordEvidenceSummary: WordEvidenceSummary {
        WordEvidenceSummary(words: recognizedWords)
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

        for word in observation.recognizedWords {
            mergeRecognizedWord(word)
        }
    }

    public func guidanceSuggestion() -> ScanTile? {
        confidenceMap.weakestTiles(limit: 1).first
    }

    public func scanGuidance() -> ScanGuidance {
        if isReadyForReview {
            return ScanGuidance(
                action: .readyForReview,
                targetTile: nil,
                readyForReview: true
            )
        }

        if let weakWord = weakestWord(where: { $0.state <= .veryUncertain }) {
            return ScanGuidance(
                action: .rescanWeakText,
                targetTile: tileTarget(for: weakWord),
                targetWord: weakWord,
                readyForReview: false
            )
        }

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

        return ScanGuidance(
            action: .holdSteady,
            targetTile: guidanceSuggestion(),
            readyForReview: false
        )
    }

    private func weakestTile(where isIncluded: (ScanTile) -> Bool) -> ScanTile? {
        confidenceMap
            .weakestTiles(limit: confidenceMap.tiles.count)
            .first(where: isIncluded)
    }

    private func weakestWord(where isIncluded: (RecognizedWord) -> Bool) -> RecognizedWord? {
        recognizedWords
            .filter(isIncluded)
            .sorted { lhs, rhs in
                if lhs.state != rhs.state {
                    return lhs.state < rhs.state
                }

                if lhs.confidence != rhs.confidence {
                    return lhs.confidence < rhs.confidence
                }

                return lhs.text < rhs.text
            }
            .first
    }

    private func tileTarget(for word: RecognizedWord) -> ScanTile? {
        word.tileCoordinates
            .compactMap { coordinate in
                confidenceMap.tiles.first { $0.coordinate == coordinate }
            }
            .sorted { lhs, rhs in
                if lhs.state != rhs.state {
                    return lhs.state < rhs.state
                }

                return lhs.combinedConfidence < rhs.combinedConfidence
            }
            .first ?? guidanceSuggestion()
    }

    private func isReviewable(_ tile: ScanTile) -> Bool {
        tile.state == .successful ||
            tile.state == .uncertain ||
            isVisuallyCoveredBlankRegion(tile)
    }

    private func isReviewableForWordReadiness(_ tile: ScanTile) -> Bool {
        tile.state != .needsScan || isVisuallyCoveredBlankRegion(tile)
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

    private mutating func mergeRecognizedWord(_ word: RecognizedWord) {
        guard let existingIndex = recognizedWords.firstIndex(where: { existing in
            isSameWordSlot(existing, word)
        }) else {
            recognizedWords.append(word)
            return
        }

        let existingWord = recognizedWords[existingIndex]
        if word.confidence > existingWord.confidence ||
            (isSameWordSlot(existingWord, word) && isUsefulCorrection(word, over: existingWord)) {
            recognizedWords[existingIndex] = word
        }
    }

    private func isUsefulCorrection(_ candidate: RecognizedWord, over existing: RecognizedWord) -> Bool {
        guard candidate.text != existing.text,
              candidate.confidence >= existing.confidence - 0.10 else {
            return false
        }

        return textQualityScore(candidate.text) >= textQualityScore(existing.text)
    }

    private func textQualityScore(_ text: String) -> Int {
        text.reduce(0) { score, character in
            if character == "▯" || character == "▮" || character == "…" {
                return score - 2
            }

            if character.isLetter || character.isNumber {
                return score + 1
            }

            return score
        }
    }

    private func isSameWordSlot(_ lhs: RecognizedWord, _ rhs: RecognizedWord) -> Bool {
        guard lhs.languageCode == rhs.languageCode,
              !Set(lhs.tileCoordinates).isDisjoint(with: Set(rhs.tileCoordinates)) else {
            return false
        }

        let overlap = lhs.boundingBox.intersectionArea(with: rhs.boundingBox)
        let smallerArea = min(lhs.boundingBox.area, rhs.boundingBox.area)

        guard smallerArea > 0 else {
            return false
        }

        return overlap / smallerArea >= 0.50
    }
}

