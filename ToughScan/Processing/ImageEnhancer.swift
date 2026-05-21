import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

protocol ImageEnhancing {
    func enhance(_ image: CIImage) -> CIImage
}

final class ImageEnhancer: ImageEnhancing {
    private let context = CIContext()

    func enhance(_ image: CIImage) -> CIImage {
        let contrast = CIFilter.colorControls()
        contrast.inputImage = image
        contrast.contrast = 1.35
        contrast.saturation = 0
        contrast.brightness = 0.04

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = contrast.outputImage ?? image
        sharpen.sharpness = 0.45

        return sharpen.outputImage ?? contrast.outputImage ?? image
    }

    func makeCGImage(from image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent)
    }
}

