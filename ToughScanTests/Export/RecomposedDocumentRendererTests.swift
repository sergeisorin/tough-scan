import PDFKit
import ToughScanCore
import XCTest

final class RecomposedDocumentRendererTests: XCTestCase {
    func testRendererDrawsTextAndVisualRegionOntoWhitePage() throws {
        let page = makePage(
            textBlocks: [
                RecognizedTextBlock(
                    text: "Total 42",
                    confidence: 0.93,
                    languageCode: "en",
                    tileCoordinates: [],
                    boundingBox: NormalizedRect(x: 0.12, y: 0.16, width: 0.40, height: 0.10)
                )
            ],
            visualRegions: [
                makeVisualRegion(
                    boundingBox: NormalizedRect(x: 0.66, y: 0.18, width: 0.18, height: 0.16),
                    color: .systemBlue
                )
            ]
        )

        let result = RecomposedDocumentRenderer().makePDF(from: [page])
        let pdf = try XCTUnwrap(PDFDocument(data: result.data))
        let pdfPage = try XCTUnwrap(pdf.page(at: 0))

        XCTAssertFalse(result.usedOriginalImageFallback)
        XCTAssertEqual(pdf.string, "Total 42")
        XCTAssertTrue(sampledColor(from: pdfPage, at: CGPoint(x: 0.74, y: 0.26)).isMostlyBlue)
    }

    func testRendererPlacesVisionTextBoxesUsingBottomLeftYCoordinates() throws {
        let page = makePage(
            textBlocks: [
                RecognizedTextBlock(
                    text: "TOP TEXT",
                    confidence: 0.93,
                    languageCode: "en",
                    tileCoordinates: [],
                    boundingBox: NormalizedRect(x: 0.10, y: 0.70, width: 0.80, height: 0.16)
                )
            ],
            visualRegions: []
        )

        let result = RecomposedDocumentRenderer().makePDF(from: [page])
        let pdf = try XCTUnwrap(PDFDocument(data: result.data))
        let pdfPage = try XCTUnwrap(pdf.page(at: 0))

        let expectedTopTextPixels = darkPixelCount(
            from: pdfPage,
            in: NormalizedRect(x: 0.08, y: 0.10, width: 0.84, height: 0.22)
        )
        let mirroredBottomTextPixels = darkPixelCount(
            from: pdfPage,
            in: NormalizedRect(x: 0.08, y: 0.66, width: 0.84, height: 0.22)
        )

        XCTAssertGreaterThan(expectedTopTextPixels, 20)
        XCTAssertLessThan(mirroredBottomTextPixels, expectedTopTextPixels / 3)
    }

    func testRendererFallsBackToOriginalImageWhenTextBoxesAreMissing() throws {
        let page = makePage(
            imageBackgroundColor: .systemYellow,
            textBlocks: [
                RecognizedTextBlock(
                    text: "Unplaced text",
                    confidence: 0.88,
                    languageCode: "en",
                    tileCoordinates: []
                )
            ],
            visualRegions: []
        )

        let result = RecomposedDocumentRenderer().makePDF(from: [page])
        let pdf = try XCTUnwrap(PDFDocument(data: result.data))
        let pdfPage = try XCTUnwrap(pdf.page(at: 0))

        XCTAssertTrue(result.usedOriginalImageFallback)
        XCTAssertEqual(result.ineligiblePageIDs, [page.id])
        XCTAssertTrue(sampledColor(from: pdfPage, at: CGPoint(x: 0.50, y: 0.50)).isMostlyYellow)
    }

    func testOriginalImagePDFPathStillDrawsSourceImage() throws {
        let service = ScanExportService()
        let image = makeImage(size: CGSize(width: 120, height: 160), backgroundColor: .systemGreen)
        let pdf = try XCTUnwrap(PDFDocument(data: service.makePDF(from: image, textBlocks: [])))
        let pdfPage = try XCTUnwrap(pdf.page(at: 0))

        XCTAssertTrue(sampledColor(from: pdfPage, at: CGPoint(x: 0.50, y: 0.50)).isMostlyGreen)
    }

    private func makePage(
        imageBackgroundColor: UIColor = .white,
        textBlocks: [RecognizedTextBlock],
        visualRegions: [VisualDocumentRegion]
    ) -> ScannedPage {
        ScannedPage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000222")!,
            snapshot: DocumentSnapshot(
                image: makeImage(size: CGSize(width: 240, height: 320), backgroundColor: imageBackgroundColor),
                visualQuality: 0.9
            ),
            recognizedTextBlocks: textBlocks,
            visualRegions: visualRegions
        )
    }

    private func makeVisualRegion(
        boundingBox: NormalizedRect,
        color: UIColor
    ) -> VisualDocumentRegion {
        VisualDocumentRegion(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000333")!,
            kind: .stampOrSignature,
            boundingBox: boundingBox,
            confidence: 0.9,
            image: makeImage(size: CGSize(width: 44, height: 36), backgroundColor: color)
        )
    }

    private func makeImage(size: CGSize, backgroundColor: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            backgroundColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func sampledColor(from page: PDFPage, at normalizedPoint: CGPoint) -> UIColor {
        let thumbnail = page.thumbnail(of: CGSize(width: 240, height: 320), for: .mediaBox)
        let x = min(max(Int(normalizedPoint.x * thumbnail.size.width), 0), Int(thumbnail.size.width) - 1)
        let y = min(max(Int(normalizedPoint.y * thumbnail.size.height), 0), Int(thumbnail.size.height) - 1)
        return thumbnail.colorAtPixel(x: x, y: y)
    }

    private func darkPixelCount(from page: PDFPage, in rect: NormalizedRect) -> Int {
        let thumbnail = page.thumbnail(of: CGSize(width: 240, height: 320), for: .mediaBox)
        let pixelRect = CGRect(
            x: rect.x * thumbnail.size.width,
            y: rect.y * thumbnail.size.height,
            width: rect.width * thumbnail.size.width,
            height: rect.height * thumbnail.size.height
        ).integral

        var count = 0
        for x in Int(pixelRect.minX)..<Int(pixelRect.maxX) {
            for y in Int(pixelRect.minY)..<Int(pixelRect.maxY) {
                if thumbnail.colorAtPixel(x: x, y: y).isDark {
                    count += 1
                }
            }
        }

        return count
    }
}

private extension UIColor {
    var isMostlyBlue: Bool {
        let rgba = rgbaComponents
        return rgba.blue > 0.45 && rgba.blue > rgba.red * 1.4 && rgba.blue > rgba.green * 1.1
    }

    var isMostlyGreen: Bool {
        let rgba = rgbaComponents
        return rgba.green > 0.35 && rgba.green > rgba.red * 1.2 && rgba.green > rgba.blue * 1.2
    }

    var isMostlyYellow: Bool {
        let rgba = rgbaComponents
        return rgba.red > 0.65 && rgba.green > 0.55 && rgba.blue < 0.35
    }

    var isDark: Bool {
        let rgba = rgbaComponents
        return (rgba.red + rgba.green + rgba.blue) / 3 < 0.45
    }

    private var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (red, green, blue, alpha)
    }
}

private extension UIImage {
    func colorAtPixel(x: Int, y: Int) -> UIColor {
        guard let cgImage else {
            return .clear
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(
            cgImage,
            in: CGRect(
                x: -x,
                y: y - Int(size.height) + 1,
                width: Int(size.width),
                height: Int(size.height)
            )
        )

        return UIColor(
            red: CGFloat(pixel[0]) / 255,
            green: CGFloat(pixel[1]) / 255,
            blue: CGFloat(pixel[2]) / 255,
            alpha: CGFloat(pixel[3]) / 255
        )
    }
}
