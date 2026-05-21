import Foundation
import PDFKit
import ToughScanCore
import UIKit

protocol ScanExporting {
    func makePDF(from image: UIImage, textBlocks: [RecognizedTextBlock]) -> Data
    func makeTextFile(from textBlocks: [RecognizedTextBlock]) -> Data
}

final class ScanExportService: ScanExporting {
    func makePDF(from image: UIImage, textBlocks: [RecognizedTextBlock]) -> Data {
        let format = UIGraphicsPDFRendererFormat()
        let metadata = [
            kCGPDFContextCreator: "Tough Scan",
            kCGPDFContextTitle: "Recovered Document"
        ]
        format.documentInfo = metadata as [String: Any]

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: image.size), format: format)
        return renderer.pdfData { context in
            context.beginPage()
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    func makeTextFile(from textBlocks: [RecognizedTextBlock]) -> Data {
        let text = textBlocks
            .map(\.text)
            .joined(separator: "\n")

        return Data(text.utf8)
    }
}

