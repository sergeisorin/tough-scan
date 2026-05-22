import CoreGraphics
import ToughScanCore

struct VisualDocumentOCRExclusionMask {
    let textBoxExpansion: Double

    func excludedRects(for textBlocks: [RecognizedTextBlock], in size: CGSize) -> [CGRect] {
        textBlocks
            .compactMap(\.boundingBox)
            .map { expandedPixelRect(for: $0, in: size) }
    }

    private func expandedPixelRect(for rect: NormalizedRect, in size: CGSize) -> CGRect {
        let expanded = NormalizedRect(
            x: max(0, rect.x - textBoxExpansion),
            y: max(0, rect.y - textBoxExpansion),
            width: min(1, rect.width + (textBoxExpansion * 2)),
            height: min(1, rect.height + (textBoxExpansion * 2))
        )

        return expanded.pixelRect(in: size, from: .visionBottomLeft)
    }
}
