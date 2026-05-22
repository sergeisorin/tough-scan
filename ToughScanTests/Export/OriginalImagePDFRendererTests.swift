import PDFKit
import XCTest

final class OriginalImagePDFRendererTests: XCTestCase {
    func testRendererWritesOnePagePerSourceImage() throws {
        let firstPage = ScannedPage(
            snapshot: DocumentSnapshot(image: makeImage(size: CGSize(width: 100, height: 120)), visualQuality: 0.8),
            recognizedTextBlocks: []
        )
        let secondPage = ScannedPage(
            snapshot: DocumentSnapshot(image: makeImage(size: CGSize(width: 80, height: 90)), visualQuality: 0.8),
            recognizedTextBlocks: []
        )

        let data = OriginalImagePDFRenderer().makePDF(from: [firstPage, secondPage])
        let document = try XCTUnwrap(PDFDocument(data: data))

        XCTAssertEqual(document.pageCount, 2)
        XCTAssertEqual(document.page(at: 0)?.bounds(for: .mediaBox).size, firstPage.snapshot.image.size)
        XCTAssertEqual(document.page(at: 1)?.bounds(for: .mediaBox).size, secondPage.snapshot.image.size)
    }

    private func makeImage(size: CGSize) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
