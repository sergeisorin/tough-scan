import CoreGraphics
import ToughScanCore

struct VisualDocumentRegionCandidateFilter {
    let minimumInkPixels: Int
    let maximumRegionCoverage: CGFloat

    func makeRegion(
        from component: VisualInkComponent,
        bitmap: VisualDocumentBitmap
    ) -> VisualDocumentRegion? {
        guard component.pixelCount >= minimumInkPixels else {
            return nil
        }

        let rect = component.pixelRect
        let width = rect.width
        let height = rect.height
        guard width >= 8, height >= 8 else {
            return nil
        }

        let imageArea = CGFloat(bitmap.width * bitmap.height)
        guard (width * height) / imageArea <= maximumRegionCoverage else {
            return nil
        }

        let aspectRatio = width / max(height, 1)
        if aspectRatio > 8, height / CGFloat(bitmap.height) < 0.04 {
            return nil
        }

        let normalizedRect = NormalizedRect(
            x: rect.minX / CGFloat(bitmap.width),
            y: rect.minY / CGFloat(bitmap.height),
            width: rect.width / CGFloat(bitmap.width),
            height: rect.height / CGFloat(bitmap.height)
        )

        guard let croppedImage = bitmap.croppedImage(to: rect) else {
            return nil
        }

        let density = Double(component.pixelCount) / Double(max(1, Int(width * height)))
        let shapeConfidence = min(1, max(0.35, density * 2.5))

        return VisualDocumentRegion(
            kind: .stampOrSignature,
            boundingBox: normalizedRect,
            confidence: shapeConfidence,
            image: croppedImage
        )
    }
}
