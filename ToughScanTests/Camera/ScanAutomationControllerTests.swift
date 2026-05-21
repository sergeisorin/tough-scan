import ToughScanCore
import XCTest

final class ScanAutomationControllerTests: XCTestCase {
    func testLowLightEnablesTorchBeforeChangingExposure() {
        var controller = ScanAutomationController()
        let decision = controller.nextDecision(
            metrics: makeMetrics(brightness: 0.18, glareRisk: 0.02),
            guidance: ScanGuidance(action: .holdSteady, targetTile: nil, readyForReview: false),
            cameraState: CameraControlState(torchEnabled: false),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(decision.command, .enableTorch)
        XCTAssertEqual(decision.message, "Adding light for low-contrast text.")
    }

    func testGlareTurnsOffTorchBeforeReducingExposure() {
        var controller = ScanAutomationController()
        let decision = controller.nextDecision(
            metrics: makeMetrics(brightness: 0.92, glareRisk: 0.42),
            guidance: ScanGuidance(action: .holdSteady, targetTile: nil, readyForReview: false),
            cameraState: CameraControlState(torchEnabled: true),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(decision.command, .disableTorch)
        XCTAssertEqual(decision.message, "Reducing glare from the page.")
    }

    func testWeakTileGuidanceTargetsTileCenterForFocus() throws {
        var controller = ScanAutomationController()
        let targetTile = ScanTile(
            coordinate: TileCoordinate(column: 1, row: 2),
            visualQuality: 0.4,
            ocrConfidence: 0.2,
            textCoverage: 0.1
        )
        let decision = controller.nextDecision(
            metrics: makeMetrics(brightness: 0.62, glareRisk: 0.02),
            guidance: ScanGuidance(action: .rescanWeakText, targetTile: targetTile, readyForReview: false),
            cameraState: CameraControlState(),
            now: Date(timeIntervalSince1970: 100)
        )

        guard case let .focusAt(point) = decision.command else {
            return XCTFail("Expected focus command")
        }

        XCTAssertEqual(point.x, 0.375, accuracy: 0.001)
        XCTAssertEqual(point.y, 0.416, accuracy: 0.001)
    }

    func testCooldownPreventsRepeatedTorchCommands() {
        var controller = ScanAutomationController()
        let first = controller.nextDecision(
            metrics: makeMetrics(brightness: 0.18, glareRisk: 0.02),
            guidance: ScanGuidance(action: .holdSteady, targetTile: nil, readyForReview: false),
            cameraState: CameraControlState(torchEnabled: false),
            now: Date(timeIntervalSince1970: 100)
        )
        let second = controller.nextDecision(
            metrics: makeMetrics(brightness: 0.17, glareRisk: 0.02),
            guidance: ScanGuidance(action: .holdSteady, targetTile: nil, readyForReview: false),
            cameraState: CameraControlState(torchEnabled: false),
            now: Date(timeIntervalSince1970: 101)
        )

        XCTAssertEqual(first.command, .enableTorch)
        XCTAssertEqual(second.command, .none)
    }

    func testBlurGuidanceWinsOverCameraChangesWhenGeometryIsStable() {
        var controller = ScanAutomationController()
        let decision = controller.nextDecision(
            metrics: makeMetrics(brightness: 0.22, sharpness: 0.12, glareRisk: 0.02),
            guidance: ScanGuidance(action: .holdSteady, targetTile: nil, readyForReview: false),
            cameraState: CameraControlState(torchEnabled: false),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(decision.command, .showGuidance("Hold still so the text sharpens."))
    }

    func testLensSmudgeGuidanceWinsOverCameraChangesWhenGeometryIsStable() {
        var controller = ScanAutomationController()
        let decision = controller.nextDecision(
            metrics: makeMetrics(
                brightness: 0.22,
                sharpness: 0.7,
                glareRisk: 0.02,
                lensSmudgeConfidence: 0.94
            ),
            guidance: ScanGuidance(action: .holdSteady, targetTile: nil, readyForReview: false),
            cameraState: CameraControlState(torchEnabled: false),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(
            decision.command,
            .showGuidance("Camera lens may be smudged. Clean the lens and try another pass.")
        )
    }

    func testSmallStableDocumentCanZoomForWeakText() {
        var controller = ScanAutomationController()
        let targetTile = ScanTile(
            coordinate: TileCoordinate(column: 2, row: 3),
            visualQuality: 0.5,
            ocrConfidence: 0.2,
            textCoverage: 0.1
        )

        let decision = controller.nextDecision(
            metrics: makeMetrics(
                brightness: 0.55,
                sharpness: 0.65,
                glareRisk: 0.02,
                documentCoverage: 0.28
            ),
            guidance: ScanGuidance(action: .rescanWeakText, targetTile: targetTile, readyForReview: false),
            cameraState: CameraControlState(zoomFactor: 1, supportedZoomRange: 1...2),
            now: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(decision.command, .setZoom(1.25))
        XCTAssertEqual(decision.message, "Zooming in for small text.")
    }

    private func makeMetrics(
        brightness: Double,
        contrast: Double = 0.5,
        sharpness: Double = 0.7,
        glareRisk: Double,
        documentCoverage: Double = 0.7,
        geometryConfidence: Double = 0.9,
        lensSmudgeConfidence: Double = 0
    ) -> FrameQualityMetrics {
        FrameQualityMetrics(
            brightness: brightness,
            contrast: contrast,
            sharpness: sharpness,
            glareRisk: glareRisk,
            documentCoverage: documentCoverage,
            geometryConfidence: geometryConfidence,
            lensSmudgeConfidence: lensSmudgeConfidence
        )
    }
}
