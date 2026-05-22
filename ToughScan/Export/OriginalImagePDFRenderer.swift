import PDFKit
import ToughScanCore
import UIKit

struct OriginalImagePDFRenderer {
    func makePDF(from pages: [ScannedPage]) -> Data {
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

    func makePDF(from image: UIImage) -> Data {
        makePDF(
            from: [
                ScannedPage(
                    snapshot: DocumentSnapshot(image: image, visualQuality: 1),
                    recognizedTextBlocks: []
                )
            ]
        )
    }
}
