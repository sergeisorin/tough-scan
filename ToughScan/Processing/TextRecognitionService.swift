import CoreGraphics
import Foundation
import ToughScanCore
import Vision

protocol TextRecognizing {
    func recognizeText(in image: CGImage) async throws -> [RecognizedTextBlock]
}

final class TextRecognitionService: TextRecognizing {
    private let recognitionLanguages = ["he-IL", "en-US"]

    func recognizeText(in image: CGImage) async throws -> [RecognizedTextBlock] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let blocks = observations.compactMap { observation -> RecognizedTextBlock? in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }

                    return RecognizedTextBlock(
                        text: candidate.string,
                        confidence: Double(candidate.confidence),
                        languageCode: "he,en",
                        tileCoordinates: []
                    )
                }

                continuation.resume(returning: blocks)
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

