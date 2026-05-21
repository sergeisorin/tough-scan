import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import ToughScanCore

protocol PerspectiveNormalizing {
    func normalize(_ image: CIImage, quad: DocumentQuad) -> CIImage?
}

final class PerspectiveNormalizer: PerspectiveNormalizing {
    func normalize(_ image: CIImage, quad: DocumentQuad) -> CIImage? {
        guard quad.isValidDocumentShape else {
            return nil
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = image
        filter.topLeft = quad.topLeft.cgPoint(in: image.extent)
        filter.topRight = quad.topRight.cgPoint(in: image.extent)
        filter.bottomRight = quad.bottomRight.cgPoint(in: image.extent)
        filter.bottomLeft = quad.bottomLeft.cgPoint(in: image.extent)

        return filter.outputImage
    }
}

private extension NormalizedPoint {
    func cgPoint(in extent: CGRect) -> CGPoint {
        CGPoint(
            x: extent.minX + (x * extent.width),
            y: extent.maxY - (y * extent.height)
        )
    }
}

