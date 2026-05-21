import CoreImage
import Foundation
import Vision

protocol LensSmudgeDetecting {
    func smudgeConfidence(in image: CIImage) async -> Double?
}

struct DefaultLensSmudgeDetector: LensSmudgeDetecting {
    func smudgeConfidence(in image: CIImage) async -> Double? {
        if #available(iOS 26.0, *) {
            return await VisionLensSmudgeDetector().smudgeConfidence(in: image)
        }

        return nil
    }
}

@available(iOS 26.0, *)
private struct VisionLensSmudgeDetector: LensSmudgeDetecting {
    func smudgeConfidence(in image: CIImage) async -> Double? {
        do {
            let request = DetectLensSmudgeRequest(.revision1)
            let observation = try await request.perform(on: image)
            return Double(observation.confidence)
        } catch {
            return nil
        }
    }
}
