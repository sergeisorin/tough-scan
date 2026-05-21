import CoreImage
import Foundation
import ToughScanCore
import Vision

protocol DocumentDetecting {
    func detectDocument(in image: CIImage) async throws -> DocumentGeometryObservation?
}

final class DocumentDetectionService: DocumentDetecting {
    func detectDocument(in image: CIImage) async throws -> DocumentGeometryObservation? {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let request = DetectDocumentSegmentationRequest(.revision1)
            guard let observation = try await request.perform(on: image) else {
                return nil
            }

            let geometry = DocumentDetectionGeometryMapper.geometryObservation(
                topLeft: observation.topLeft.cgPoint,
                topRight: observation.topRight.cgPoint,
                bottomRight: observation.bottomRight.cgPoint,
                bottomLeft: observation.bottomLeft.cgPoint,
                confidence: observation.confidence
            )

            guard geometry.quad.isValidDocumentShape else {
                return nil
            }

            return geometry
        }
        #endif

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
                    .map { rectangle in
                        DocumentDetectionGeometryMapper.geometryObservation(
                            topLeft: rectangle.topLeft,
                            topRight: rectangle.topRight,
                            bottomRight: rectangle.bottomRight,
                            bottomLeft: rectangle.bottomLeft,
                            confidence: rectangle.confidence
                        )
                    }
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
}

