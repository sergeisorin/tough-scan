import CoreGraphics
import Foundation
import ToughScanCore

enum DocumentDetectionGeometryMapper {
    static func geometryObservation(
        topLeft: CGPoint,
        topRight: CGPoint,
        bottomRight: CGPoint,
        bottomLeft: CGPoint,
        confidence: Float
    ) -> DocumentGeometryObservation {
        DocumentGeometryObservation(
            quad: DocumentQuad(
                topLeft: topLeft.asTopLeftPoint,
                topRight: topRight.asTopLeftPoint,
                bottomRight: bottomRight.asTopLeftPoint,
                bottomLeft: bottomLeft.asTopLeftPoint
            ),
            confidence: Double(confidence)
        )
    }
}

private extension CGPoint {
    var asTopLeftPoint: ToughScanCore.NormalizedPoint {
        ToughScanCore.NormalizedPoint(x: x, y: 1 - y)
    }
}
