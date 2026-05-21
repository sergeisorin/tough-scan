public struct NormalizedRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var area: Double { max(0, width) * max(0, height) }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x.clampedToConfidenceRange
        self.y = y.clampedToConfidenceRange
        self.width = min(max(width, 0), 1 - self.x)
        self.height = min(max(height, 0), 1 - self.y)
    }

    func intersectionArea(with other: NormalizedRect) -> Double {
        let intersectionWidth = max(0, min(maxX, other.maxX) - max(minX, other.minX))
        let intersectionHeight = max(0, min(maxY, other.maxY) - max(minY, other.minY))
        return intersectionWidth * intersectionHeight
    }
}

public struct NormalizedTextRegion: Equatable, Sendable {
    public let text: String
    public let confidence: Double
    public let languageCode: String
    public let boundingBox: NormalizedRect

    public init(
        text: String,
        confidence: Double,
        languageCode: String,
        boundingBox: NormalizedRect
    ) {
        self.text = text
        self.confidence = confidence.clampedToConfidenceRange
        self.languageCode = languageCode
        self.boundingBox = boundingBox
    }
}

public struct TileEvidenceMappingResult: Equatable, Sendable {
    public let tileEvidence: [TileEvidence]
    public let recognizedTextBlocks: [RecognizedTextBlock]

    public init(tileEvidence: [TileEvidence], recognizedTextBlocks: [RecognizedTextBlock]) {
        self.tileEvidence = tileEvidence
        self.recognizedTextBlocks = recognizedTextBlocks
    }
}

public struct TileEvidenceMapper: Sendable {
    public let gridWidth: Int
    public let gridHeight: Int

    public init(gridWidth: Int, gridHeight: Int) {
        precondition(gridWidth > 0, "TileEvidenceMapper gridWidth must be positive")
        precondition(gridHeight > 0, "TileEvidenceMapper gridHeight must be positive")

        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
    }

    public func map(
        regions: [NormalizedTextRegion],
        visualQuality: Double
    ) -> TileEvidenceMappingResult {
        var evidenceByCoordinate = Dictionary(
            uniqueKeysWithValues: allTileCoordinates().map { coordinate in
                (coordinate, TileAccumulator())
            }
        )
        var blocks: [RecognizedTextBlock] = []

        for region in regions where !region.text.isEmpty && region.boundingBox.area > 0 {
            let touchedTiles = tileCoordinates(touchedBy: region.boundingBox)

            guard !touchedTiles.isEmpty else {
                continue
            }

            blocks.append(
                RecognizedTextBlock(
                    text: region.text,
                    confidence: region.confidence,
                    languageCode: region.languageCode,
                    tileCoordinates: touchedTiles,
                    boundingBox: region.boundingBox
                )
            )

            for coordinate in touchedTiles {
                let coverage = coverageOfTile(coordinate, by: region.boundingBox)
                evidenceByCoordinate[coordinate, default: TileAccumulator()].add(
                    ocrConfidence: region.confidence,
                    textCoverage: coverage
                )
            }
        }

        let evidence = evidenceByCoordinate
            .map { coordinate, accumulator in
                TileEvidence(
                    coordinate: coordinate,
                    visualQuality: visualQuality,
                    ocrConfidence: accumulator.maxOCRConfidence,
                    textCoverage: accumulator.textCoverage
                )
            }
            .sorted { lhs, rhs in
                if lhs.coordinate.row != rhs.coordinate.row {
                    return lhs.coordinate.row < rhs.coordinate.row
                }

                return lhs.coordinate.column < rhs.coordinate.column
            }

        return TileEvidenceMappingResult(tileEvidence: evidence, recognizedTextBlocks: blocks)
    }

    public func tileCoordinates(touchedBy visionBoundingBox: NormalizedRect) -> [TileCoordinate] {
        let topLeftBox = convertVisionBoxToTopLeftGrid(visionBoundingBox)

        return allTileCoordinates().filter { coordinate in
            tileRect(for: coordinate).intersectionArea(with: topLeftBox) > 0
        }
    }

    private func coverageOfTile(_ coordinate: TileCoordinate, by visionBoundingBox: NormalizedRect) -> Double {
        let topLeftBox = convertVisionBoxToTopLeftGrid(visionBoundingBox)
        let tile = tileRect(for: coordinate)
        return (tile.intersectionArea(with: topLeftBox) / tile.area).clampedToConfidenceRange
    }

    private func convertVisionBoxToTopLeftGrid(_ box: NormalizedRect) -> NormalizedRect {
        NormalizedRect(
            x: box.x,
            y: 1 - box.y - box.height,
            width: box.width,
            height: box.height
        )
    }

    private func allTileCoordinates() -> [TileCoordinate] {
        (0..<gridHeight).flatMap { row in
            (0..<gridWidth).map { column in
                TileCoordinate(column: column, row: row)
            }
        }
    }

    private func tileRect(for coordinate: TileCoordinate) -> NormalizedRect {
        let tileWidth = 1 / Double(gridWidth)
        let tileHeight = 1 / Double(gridHeight)

        return NormalizedRect(
            x: Double(coordinate.column) * tileWidth,
            y: Double(coordinate.row) * tileHeight,
            width: tileWidth,
            height: tileHeight
        )
    }
}

private struct TileAccumulator {
    private(set) var maxOCRConfidence: Double = 0
    private(set) var textCoverage: Double = 0

    mutating func add(ocrConfidence: Double, textCoverage: Double) {
        maxOCRConfidence = max(maxOCRConfidence, ocrConfidence.clampedToConfidenceRange)
        self.textCoverage = min(1, self.textCoverage + textCoverage.clampedToConfidenceRange)
    }
}

