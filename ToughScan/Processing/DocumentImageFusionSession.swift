import ToughScanCore
import UIKit

struct DocumentImageFusionSession {
    private let gridWidth: Int
    private let gridHeight: Int
    private var bestPatchesByCoordinate: [TileCoordinate: TileImagePatch] = [:]

    init(gridWidth: Int, gridHeight: Int) {
        precondition(gridWidth > 0, "DocumentImageFusionSession gridWidth must be positive")
        precondition(gridHeight > 0, "DocumentImageFusionSession gridHeight must be positive")

        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
    }

    mutating func add(_ snapshot: DocumentSnapshot) -> DocumentSnapshot? {
        guard let cgImage = snapshot.image.cgImage,
              !snapshot.tileEvidence.isEmpty else {
            return snapshot
        }

        for evidence in snapshot.tileEvidence where contains(evidence.coordinate) {
            guard let croppedImage = cropTileImage(
                from: cgImage,
                scale: snapshot.image.scale,
                coordinate: evidence.coordinate
            ) else {
                continue
            }

            let patch = TileImagePatch(
                coordinate: evidence.coordinate,
                image: croppedImage,
                evidence: evidence,
                score: score(for: evidence)
            )

            if patch.score > (bestPatchesByCoordinate[evidence.coordinate]?.score ?? -1) {
                bestPatchesByCoordinate[evidence.coordinate] = patch
            }
        }

        guard !bestPatchesByCoordinate.isEmpty else {
            return snapshot
        }

        let fusedImage = makeFusedImage(
            size: snapshot.image.size,
            scale: snapshot.image.scale
        )
        let selectedEvidence = bestPatchesByCoordinate.values
            .sorted(by: sortPatchesByGridPosition)
            .map(\.evidence)
        let fusedScore = selectedEvidence.isEmpty
            ? snapshot.captureScore
            : selectedEvidence
                .map(score(for:))
                .reduce(0, +) / Double(selectedEvidence.count)

        return DocumentSnapshot(
            id: snapshot.id,
            image: fusedImage,
            visualQuality: snapshot.visualQuality,
            captureScore: fusedScore,
            averageOCRConfidence: snapshot.averageOCRConfidence,
            textCoverage: snapshot.textCoverage,
            tileEvidence: selectedEvidence,
            createdAt: snapshot.createdAt
        )
    }

    private func cropTileImage(
        from image: CGImage,
        scale: CGFloat,
        coordinate: TileCoordinate
    ) -> UIImage? {
        guard let cropped = image.cropping(to: pixelRect(for: coordinate, in: image).integral) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: scale, orientation: .up)
    }

    private func makeFusedImage(size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            for patch in bestPatchesByCoordinate.values.sorted(by: sortPatchesByGridPosition) {
                patch.image.draw(in: pointRect(for: patch.coordinate, in: size))
            }
        }
    }

    private func score(for evidence: TileEvidence) -> Double {
        ScanTile(
            coordinate: evidence.coordinate,
            visualQuality: evidence.visualQuality,
            ocrConfidence: evidence.ocrConfidence,
            textCoverage: evidence.textCoverage
        )
        .combinedConfidence
    }

    private func contains(_ coordinate: TileCoordinate) -> Bool {
        coordinate.column >= 0 &&
            coordinate.column < gridWidth &&
            coordinate.row >= 0 &&
            coordinate.row < gridHeight
    }

    private func pixelRect(for coordinate: TileCoordinate, in image: CGImage) -> CGRect {
        rect(
            for: coordinate,
            width: CGFloat(image.width),
            height: CGFloat(image.height)
        )
    }

    private func pointRect(for coordinate: TileCoordinate, in size: CGSize) -> CGRect {
        rect(for: coordinate, width: size.width, height: size.height)
    }

    private func rect(for coordinate: TileCoordinate, width: CGFloat, height: CGFloat) -> CGRect {
        let tileWidth = width / CGFloat(gridWidth)
        let tileHeight = height / CGFloat(gridHeight)
        let x = CGFloat(coordinate.column) * tileWidth
        let y = CGFloat(coordinate.row) * tileHeight
        let maxX = coordinate.column == gridWidth - 1 ? width : x + tileWidth
        let maxY = coordinate.row == gridHeight - 1 ? height : y + tileHeight

        return CGRect(
            x: x,
            y: y,
            width: maxX - x,
            height: maxY - y
        )
    }

    private func sortPatchesByGridPosition(_ lhs: TileImagePatch, _ rhs: TileImagePatch) -> Bool {
        if lhs.coordinate.row != rhs.coordinate.row {
            return lhs.coordinate.row < rhs.coordinate.row
        }

        return lhs.coordinate.column < rhs.coordinate.column
    }
}

private struct TileImagePatch {
    let coordinate: TileCoordinate
    let image: UIImage
    let evidence: TileEvidence
    let score: Double
}
