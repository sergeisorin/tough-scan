import UIKit
import XCTest

final class DocumentSnapshotTests: XCTestCase {
    func testSnapshotRankingPrefersHigherCaptureScoreOverVisualQualityOnly() {
        let sharpText = DocumentSnapshot(
            image: makeImage(),
            visualQuality: 0.72,
            captureScore: 0.90,
            averageOCRConfidence: 0.88,
            textCoverage: 0.64
        )
        let prettyButWeakText = DocumentSnapshot(
            image: makeImage(),
            visualQuality: 0.88,
            captureScore: 0.62,
            averageOCRConfidence: 0.31,
            textCoverage: 0.22
        )

        XCTAssertTrue(sharpText.isBetterThan(prettyButWeakText))
        XCTAssertFalse(prettyButWeakText.isBetterThan(sharpText))
    }

    func testSnapshotCaptureScoreFallsBackToVisualQualityForExistingCallers() {
        let snapshot = DocumentSnapshot(
            image: makeImage(),
            visualQuality: 0.74
        )

        XCTAssertEqual(snapshot.captureScore, 0.74)
        XCTAssertEqual(snapshot.averageOCRConfidence, 0)
        XCTAssertEqual(snapshot.textCoverage, 0)
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 80, height: 120)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 120))
            UIColor.black.setFill()
            context.fill(CGRect(x: 8, y: 20, width: 64, height: 2))
        }
    }
}
