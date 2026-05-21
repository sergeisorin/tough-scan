import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import XCTest

final class FrameQualityAnalyzerTests: XCTestCase {
    private let analyzer = FrameQualityAnalyzer()

    func testBrightnessDistinguishesDarkAndBrightFrames() {
        let dark = analyzer.analyze(
            makeSolidImage(white: 0.08),
            geometryConfidence: 0.9,
            documentCoverage: 0.7
        )
        let bright = analyzer.analyze(
            makeSolidImage(white: 0.85),
            geometryConfidence: 0.9,
            documentCoverage: 0.7
        )

        XCTAssertLessThan(dark.brightness, 0.2)
        XCTAssertGreaterThan(bright.brightness, 0.75)
        XCTAssertLessThan(dark.captureScore, bright.captureScore)
    }

    func testContrastDistinguishesFlatAndStripedFrames() {
        let flat = analyzer.analyze(
            makeSolidImage(white: 0.5),
            geometryConfidence: 0.9,
            documentCoverage: 0.7
        )
        let striped = analyzer.analyze(
            makeStripedImage(),
            geometryConfidence: 0.9,
            documentCoverage: 0.7
        )

        XCTAssertLessThan(flat.contrast, 0.05)
        XCTAssertGreaterThan(striped.contrast, 0.45)
        XCTAssertGreaterThan(striped.captureScore, flat.captureScore)
    }

    func testGlareRiskIncreasesForClippedWhiteFrames() {
        let normal = analyzer.analyze(
            makeSolidImage(white: 0.78),
            geometryConfidence: 0.9,
            documentCoverage: 0.7
        )
        let clipped = analyzer.analyze(
            makeSolidImage(white: 1.0),
            geometryConfidence: 0.9,
            documentCoverage: 0.7
        )

        XCTAssertLessThan(normal.glareRisk, 0.05)
        XCTAssertGreaterThan(clipped.glareRisk, 0.9)
        XCTAssertLessThan(clipped.captureScore, normal.captureScore)
    }

    func testSharpnessDropsAfterBlur() {
        let crisp = makeLineImage()
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = crisp.clampedToExtent()
        blur.radius = 5
        let blurred = (blur.outputImage ?? crisp).cropped(to: crisp.extent)

        let crispMetrics = analyzer.analyze(
            crisp,
            geometryConfidence: 0.9,
            documentCoverage: 0.7
        )
        let blurredMetrics = analyzer.analyze(
            blurred,
            geometryConfidence: 0.9,
            documentCoverage: 0.7
        )

        XCTAssertGreaterThan(crispMetrics.sharpness, blurredMetrics.sharpness)
        XCTAssertGreaterThan(crispMetrics.captureScore, blurredMetrics.captureScore)
    }

    func testLensSmudgeConfidencePenalizesCaptureScore() {
        let clean = FrameQualityMetrics(
            brightness: 0.62,
            contrast: 0.7,
            sharpness: 0.7,
            glareRisk: 0.02,
            documentCoverage: 0.8,
            geometryConfidence: 0.9,
            lensSmudgeConfidence: 0.05
        )
        let smudged = FrameQualityMetrics(
            brightness: 0.62,
            contrast: 0.7,
            sharpness: 0.7,
            glareRisk: 0.02,
            documentCoverage: 0.8,
            geometryConfidence: 0.9,
            lensSmudgeConfidence: 0.92
        )

        XCTAssertFalse(clean.isLikelySmudged)
        XCTAssertTrue(smudged.isLikelySmudged)
        XCTAssertLessThan(smudged.captureScore, clean.captureScore)
    }

    private func makeSolidImage(white: CGFloat) -> CIImage {
        let color = UIColor(white: white, alpha: 1)
        return UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 96, height: 96))
        }.ciImageForTesting()
    }

    private func makeStripedImage() -> CIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 96, height: 96)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 96, height: 96))
            UIColor.black.setFill()
            for x in stride(from: 0, to: 96, by: 12) {
                context.fill(CGRect(x: x, y: 0, width: 6, height: 96))
            }
        }.ciImageForTesting()
    }

    private func makeLineImage() -> CIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
            UIColor.black.setFill()
            for y in stride(from: 12, to: 120, by: 12) {
                context.fill(CGRect(x: 12, y: y, width: 104, height: 2))
            }
        }.ciImageForTesting()
    }
}

private extension UIImage {
    func ciImageForTesting() -> CIImage {
        guard let cgImage else {
            return CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        }

        return CIImage(cgImage: cgImage)
    }
}
