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
        CaptureQualityScoring.default.captureScore(for: self)
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
