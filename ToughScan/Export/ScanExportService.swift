import Foundation
import PDFKit
import ToughScanCore
import UIKit

protocol ScanExporting {
    func makePDF(from image: UIImage, textBlocks: [RecognizedTextBlock]) -> Data
    func makeTextFile(from textBlocks: [RecognizedTextBlock]) -> Data
    func makeExportBundle(from pages: [ScannedPage]) throws -> ScanExportBundle
}

final class ScanExportService: ScanExporting {
    enum ExportError: Error {
        case noPages
    }

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

    func makeExportBundle(from pages: [ScannedPage]) throws -> ScanExportBundle {
        guard !pages.isEmpty else {
            throw ExportError.noPages
        }

        let exportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("tough-scan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )

        let pdfURL = exportDirectory.appendingPathComponent("tough-scan-document.pdf")
        let textURL = exportDirectory.appendingPathComponent("tough-scan-text.txt")

        do {
            try makeMultiPagePDF(from: pages).write(to: pdfURL, options: .atomic)
            try makeTextFile(from: pages).write(to: textURL, options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: exportDirectory)
            throw error
        }

        return ScanExportBundle(directoryURL: exportDirectory, fileURLs: [pdfURL, textURL])
    }

    private func makeMultiPagePDF(from pages: [ScannedPage]) -> Data {
        let firstPageSize = pages.first?.snapshot.image.size ?? CGSize(width: 612, height: 792)
        let format = UIGraphicsPDFRendererFormat()
        let metadata = [
            kCGPDFContextCreator: "Tough Scan",
            kCGPDFContextTitle: "Recovered Document"
        ]
        format.documentInfo = metadata as [String: Any]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: firstPageSize),
            format: format
        )

        return renderer.pdfData { context in
            for page in pages {
                let pageRect = CGRect(origin: .zero, size: page.snapshot.image.size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                page.snapshot.image.draw(in: pageRect)
            }
        }
    }

    private func makeTextFile(from pages: [ScannedPage]) -> Data {
        let text = pages.enumerated()
            .map { index, page in
                let body = page.structuredDocument?.exportText ?? page.recognizedTextBlocks
                    .map(\.text)
                    .joined(separator: "\n")

                return "Page \(index + 1)\n\(body)"
            }
            .joined(separator: "\n\n")

        return Data(text.utf8)
    }
}

