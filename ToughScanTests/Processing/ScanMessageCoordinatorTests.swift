import XCTest

final class ScanMessageCoordinatorTests: XCTestCase {
    func testQualityMessageReplacesGuidance() {
        var coordinator = ScanMessageCoordinator()

        coordinator.submit("Keep scanning the highlighted region.", priority: .guidance)
        coordinator.submit("Camera lens may be smudged.", priority: .qualityWarning)

        XCTAssertEqual(coordinator.currentMessage, "Camera lens may be smudged.")
    }

    func testGuidanceDoesNotReplaceError() {
        var coordinator = ScanMessageCoordinator()

        coordinator.submit("Live OCR failed.", priority: .error)
        coordinator.submit("Keep scanning the highlighted region.", priority: .guidance)

        XCTAssertEqual(coordinator.currentMessage, "Live OCR failed.")
    }

    func testSamePriorityMessageReplacesPreviousMessage() {
        var coordinator = ScanMessageCoordinator()

        coordinator.submit("Hold steady.", priority: .guidance)
        coordinator.submit("Page has enough evidence for review.", priority: .guidance)

        XCTAssertEqual(coordinator.currentMessage, "Page has enough evidence for review.")
    }
}
