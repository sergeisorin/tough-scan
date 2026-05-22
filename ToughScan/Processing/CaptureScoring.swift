import Foundation

struct CaptureQualityScoring: Equatable {
    static let `default` = CaptureQualityScoring(
        targetBrightness: 0.62,
        exposureWeight: 0.30,
        contrastWeight: 0.35,
        sharpnessWeight: 0.35,
        documentCoverageWeight: 0.15,
        geometryConfidenceWeight: 0.15,
        glarePenaltyWeight: 0.45,
        lensSmudgePenaltyWeight: 0.50
    )

    let targetBrightness: Double
    let exposureWeight: Double
    let contrastWeight: Double
    let sharpnessWeight: Double
    let documentCoverageWeight: Double
    let geometryConfidenceWeight: Double
    let glarePenaltyWeight: Double
    let lensSmudgePenaltyWeight: Double

    func captureScore(for metrics: FrameQualityMetrics) -> Double {
        let exposureScore = 1 - min(abs(metrics.brightness - targetBrightness) / targetBrightness, 1)
        let detailScore = (metrics.contrast * contrastWeight) + (metrics.sharpness * sharpnessWeight)
        let documentScore = (metrics.documentCoverage * documentCoverageWeight) +
            (metrics.geometryConfidence * geometryConfidenceWeight)
        let glarePenalty = metrics.glareRisk * glarePenaltyWeight
        let smudgePenalty = metrics.lensSmudgeConfidence * lensSmudgePenaltyWeight

        return (exposureScore * exposureWeight + detailScore + documentScore - glarePenalty - smudgePenalty)
            .clampedToUnitRange
    }
}

struct DocumentSnapshotScoring: Equatable {
    static let `default` = DocumentSnapshotScoring(
        frameQualityWeight: 0.55,
        ocrConfidenceWeight: 0.30,
        textCoverageWeight: 0.15
    )

    let frameQualityWeight: Double
    let ocrConfidenceWeight: Double
    let textCoverageWeight: Double

    func captureScore(
        frameQualityScore: Double,
        averageOCRConfidence: Double,
        averageTextCoverage: Double
    ) -> Double {
        ((frameQualityScore * frameQualityWeight) +
            (averageOCRConfidence * ocrConfidenceWeight) +
            (averageTextCoverage * textCoverageWeight))
            .clampedToUnitRange
    }
}
