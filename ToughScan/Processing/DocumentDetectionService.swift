import CoreImage
import Foundation
import ToughScanCore
import Vision

protocol DocumentDetecting {
    func detectDocument(in image: CIImage) async throws -> DocumentGeometryObservation?
}

final class DocumentDetectionService: DocumentDetecting {
    func detectDocument(in image: CIImage) async throws -> DocumentGeometryObservation? {
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
}

