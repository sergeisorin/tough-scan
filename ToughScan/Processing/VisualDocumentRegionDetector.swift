import ToughScanCore
import UIKit

struct VisualDocumentRegionDetector {
    private let inkThreshold: UInt8 = 225
    private let minimumInkPixels = 24
    private let maximumRegionCoverage: CGFloat = 0.45
    private let textBoxExpansion = 0.02

    func detectVisualRegions(
        in image: UIImage,
        textBlocks: [RecognizedTextBlock]
    ) -> [VisualDocumentRegion] {
        guard let bitmap = VisualDocumentBitmap(image: image) else {
            return []
        }

        let excludedRects = VisualDocumentOCRExclusionMask(textBoxExpansion: textBoxExpansion)
            .excludedRects(for: textBlocks, in: bitmap.size)

        let mask = VisualDocumentInkMaskBuilder(inkThreshold: inkThreshold)
            .makeInkMask(from: bitmap, excluding: excludedRects)
        let components = VisualInkComponentFinder()
            .connectedComponents(in: mask, width: bitmap.width, height: bitmap.height)
        let candidateFilter = VisualDocumentRegionCandidateFilter(
            minimumInkPixels: minimumInkPixels,
            maximumRegionCoverage: maximumRegionCoverage
        )

        return components
            .compactMap { component in
                candidateFilter.makeRegion(from: component, bitmap: bitmap)
            }
            .sorted { lhs, rhs in
                if lhs.boundingBox.y != rhs.boundingBox.y {
                    return lhs.boundingBox.y < rhs.boundingBox.y
                }

                return lhs.boundingBox.x < rhs.boundingBox.x
            }
    }
}
