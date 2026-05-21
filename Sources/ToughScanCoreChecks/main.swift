import ToughScanCore

@main
struct ToughScanCoreChecks {
    static func main() {
        testTileStateUsesCombinedVisualAndOCRConfidence()
        testWeakestTilesAreRankedWithNeedsScanFirst()
        testUpdatingTileKeepsTheStrongerObservation()
        testSessionStartsWithAllTilesNeedingScan()
        testAddingFrameImprovesCoveredTiles()
        testGuidanceReturnsMostImportantWeakRegion()

        print("ToughScanCoreChecks passed")
    }
}

private func testTileStateUsesCombinedVisualAndOCRConfidence() {
    var map = TileConfidenceMap(width: 2, height: 2)
    let coordinate = TileCoordinate(column: 0, row: 0)

    map.updateTile(
        at: coordinate,
        visualQuality: 0.82,
        ocrConfidence: 0.76,
        textCoverage: 0.62
    )

    expect(map.tile(at: coordinate).state == .successful)
}

private func testWeakestTilesAreRankedWithNeedsScanFirst() {
    var map = TileConfidenceMap(width: 2, height: 2)

    map.updateTile(
        at: TileCoordinate(column: 0, row: 0),
        visualQuality: 0.78,
        ocrConfidence: 0.70,
        textCoverage: 0.50
    )
    map.updateTile(
        at: TileCoordinate(column: 1, row: 0),
        visualQuality: 0.38,
        ocrConfidence: 0.30,
        textCoverage: 0.20
    )

    let weakest = map.weakestTiles(limit: 2)

    expect(weakest.map(\.coordinate) == [
        TileCoordinate(column: 0, row: 1),
        TileCoordinate(column: 1, row: 1)
    ])
    expect(weakest.allSatisfy { $0.state == .needsScan })
}

private func testUpdatingTileKeepsTheStrongerObservation() {
    var map = TileConfidenceMap(width: 1, height: 1)
    let coordinate = TileCoordinate(column: 0, row: 0)

    map.updateTile(
        at: coordinate,
        visualQuality: 0.84,
        ocrConfidence: 0.78,
        textCoverage: 0.65
    )
    map.updateTile(
        at: coordinate,
        visualQuality: 0.20,
        ocrConfidence: 0.12,
        textCoverage: 0.10
    )

    let tile = map.tile(at: coordinate)
    expect(tile.state == .successful)
    expect(tile.combinedConfidence > 0.70)
}

private func testSessionStartsWithAllTilesNeedingScan() {
    let session = ProgressiveScanSession(gridWidth: 3, gridHeight: 2)

    expect(session.confidenceMap.tiles.count == 6)
    expect(session.confidenceMap.tiles.allSatisfy { $0.state == .needsScan })
}

private func testAddingFrameImprovesCoveredTiles() {
    var session = ProgressiveScanSession(gridWidth: 2, gridHeight: 2)

    session.addFrame(
        FrameObservation(
            id: "frame-1",
            tileEvidence: [
                TileEvidence(
                    coordinate: TileCoordinate(column: 1, row: 1),
                    visualQuality: 0.86,
                    ocrConfidence: 0.80,
                    textCoverage: 0.70
                )
            ],
            recognizedTextBlocks: [
                RecognizedTextBlock(
                    text: "שלום",
                    confidence: 0.81,
                    languageCode: "he",
                    tileCoordinates: [TileCoordinate(column: 1, row: 1)]
                )
            ]
        )
    )

    expect(session.confidenceMap.tile(at: TileCoordinate(column: 1, row: 1)).state == .successful)
    expect(session.recognizedTextBlocks.map(\.text) == ["שלום"])
}

private func testGuidanceReturnsMostImportantWeakRegion() {
    var session = ProgressiveScanSession(gridWidth: 2, gridHeight: 1)

    session.addFrame(
        FrameObservation(
            id: "frame-1",
            tileEvidence: [
                TileEvidence(
                    coordinate: TileCoordinate(column: 0, row: 0),
                    visualQuality: 0.54,
                    ocrConfidence: 0.45,
                    textCoverage: 0.30
                )
            ],
            recognizedTextBlocks: []
        )
    )

    expect(session.guidanceSuggestion()?.coordinate == TileCoordinate(column: 1, row: 0))
    expect(session.guidanceSuggestion()?.state == .needsScan)
}

private func expect(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    guard condition() else {
        fatalError("Check failed", file: file, line: line)
    }
}

