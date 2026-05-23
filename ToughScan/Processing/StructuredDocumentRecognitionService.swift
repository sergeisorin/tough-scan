import Foundation
import UIKit
import Vision

protocol StructuredDocumentRecognizing {
    func recognizeDocument(in image: UIImage) async throws -> StructuredDocument
}

final class StructuredDocumentRecognitionService: StructuredDocumentRecognizing {
    enum RecognitionError: Error {
        case missingImageData
        case noDocument
    }

    func recognizeDocument(in image: UIImage) async throws -> StructuredDocument {
        guard let cgImage = image.cgImage else {
            throw RecognitionError.missingImageData
        }

        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            var request = RecognizeDocumentsRequest(.revision1)
            request.textRecognitionOptions.automaticallyDetectLanguage = false
            request.textRecognitionOptions.recognitionLanguages = [
                Locale.Language(identifier: "he-IL"),
                Locale.Language(identifier: "en-US")
            ]
            request.textRecognitionOptions.useLanguageCorrection = true
            request.barcodeDetectionOptions.enabled = true

            let observations = try await request.perform(on: cgImage)
            guard let container = observations.first?.document else {
                throw RecognitionError.noDocument
            }

            return StructuredDocument(
                paragraphs: container.paragraphs.map(\.transcript),
                tables: container.tables.map(Self.structuredTable),
                lists: container.lists.map(Self.structuredList),
                barcodes: container.barcodes.compactMap(\.payloadString)
            )
        }
        #endif

        let textBlocks = try await TextRecognitionService().recognizeText(in: cgImage)
        let paragraphs = textBlocks
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard !paragraphs.isEmpty else {
            throw RecognitionError.noDocument
        }

        return StructuredDocument(
            paragraphs: paragraphs,
            tables: [],
            lists: [],
            barcodes: []
        )
    }

    #if compiler(>=6.2)
    @available(iOS 26.0, *)
    private static func structuredTable(from table: DocumentObservation.Container.Table) -> StructuredTable {
        StructuredTable(
            rows: table.rows.map { row in
                row.map { cell in
                    cell.content.text.transcript
                }
            }
        )
    }

    @available(iOS 26.0, *)
    private static func structuredList(from list: DocumentObservation.Container.List) -> StructuredList {
        StructuredList(items: list.items.map(\.itemString))
    }
    #endif
}
