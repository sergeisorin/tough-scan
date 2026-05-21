import Foundation

struct FrameQualityMetrics: Equatable {
    let brightness: Double
    let contrast: Double
    let sharpness: Double
    let glareRisk: Double
    let documentCoverage: Double
    let geometryConfidence: Double
    let lensSmudgeConfidence: Double

    var isLikelySmudged: Bool {
        lensSmudgeConfidence >= 0.85
    }

    var captureScore: Double {
        let exposureScore = 1 - min(abs(brightness - 0.62) / 0.62, 1)
        let detailScore = (contrast * 0.35) + (sharpness * 0.35)
        let documentScore = (documentCoverage * 0.15) + (geometryConfidence * 0.15)
        let glarePenalty = glareRisk * 0.45
        let smudgePenalty = lensSmudgeConfidence * 0.50

        return (exposureScore * 0.30 + detailScore + documentScore - glarePenalty - smudgePenalty)
            .clampedToUnitRange
    }

    init(
        brightness: Double,
        contrast: Double,
        sharpness: Double,
        glareRisk: Double,
        documentCoverage: Double,
        geometryConfidence: Double,
        lensSmudgeConfidence: Double = 0
    ) {
        self.brightness = brightness.clampedToUnitRange
        self.contrast = contrast.clampedToUnitRange
        self.sharpness = sharpness.clampedToUnitRange
        self.glareRisk = glareRisk.clampedToUnitRange
        self.documentCoverage = documentCoverage.clampedToUnitRange
        self.geometryConfidence = geometryConfidence.clampedToUnitRange
        self.lensSmudgeConfidence = lensSmudgeConfidence.clampedToUnitRange
    }

    func withLensSmudgeConfidence(_ confidence: Double) -> FrameQualityMetrics {
        FrameQualityMetrics(
            brightness: brightness,
            contrast: contrast,
            sharpness: sharpness,
            glareRisk: glareRisk,
            documentCoverage: documentCoverage,
            geometryConfidence: geometryConfidence,
            lensSmudgeConfidence: confidence
        )
    }
}

extension Double {
    var clampedToUnitRange: Double {
        min(max(self, 0), 1)
    }
}
