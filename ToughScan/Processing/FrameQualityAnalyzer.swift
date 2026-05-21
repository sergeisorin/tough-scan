import CoreImage
import Foundation

protocol FrameQualityAnalyzing {
    func analyze(
        _ image: CIImage,
        geometryConfidence: Double,
        documentCoverage: Double
    ) -> FrameQualityMetrics
}

final class FrameQualityAnalyzer: FrameQualityAnalyzing {
    private let context = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
    private let sampleSize = 48

    func analyze(
        _ image: CIImage,
        geometryConfidence: Double,
        documentCoverage: Double
    ) -> FrameQualityMetrics {
        let samples = luminanceSamples(from: image)
        guard !samples.isEmpty else {
            return FrameQualityMetrics(
                brightness: 0,
                contrast: 0,
                sharpness: 0,
                glareRisk: 1,
                documentCoverage: documentCoverage,
                geometryConfidence: geometryConfidence
            )
        }

        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.reduce(0) { partial, sample in
            partial + pow(sample - mean, 2)
        } / Double(samples.count)
        let contrast = min(sqrt(variance) * 2, 1)
        let glareRisk = Double(samples.filter { $0 >= 0.96 }.count) / Double(samples.count)
        let sharpness = estimateSharpness(samples: samples, width: sampleSize, height: sampleSize)

        return FrameQualityMetrics(
            brightness: mean,
            contrast: contrast,
            sharpness: sharpness,
            glareRisk: glareRisk,
            documentCoverage: documentCoverage,
            geometryConfidence: geometryConfidence
        )
    }

    private func luminanceSamples(from image: CIImage) -> [Double] {
        let extent = image.extent.integral
        guard extent.width > 0, extent.height > 0 else {
            return []
        }

        let scaleX = CGFloat(sampleSize) / extent.width
        let scaleY = CGFloat(sampleSize) / extent.height
        let scaled = image
            .cropped(to: extent)
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var bytes = [UInt8](repeating: 0, count: sampleSize * sampleSize * 4)
        context.render(
            scaled,
            toBitmap: &bytes,
            rowBytes: sampleSize * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return stride(from: 0, to: bytes.count, by: 4).map { index in
            let red = Double(bytes[index]) / 255
            let green = Double(bytes[index + 1]) / 255
            let blue = Double(bytes[index + 2]) / 255
            return (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        }
    }

    private func estimateSharpness(samples: [Double], width: Int, height: Int) -> Double {
        guard samples.count == width * height else {
            return 0
        }

        var edgeEnergy = 0.0
        var comparisons = 0

        for y in 0..<height {
            for x in 0..<width {
                let current = samples[(y * width) + x]

                if x + 1 < width {
                    edgeEnergy += abs(current - samples[(y * width) + x + 1])
                    comparisons += 1
                }

                if y + 1 < height {
                    edgeEnergy += abs(current - samples[((y + 1) * width) + x])
                    comparisons += 1
                }
            }
        }

        guard comparisons > 0 else {
            return 0
        }

        return min((edgeEnergy / Double(comparisons)) * 8, 1)
    }
}
