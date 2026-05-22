import ToughScanCore
import UIKit
import XCTest

final class VisualDocumentRegionDetectorTests: XCTestCase {
    private let detector = VisualDocumentRegionDetector()

    func testDetectsStampLikeBlobOutsideText() throws {
        let image = makeDocumentImage { context, size in
            UIColor.red.setStroke()
            let rect = CGRect(x: size.width * 0.62, y: size.height * 0.18, width: 58, height: 58)
            context.cgContext.setLineWidth(6)
            context.cgContext.strokeEllipse(in: rect)
        }

        let regions = detector.detectVisualRegions(in: image, textBlocks: [])

        let region = try XCTUnwrap(regions.first)
        XCTAssertEqual(region.kind, .stampOrSignature)
        XCTAssertGreaterThan(region.confidence, 0.40)
        XCTAssertGreaterThan(region.boundingBox.x, 0.55)
        XCTAssertLessThan(region.boundingBox.y, 0.35)
        XCTAssertGreaterThan(region.image.size.width, 20)
        XCTAssertGreaterThan(region.image.size.height, 20)
    }

    func testDetectsSignatureLikeFreeformStroke() throws {
        let image = makeDocumentImage { context, size in
            UIColor.black.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: size.width * 0.20, y: size.height * 0.72))
            path.addCurve(
                to: CGPoint(x: size.width * 0.68, y: size.height * 0.72),
                controlPoint1: CGPoint(x: size.width * 0.32, y: size.height * 0.62),
                controlPoint2: CGPoint(x: size.width * 0.48, y: size.height * 0.82)
            )
            path.addLine(to: CGPoint(x: size.width * 0.74, y: size.height * 0.68))
            path.lineWidth = 5
            path.stroke()
        }

        let regions = detector.detectVisualRegions(in: image, textBlocks: [])

        let region = try XCTUnwrap(regions.first)
        XCTAssertEqual(region.kind, .stampOrSignature)
        XCTAssertGreaterThan(region.boundingBox.width, 0.35)
        XCTAssertGreaterThan(region.boundingBox.y, 0.60)
    }

    func testIgnoresInkCoveredByExpandedOCRBoxes() {
        let image = makeDocumentImage { _, size in
            UIColor.black.setFill()
            UIRectFill(CGRect(x: size.width * 0.12, y: size.height * 0.18, width: 210, height: 28))
        }
        let visionBottomLeftY = 1 - 0.15 - 0.12
        let textBlocks = [
            RecognizedTextBlock(
                text: "Recognized text",
                confidence: 0.92,
                languageCode: "en",
                tileCoordinates: [],
                boundingBox: NormalizedRect(x: 0.10, y: visionBottomLeftY, width: 0.65, height: 0.12)
            )
        ]

        XCTAssertEqual(detector.detectVisualRegions(in: image, textBlocks: textBlocks), [])
    }

    func testRejectsTinySpecksAndHorizontalRules() {
        let image = makeDocumentImage { context, size in
            UIColor.black.setFill()
            UIRectFill(CGRect(x: 20, y: 20, width: 2, height: 2))
            UIRectFill(CGRect(x: 42, y: size.height * 0.50, width: size.width - 84, height: 3))
            context.cgContext.setLineWidth(1)
        }

        XCTAssertEqual(detector.detectVisualRegions(in: image, textBlocks: []), [])
    }

    private func makeDocumentImage(
        size: CGSize = CGSize(width: 320, height: 420),
        draw: (UIGraphicsImageRendererContext, CGSize) -> Void
    ) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            draw(context, size)
        }
    }
}
