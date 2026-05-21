import XCTest

final class CameraControlStateTests: XCTestCase {
    func testExposureBiasClampsToSupportedRange() {
        var state = CameraControlState(supportedExposureRange: -1.5...1.25)

        state.setExposureBias(2.8)
        XCTAssertEqual(state.exposureBias, 1.25)

        state.setExposureBias(-3)
        XCTAssertEqual(state.exposureBias, -1.5)
    }

    func testResetReturnsToNeutralCameraAssistState() {
        var state = CameraControlState(
            torchEnabled: true,
            exposureBias: 1.2,
            supportedExposureRange: -2...2
        )

        state.reset()

        XCTAssertFalse(state.torchEnabled)
        XCTAssertEqual(state.exposureBias, 0)
        XCTAssertEqual(state.exposureLabel, "Neutral")
    }

    func testExposureLabelsDescribeBrightnessDirection() {
        var state = CameraControlState(supportedExposureRange: -2...2)

        state.setExposureBias(-0.5)
        XCTAssertEqual(state.exposureLabel, "Darker")

        state.setExposureBias(0)
        XCTAssertEqual(state.exposureLabel, "Neutral")

        state.setExposureBias(0.5)
        XCTAssertEqual(state.exposureLabel, "Brighter")
    }
}

