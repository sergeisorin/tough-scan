import CoreGraphics
import UIKit

struct VisualDocumentBitmap {
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
