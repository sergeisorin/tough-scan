import Foundation
import PDFKit
import ToughScanCore
import UIKit

protocol ScanExporting {
    func makePDF(from image: UIImage, textBlocks: [RecognizedTextBlock]) -> Data
    func makeExportBundle(
        from pages: [ScannedPage],
        intelligenceNotes: DocumentIntelligenceNotes?,
        includesIntelligenceNotes: Bool,
        exportMode: ScanExportMode
    ) throws -> ScanExportBundle
}

enum ScanExportMode: String, CaseIterable, Identifiable {
    case originalImagePDF
    case recomposedPDFWithVisualMarks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .originalImagePDF:
            return "Original image PDF"
        case .recomposedPDFWithVisualMarks:
            return "Cleaned PDF with visual marks"
        }
    }
}

protocol ExportDataWriting {
    func write(_ data: Data, to url: URL) throws
}

struct AtomicExportDataWriter: ExportDataWriting {
    func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}

final class ScanExportService: ScanExporting {
    enum ExportError: Error {
        case noPages
    }

    private let temporaryDirectory: URL
    private let fileManager: FileManager
    private let dataWriter: ExportDataWriting
    private let recomposedDocumentRenderer: RecomposedDocumentRenderer

    init(
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        fileManager: FileManager = .default,
        dataWriter: ExportDataWriting = AtomicExportDataWriter(),
        recomposedDocumentRenderer: RecomposedDocumentRenderer = RecomposedDocumentRenderer()
    ) {
        self.temporaryDirectory = temporaryDirectory
        self.fileManager = fileManager
        self.dataWriter = dataWriter
        self.recomposedDocumentRenderer = recomposedDocumentRenderer
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

    func makeExportBundle(
        from pages: [ScannedPage],
        intelligenceNotes: DocumentIntelligenceNotes? = nil,
        includesIntelligenceNotes: Bool = false,
        exportMode: ScanExportMode = .originalImagePDF
    ) throws -> ScanExportBundle {
        guard !pages.isEmpty else {
            throw ExportError.noPages
        }

        let exportDirectory = temporaryDirectory
            .appendingPathComponent("tough-scan-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )

        let pdfURL = exportDirectory.appendingPathComponent("tough-scan-document.pdf")
        let textURL = exportDirectory.appendingPathComponent("tough-scan-text.txt")

        do {
            try dataWriter.write(makeMultiPagePDF(from: pages, exportMode: exportMode), to: pdfURL)
            try dataWriter.write(
                makeTextFile(
                    from: pages,
                    intelligenceNotes: intelligenceNotes,
                    includesIntelligenceNotes: includesIntelligenceNotes
                ),
                to: textURL
            )
        } catch {
            try? fileManager.removeItem(at: exportDirectory)
            throw error
        }

        return ScanExportBundle(directoryURL: exportDirectory, fileURLs: [pdfURL, textURL])
    }

    private func makeMultiPagePDF(from pages: [ScannedPage], exportMode: ScanExportMode) -> Data {
        guard exportMode == .originalImagePDF else {
            return recomposedDocumentRenderer.makePDF(from: pages).data
        }

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

    private func makeTextFile(
        from pages: [ScannedPage],
        intelligenceNotes: DocumentIntelligenceNotes?,
        includesIntelligenceNotes: Bool
    ) -> Data {
        var sections = [ReviewTextSourceBuilder.makeSource(from: pages)]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        if includesIntelligenceNotes,
           let intelligenceNotes,
           !intelligenceNotes.isEmpty {
            sections.append("Apple Intelligence suggestions\n\(intelligenceNotes.exportText)")
        }

        let text = sections.joined(separator: "\n\n")

        return Data(text.utf8)
    }
}

