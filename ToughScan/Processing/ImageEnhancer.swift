import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

protocol ImageEnhancing {
    func enhance(_ image: CIImage) -> CIImage
}

struct ImageEnhancementProfile: Equatable {
    static let `default` = ImageEnhancementProfile(
        contrast: 1.35,
        brightness: 0.04,
        saturation: 0,
        sharpness: 0.45
    )

    let contrast: Float
    let brightness: Float
    let saturation: Float
    let sharpness: Float
}

final class ImageEnhancer: ImageEnhancing {
    private let context = CIContext()

    func enhance(_ image: CIImage) -> CIImage {
        enhance(image, profile: .default)
    }

    func enhance(_ image: CIImage, metrics: FrameQualityMetrics) -> CIImage {
        enhance(image, profile: enhancementProfile(for: metrics))
    }

    func enhancementProfile(for metrics: FrameQualityMetrics) -> ImageEnhancementProfile {
        if metrics.glareRisk > 0.25 {
            return ImageEnhancementProfile(
                contrast: 1.15,
                brightness: -0.03,
                saturation: 0,
                sharpness: 0.30
            )
        }

        if metrics.contrast < 0.20 {
            return ImageEnhancementProfile(
                contrast: 1.55,
                brightness: metrics.brightness < 0.40 ? 0.08 : 0.04,
                saturation: 0,
                sharpness: metrics.sharpness < 0.20 ? 0.35 : 0.45
            )
        }

        if metrics.sharpness < 0.20 {
            return ImageEnhancementProfile(
                contrast: 1.30,
                brightness: 0.03,
                saturation: 0,
                sharpness: 0.30
            )
        }

        return .default
    }

    private func enhance(_ image: CIImage, profile: ImageEnhancementProfile) -> CIImage {
        let contrast = CIFilter.colorControls()
        contrast.inputImage = image
        contrast.contrast = profile.contrast
        contrast.saturation = profile.saturation
        contrast.brightness = profile.brightness

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = contrast.outputImage ?? image
        sharpen.sharpness = profile.sharpness

        return sharpen.outputImage ?? contrast.outputImage ?? image
    }

    func makeCGImage(from image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent)
    }
}

