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
        testVisionRegionMapsToExpectedTile()
        testRegionSpanningTilesMapsToEveryTouchedTile()
        testMappingAggregatesTileEvidence()
        testValidDocumentQuadIsAccepted()
        testTinyDocumentQuadIsRejected()
        testGeometryStabilizerSmoothsSmallMovement()
        testGeometryStabilizerRejectsSuddenOutlier()

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

private func testVisionRegionMapsToExpectedTile() {
    let mapper = TileEvidenceMapper(gridWidth: 4, gridHeight: 4)
    let region = NormalizedTextRegion(
        text: "Top right",
        confidence: 0.91,
        languageCode: "en",
        boundingBox: NormalizedRect(x: 0.76, y: 0.76, width: 0.18, height: 0.18)
    )

    let result = mapper.map(regions: [region], visualQuality: 0.80)

    expect(result.recognizedTextBlocks.first?.tileCoordinates == [TileCoordinate(column: 3, row: 0)])
    expect(result.tileEvidence.first?.coordinate == TileCoordinate(column: 3, row: 0))
}

private func testRegionSpanningTilesMapsToEveryTouchedTile() {
    let mapper = TileEvidenceMapper(gridWidth: 4, gridHeight: 4)
    let region = NormalizedTextRegion(
        text: "Center",
        confidence: 0.77,
        languageCode: "en",
        boundingBox: NormalizedRect(x: 0.45, y: 0.45, width: 0.20, height: 0.20)
    )

    let result = mapper.map(regions: [region], visualQuality: 0.72)
    let touchedTiles = result.recognizedTextBlocks.first?.tileCoordinates ?? []

    expect(touchedTiles == [
        TileCoordinate(column: 1, row: 1),
        TileCoordinate(column: 2, row: 1),
        TileCoordinate(column: 1, row: 2),
        TileCoordinate(column: 2, row: 2)
    ])
}

private func testMappingAggregatesTileEvidence() {
    let mapper = TileEvidenceMapper(gridWidth: 2, gridHeight: 2)
    let regions = [
        NormalizedTextRegion(
            text: "weak",
            confidence: 0.42,
            languageCode: "en",
            boundingBox: NormalizedRect(x: 0.05, y: 0.55, width: 0.20, height: 0.20)
        ),
        NormalizedTextRegion(
            text: "strong",
            confidence: 0.86,
            languageCode: "en",
            boundingBox: NormalizedRect(x: 0.10, y: 0.60, width: 0.25, height: 0.25)
        )
    ]

    let result = mapper.map(regions: regions, visualQuality: 0.75)
    let evidence = result.tileEvidence.first { $0.coordinate == TileCoordinate(column: 0, row: 0) }

    expect(evidence?.ocrConfidence == 0.86)
    expect((evidence?.textCoverage ?? 0) > 0.10)
    expect(evidence?.visualQuality == 0.75)
}

private func testValidDocumentQuadIsAccepted() {
    let quad = DocumentQuad(
        topLeft: NormalizedPoint(x: 0.12, y: 0.15),
        topRight: NormalizedPoint(x: 0.88, y: 0.14),
        bottomRight: NormalizedPoint(x: 0.90, y: 0.86),
        bottomLeft: NormalizedPoint(x: 0.10, y: 0.88)
    )

    expect(quad.isValidDocumentShape)
    expect(quad.area > 0.50)
}

private func testTinyDocumentQuadIsRejected() {
    let quad = DocumentQuad(
        topLeft: NormalizedPoint(x: 0.48, y: 0.48),
        topRight: NormalizedPoint(x: 0.52, y: 0.48),
        bottomRight: NormalizedPoint(x: 0.52, y: 0.52),
        bottomLeft: NormalizedPoint(x: 0.48, y: 0.52)
    )

    expect(!quad.isValidDocumentShape)
}

private func testGeometryStabilizerSmoothsSmallMovement() {
    var stabilizer = DocumentGeometryStabilizer(smoothingFactor: 0.50, maxCornerJump: 0.25)
    let first = DocumentGeometryObservation(
        quad: DocumentQuad.unit,
        confidence: 0.90
    )
    let moved = DocumentGeometryObservation(
        quad: DocumentQuad(
            topLeft: NormalizedPoint(x: 0.04, y: 0.02),
            topRight: NormalizedPoint(x: 0.96, y: 0.02),
            bottomRight: NormalizedPoint(x: 0.96, y: 0.98),
            bottomLeft: NormalizedPoint(x: 0.04, y: 0.98)
        ),
        confidence: 0.92
    )

    let initial = stabilizer.update(with: first)
    let smoothed = stabilizer.update(with: moved)

    expect(initial?.quad == DocumentQuad.unit)
    expect(isClose(smoothed?.quad.topLeft.x, 0.02))
    expect(isClose(smoothed?.quad.topLeft.y, 0.01))
}

private func testGeometryStabilizerRejectsSuddenOutlier() {
    var stabilizer = DocumentGeometryStabilizer(smoothingFactor: 0.50, maxCornerJump: 0.10)
    let first = DocumentGeometryObservation(
        quad: DocumentQuad.unit,
        confidence: 0.90
    )
    let outlier = DocumentGeometryObservation(
        quad: DocumentQuad(
            topLeft: NormalizedPoint(x: 0.70, y: 0.70),
            topRight: NormalizedPoint(x: 0.98, y: 0.70),
            bottomRight: NormalizedPoint(x: 0.98, y: 0.98),
            bottomLeft: NormalizedPoint(x: 0.70, y: 0.98)
        ),
        confidence: 0.93
    )

    _ = stabilizer.update(with: first)
    let stableAfterOutlier = stabilizer.update(with: outlier)

    expect(stableAfterOutlier?.quad == DocumentQuad.unit)
}

private func expect(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    guard condition() else {
        fatalError("Check failed", file: file, line: line)
    }
}

private func isClose(_ value: Double?, _ expected: Double, tolerance: Double = 0.0001) -> Bool {
    guard let value else {
        return false
    }

    return abs(value - expected) <= tolerance
}

