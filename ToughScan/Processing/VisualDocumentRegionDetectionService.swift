import ToughScanCore
import UIKit

struct VisualDocumentRegionDetectionService {
    typealias Detection = (UIImage, [RecognizedTextBlock]) -> [VisualDocumentRegion]

    private let detection: Detection

    init(detector: VisualDocumentRegionDetector = VisualDocumentRegionDetector()) {
        self.detection = { image, textBlocks in
            detector.detectVisualRegions(in: image, textBlocks: textBlocks)
        }
    }

    init(detection: @escaping Detection) {
        self.detection = detection
    }

    func detectVisualRegions(
        in image: UIImage,
        textBlocks: [RecognizedTextBlock]
    ) async -> [VisualDocumentRegion] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: detection(image, textBlocks))
            }
        }
    }
}
