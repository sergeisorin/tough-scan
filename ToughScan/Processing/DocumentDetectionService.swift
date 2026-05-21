import CoreImage
import Foundation
import ToughScanCore
import Vision

protocol DocumentDetecting {
    func detectDocument(in image: CIImage) async throws -> DocumentGeometryObservation?
}

final class DocumentDetectionService: DocumentDetecting {
    func detectDocument(in image: CIImage) async throws -> DocumentGeometryObservation? {
        guard let cgImage = CIContext().createCGImage(image, from: image.extent) else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let rectangles = (request.results as? [VNRectangleObservation]) ?? []
                let bestRectangle = rectangles
                    .map(Self.geometryObservation)
                    .filter { $0.quad.isValidDocumentShape }
                    .max { lhs, rhs in
                        let lhsScore = lhs.confidence * lhs.quad.area
                        let rhsScore = rhs.confidence * rhs.quad.area
                        return lhsScore < rhsScore
                    }

                continuation.resume(returning: bestRectangle)
            }

            request.maximumObservations = 3
            request.minimumConfidence = 0.35
            request.minimumAspectRatio = 0.20
            request.maximumAspectRatio = 1.00
            request.quadratureTolerance = 35

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func geometryObservation(from rectangle: VNRectangleObservation) -> DocumentGeometryObservation {
        DocumentGeometryObservation(
            quad: DocumentQuad(
                topLeft: rectangle.topLeft.asTopLeftPoint,
                topRight: rectangle.topRight.asTopLeftPoint,
                bottomRight: rectangle.bottomRight.asTopLeftPoint,
                bottomLeft: rectangle.bottomLeft.asTopLeftPoint
            ),
            confidence: Double(rectangle.confidence)
        )
    }
}

private extension CGPoint {
    var asTopLeftPoint: ToughScanCore.NormalizedPoint {
        ToughScanCore.NormalizedPoint(x: x, y: 1 - y)
    }
}

