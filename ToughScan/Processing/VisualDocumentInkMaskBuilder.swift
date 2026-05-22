import CoreGraphics
import Foundation

struct VisualDocumentInkMaskBuilder {
    let inkThreshold: UInt8

    func makeInkMask(
        from bitmap: VisualDocumentBitmap,
        excluding excludedRects: [CGRect]
    ) -> [Bool] {
        (0..<(bitmap.width * bitmap.height)).map { index in
            let x = index % bitmap.width
            let y = index / bitmap.width

            guard !excludedRects.contains(where: { $0.contains(CGPoint(x: x, y: y)) }) else {
                return false
            }

            return bitmap.luminance(at: index) < inkThreshold
        }
    }
}
