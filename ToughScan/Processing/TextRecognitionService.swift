import CoreGraphics
import Foundation
import ToughScanCore
import Vision

protocol TextRecognizing {
    func recognizeTextRegions(in image: CGImage) async throws -> [NormalizedTextRegion]
    func recognizeText(in image: CGImage) async throws -> [RecognizedTextBlock]
}

final class TextRecognitionService: TextRecognizing {
    private let recognitionLanguages = ["he-IL", "en-US"]

    func recognizeText(in image: CGImage) async throws -> [RecognizedTextBlock] {
        let regions = try await recognizeTextRegions(in: image)
        return regions.map { region in
            RecognizedTextBlock(
                text: region.text,
                confidence: region.confidence,
                languageCode: region.languageCode,
                tileCoordinates: [],
                boundingBox: region.boundingBox
            )
        }
    }

    func recognizeTextRegions(in image: CGImage) async throws -> [NormalizedTextRegion] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let regions = observations.compactMap { observation -> NormalizedTextRegion? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }

                    return NormalizedTextRegion(
                        text: candidate.string,
                        confidence: Double(candidate.confidence),
                        languageCode: "he,en",
                        boundingBox: NormalizedRect(
                            x: observation.boundingBox.origin.x,
                            y: observation.boundingBox.origin.y,
                            width: observation.boundingBox.width,
                            height: observation.boundingBox.height
                        )
                    )
                }

                continuation.resume(returning: regions)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguages

            let handler = VNImageRequestHandler(cgImage: image, orientation: .up)

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

