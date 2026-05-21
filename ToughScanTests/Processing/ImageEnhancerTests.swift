import XCTest

final class ImageEnhancerTests: XCTestCase {
    func testLowContrastProfileRaisesContrastAboveDefault() {
        let enhancer = ImageEnhancer()
        let profile = enhancer.enhancementProfile(
            for: makeMetrics(brightness: 0.58, contrast: 0.12, sharpness: 0.7, glareRisk: 0.02)
        )

        XCTAssertGreaterThan(profile.contrast, ImageEnhancementProfile.default.contrast)
        XCTAssertEqual(profile.saturation, 0)
    }

    func testGlareProfileAvoidsBrightnessBoost() {
        let enhancer = ImageEnhancer()
        let profile = enhancer.enhancementProfile(
            for: makeMetrics(brightness: 0.92, contrast: 0.35, sharpness: 0.6, glareRisk: 0.38)
        )

        XCTAssertLessThanOrEqual(profile.brightness, 0)
        XCTAssertLessThan(profile.contrast, ImageEnhancementProfile.default.contrast)
    }

    func testLowSharpnessProfileDoesNotOverSharpen() {
        let enhancer = ImageEnhancer()
        let profile = enhancer.enhancementProfile(
            for: makeMetrics(brightness: 0.55, contrast: 0.45, sharpness: 0.12, glareRisk: 0.02)
        )

        XCTAssertLessThanOrEqual(profile.sharpness, ImageEnhancementProfile.default.sharpness)
    }

    private func makeMetrics(
        brightness: Double,
        contrast: Double,
        sharpness: Double,
        glareRisk: Double
    ) -> FrameQualityMetrics {
        FrameQualityMetrics(
            brightness: brightness,
            contrast: contrast,
            sharpness: sharpness,
            glareRisk: glareRisk,
            documentCoverage: 0.7,
            geometryConfidence: 0.9
        )
    }
}
