public struct TileConfidenceMap: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var tiles: [ScanTile]

    public init(width: Int, height: Int) {
        precondition(width > 0, "TileConfidenceMap width must be positive")
        precondition(height > 0, "TileConfidenceMap height must be positive")

        self.width = width
        self.height = height
        self.tiles = (0..<height).flatMap { row in
            (0..<width).map { column in
                ScanTile(coordinate: TileCoordinate(column: column, row: row))
            }
        }
    }

    public func tile(at coordinate: TileCoordinate) -> ScanTile {
        guard let index = index(for: coordinate) else {
            preconditionFailure("Tile coordinate is outside the confidence map")
        }

        return tiles[index]
    }

    public mutating func updateTile(
        at coordinate: TileCoordinate,
        visualQuality: Double,
        ocrConfidence: Double,
        textCoverage: Double
    ) {
        guard let index = index(for: coordinate) else {
            return
        }

        let candidate = ScanTile(
            coordinate: coordinate,
            visualQuality: visualQuality,
            ocrConfidence: ocrConfidence,
            textCoverage: textCoverage
        )

        if candidate.combinedConfidence > tiles[index].combinedConfidence {
            tiles[index] = candidate
        }
    }

    public func weakestTiles(limit: Int) -> [ScanTile] {
        guard limit > 0 else {
            return []
        }

        return tiles
            .sorted { lhs, rhs in
                if lhs.state != rhs.state {
                    return lhs.state < rhs.state
                }

                if lhs.combinedConfidence != rhs.combinedConfidence {
                    return lhs.combinedConfidence < rhs.combinedConfidence
                }

                if lhs.coordinate.row != rhs.coordinate.row {
                    return lhs.coordinate.row < rhs.coordinate.row
                }

                return lhs.coordinate.column < rhs.coordinate.column
            }
            .prefix(limit)
            .map { $0 }
    }

    private func index(for coordinate: TileCoordinate) -> Int? {
        guard coordinate.column >= 0,
              coordinate.column < width,
              coordinate.row >= 0,
              coordinate.row < height else {
            return nil
        }

        return (coordinate.row * width) + coordinate.column
    }
}

