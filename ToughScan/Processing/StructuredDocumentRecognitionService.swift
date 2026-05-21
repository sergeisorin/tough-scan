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

        var request = RecognizeDocumentsRequest(.revision1)
        request.textRecognitionOptions.automaticallyDetectLanguage = true
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

    private static func structuredTable(from table: DocumentObservation.Container.Table) -> StructuredTable {
        StructuredTable(
            rows: table.rows.map { row in
                row.map { cell in
                    cell.content.text.transcript
                }
            }
        )
    }

    private static func structuredList(from list: DocumentObservation.Container.List) -> StructuredList {
        StructuredList(items: list.items.map(\.itemString))
    }
}
