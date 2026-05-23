import ToughScanCore
import UIKit
import XCTest

final class DocumentImageFusionSessionTests: XCTestCase {
    func testFusionBuildsSinglePageFromBestTilesAcrossSnapshots() throws {
        var fusion = DocumentImageFusionSession(gridWidth: 2, gridHeight: 1)
        let firstSnapshot = makeSnapshot(
            leftColor: .systemRed,
            rightColor: .systemBlue,
            leftConfidence: 0.35,
            rightConfidence: 0.82
        )
        let secondSnapshot = makeSnapshot(
            leftColor: .systemGreen,
            rightColor: .systemYellow,
            leftConfidence: 0.92,
            rightConfidence: 0.20
        )

        _ = fusion.add(firstSnapshot)
        let fusedSnapshot = try XCTUnwrap(fusion.add(secondSnapshot))

        XCTAssertEqual(fusedSnapshot.image.size, firstSnapshot.image.size)
        XCTAssertTrue(fusedSnapshot.image.colorAtPixel(x: 25, y: 25).isMostlyGreen)
        XCTAssertTrue(fusedSnapshot.image.colorAtPixel(x: 75, y: 25).isMostlyBlue)
    }

    private func makeSnapshot(
        leftColor: UIColor,
        rightColor: UIColor,
        leftConfidence: Double,
        rightConfidence: Double
    ) -> DocumentSnapshot {
        DocumentSnapshot(
            image: makeSplitImage(leftColor: leftColor, rightColor: rightColor),
            visualQuality: max(leftConfidence, rightConfidence),
            tileEvidence: [
                TileEvidence(
                    coordinate: TileCoordinate(column: 0, row: 0),
                    visualQuality: leftConfidence,
                    ocrConfidence: leftConfidence,
                    textCoverage: leftConfidence
                ),
                TileEvidence(
                    coordinate: TileCoordinate(column: 1, row: 0),
                    visualQuality: rightConfidence,
                    ocrConfidence: rightConfidence,
                    textCoverage: rightConfidence
                )
            ]
        )
    }

    private func makeSplitImage(leftColor: UIColor, rightColor: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50)).image { context in
            leftColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 50, height: 50))
            rightColor.setFill()
            context.fill(CGRect(x: 50, y: 0, width: 50, height: 50))
        }
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

private extension UIColor {
    var isMostlyGreen: Bool {
        let rgba = rgbaComponents
        return rgba.green > 0.35 && rgba.green > rgba.red * 1.2 && rgba.green > rgba.blue * 1.2
    }

    var isMostlyBlue: Bool {
        let rgba = rgbaComponents
        return rgba.blue > 0.45 && rgba.blue > rgba.red * 1.4 && rgba.blue > rgba.green * 1.1
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
