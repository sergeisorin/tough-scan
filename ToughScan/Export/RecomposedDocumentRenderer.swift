import PDFKit
import ToughScanCore
import UIKit

struct RecomposedDocumentRenderResult {
    let data: Data
    let usedOriginalImageFallback: Bool
    let ineligiblePageIDs: [ScannedPage.ID]
}

struct RecomposedDocumentRenderer {
    func makePDF(from pages: [ScannedPage]) -> RecomposedDocumentRenderResult {
        let firstPageSize = pages.first?.snapshot.image.size ?? CGSize(width: 612, height: 792)
        let ineligiblePages = pages.filter { !isEligibleForRecomposition($0) }
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator: "Tough Scan",
            kCGPDFContextTitle: "Recomposed Recovered Document"
        ] as [String: Any]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: firstPageSize),
            format: format
        )

        let data = renderer.pdfData { context in
            for page in pages {
                let pageRect = CGRect(origin: .zero, size: page.snapshot.image.size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])

                if isEligibleForRecomposition(page) {
                    drawRecomposed(page, in: pageRect)
                } else {
                    page.snapshot.image.draw(in: pageRect)
                }
            }
        }

        return RecomposedDocumentRenderResult(
            data: data,
            usedOriginalImageFallback: !ineligiblePages.isEmpty,
            ineligiblePageIDs: ineligiblePages.map(\.id)
        )
    }

    func isEligibleForRecomposition(_ page: ScannedPage) -> Bool {
        page.recognizedTextBlocks.contains { block in
            guard let boundingBox = block.boundingBox else {
                return false
            }

            return !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                boundingBox.width > 0 &&
                boundingBox.height > 0
        }
    }

    private func drawRecomposed(_ page: ScannedPage, in pageRect: CGRect) {
        UIColor.white.setFill()
        UIRectFill(pageRect)

        for block in page.recognizedTextBlocks {
            draw(block, in: pageRect, usesVisionCoordinates: true)
        }

        for region in page.visualRegions {
            region.image.draw(in: pixelRect(for: region.boundingBox, in: pageRect))
        }
    }

    private func draw(_ block: RecognizedTextBlock, in pageRect: CGRect, usesVisionCoordinates: Bool) {
        guard let boundingBox = block.boundingBox,
              !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let textRect = pixelRect(for: boundingBox, in: pageRect, usesVisionCoordinates: usesVisionCoordinates)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = block.languageCode.contains("he") ? .right : .left
        paragraphStyle.baseWritingDirection = block.languageCode.contains("he") ? .rightToLeft : .leftToRight

        let fontSize = max(8, min(textRect.height * 0.62, 24))
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraphStyle
        ]

        block.text.draw(
            with: textRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
    }

    private func pixelRect(
        for rect: NormalizedRect,
        in pageRect: CGRect,
        usesVisionCoordinates: Bool = false
    ) -> CGRect {
        let normalizedY = usesVisionCoordinates ? 1 - rect.y - rect.height : rect.y

        return CGRect(
            x: pageRect.minX + (rect.x * pageRect.width),
            y: pageRect.minY + (normalizedY * pageRect.height),
            width: rect.width * pageRect.width,
            height: rect.height * pageRect.height
        )
    }
}
