import CoreGraphics
import ToughScanCore
import UIKit

struct VisualDocumentRegionDetector {
    private let inkThreshold: UInt8 = 225
    private let minimumInkPixels = 24
    private let maximumRegionCoverage = 0.45
    private let textBoxExpansion = 0.02

    func detectVisualRegions(
        in image: UIImage,
        textBlocks: [RecognizedTextBlock]
    ) -> [VisualDocumentRegion] {
        guard let bitmap = BitmapImage(image: image) else {
            return []
        }

        let excludedRects = textBlocks
            .compactMap(\.boundingBox)
            .map { expandedPixelRect(for: $0, in: bitmap.size) }

        let mask = makeInkMask(from: bitmap, excluding: excludedRects)
        let components = connectedComponents(in: mask, width: bitmap.width, height: bitmap.height)

        return components
            .compactMap { component in
                makeRegion(from: component, bitmap: bitmap)
            }
            .sorted { lhs, rhs in
                if lhs.boundingBox.y != rhs.boundingBox.y {
                    return lhs.boundingBox.y < rhs.boundingBox.y
                }

                return lhs.boundingBox.x < rhs.boundingBox.x
            }
    }

    private func makeInkMask(
        from bitmap: BitmapImage,
        excluding excludedRects: [CGRect]
    ) -> [Bool] {
        (0..<(bitmap.width * bitmap.height)).map { index in
            let x = index % bitmap.width
            let y = index / bitmap.width

            guard !excludedRects.contains(where: { $0.contains(CGPoint(x: x, y: y)) }) else {
                return false
            }

            return bitmap.luminance(at: index) < inkThreshold
        }
    }

    private func connectedComponents(
        in mask: [Bool],
        width: Int,
        height: Int
    ) -> [InkComponent] {
        var visited = Array(repeating: false, count: mask.count)
        var components: [InkComponent] = []

        for index in mask.indices where mask[index] && !visited[index] {
            var stack = [index]
            visited[index] = true
            var component = InkComponent()

            while let current = stack.popLast() {
                let x = current % width
                let y = current / width
                component.include(x: x, y: y)

                for neighbor in neighbors(ofX: x, y: y, width: width, height: height) {
                    guard mask[neighbor], !visited[neighbor] else {
                        continue
                    }

                    visited[neighbor] = true
                    stack.append(neighbor)
                }
            }

            components.append(component)
        }

        return components
    }

    private func neighbors(ofX x: Int, y: Int, width: Int, height: Int) -> [Int] {
        var result: [Int] = []

        for yOffset in -1...1 {
            for xOffset in -1...1 where !(xOffset == 0 && yOffset == 0) {
                let nextX = x + xOffset
                let nextY = y + yOffset
                guard nextX >= 0, nextX < width, nextY >= 0, nextY < height else {
                    continue
                }

                result.append((nextY * width) + nextX)
            }
        }

        return result
    }

    private func makeRegion(
        from component: InkComponent,
        bitmap: BitmapImage
    ) -> VisualDocumentRegion? {
        guard component.pixelCount >= minimumInkPixels else {
            return nil
        }

        let rect = component.pixelRect
        let width = rect.width
        let height = rect.height
        guard width >= 8, height >= 8 else {
            return nil
        }

        let imageArea = CGFloat(bitmap.width * bitmap.height)
        guard (width * height) / imageArea <= maximumRegionCoverage else {
            return nil
        }

        let aspectRatio = width / max(height, 1)
        if aspectRatio > 8, height / CGFloat(bitmap.height) < 0.04 {
            return nil
        }

        let normalizedRect = NormalizedRect(
            x: rect.minX / CGFloat(bitmap.width),
            y: rect.minY / CGFloat(bitmap.height),
            width: rect.width / CGFloat(bitmap.width),
            height: rect.height / CGFloat(bitmap.height)
        )

        guard let croppedImage = bitmap.croppedImage(to: rect) else {
            return nil
        }

        let density = Double(component.pixelCount) / Double(max(1, Int(width * height)))
        let shapeConfidence = min(1, max(0.35, density * 2.5))

        return VisualDocumentRegion(
            kind: .stampOrSignature,
            boundingBox: normalizedRect,
            confidence: shapeConfidence,
            image: croppedImage
        )
    }

    private func expandedPixelRect(for rect: NormalizedRect, in size: CGSize) -> CGRect {
        let expanded = NormalizedRect(
            x: max(0, rect.x - textBoxExpansion),
            y: max(0, rect.y - textBoxExpansion),
            width: min(1, rect.width + (textBoxExpansion * 2)),
            height: min(1, rect.height + (textBoxExpansion * 2))
        )

        return CGRect(
            x: expanded.x * size.width,
            y: (1 - expanded.y - expanded.height) * size.height,
            width: expanded.width * size.width,
            height: expanded.height * size.height
        )
    }
}

private struct InkComponent {
    private(set) var minX = Int.max
    private(set) var minY = Int.max
    private(set) var maxX = Int.min
    private(set) var maxY = Int.min
    private(set) var pixelCount = 0

    mutating func include(x: Int, y: Int) {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
        pixelCount += 1
    }

    var pixelRect: CGRect {
        CGRect(
            x: minX,
            y: minY,
            width: max(0, maxX - minX + 1),
            height: max(0, maxY - minY + 1)
        )
    }
}

private struct BitmapImage {
    let cgImage: CGImage
    let width: Int
    let height: Int
    let data: [UInt8]

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    init?(image: UIImage) {
        guard let cgImage = image.cgImage else {
            return nil
        }

        self.cgImage = cgImage
        self.width = cgImage.width
        self.height = cgImage.height

        var pixels = Array(repeating: UInt8(255), count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.data = pixels
    }

    func luminance(at pixelIndex: Int) -> UInt8 {
        let index = pixelIndex * 4
        let red = Double(data[index])
        let green = Double(data[index + 1])
        let blue = Double(data[index + 2])
        return UInt8((red * 0.299) + (green * 0.587) + (blue * 0.114))
    }

    func croppedImage(to rect: CGRect) -> UIImage? {
        let integralRect = rect.integral
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !integralRect.isEmpty,
              let crop = cgImage.cropping(to: integralRect) else {
            return nil
        }

        return UIImage(cgImage: crop)
    }
}
