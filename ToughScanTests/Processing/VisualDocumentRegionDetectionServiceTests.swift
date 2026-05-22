import ToughScanCore
import XCTest

final class VisualDocumentRegionDetectionServiceTests: XCTestCase {
    func testRunsDetectionOffMainThread() async {
        let service = VisualDocumentRegionDetectionService { _, _ in
            XCTAssertFalse(Thread.isMainThread)
            return []
        }

        let regions = await service.detectVisualRegions(in: makeImage(), textBlocks: [])

        XCTAssertEqual(regions, [])
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 20, height: 20))
        }
    }
}
