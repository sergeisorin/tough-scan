import ToughScanCore
import XCTest

final class VisualDocumentRegionDetectionCoordinatorTests: XCTestCase {
    func testCompleteStoresRegionsForMatchingSnapshot() {
        var coordinator = VisualDocumentRegionDetectionCoordinator()
        let snapshotID = UUID()
        let request = coordinator.begin(snapshotID: snapshotID)
        let regions = [makeRegion()]

        coordinator.complete(request, regions: regions)

        XCTAssertEqual(coordinator.regions, regions)
        XCTAssertEqual(coordinator.regions(for: snapshotID), regions)
        XCTAssertNil(coordinator.message)
    }

    func testOlderCompletionDoesNotReplaceNewerSnapshot() {
        var coordinator = VisualDocumentRegionDetectionCoordinator()
        let olderRequest = coordinator.begin(snapshotID: UUID())
        let newerRequest = coordinator.begin(snapshotID: UUID())
        let olderRegions = [makeRegion(x: 0.1)]
        let newerRegions = [makeRegion(x: 0.6)]

        coordinator.complete(olderRequest, regions: olderRegions)
        XCTAssertEqual(coordinator.regions, [])
        XCTAssertEqual(coordinator.message, VisualDocumentRegionDetectionCoordinator.analyzingMessage)

        coordinator.complete(newerRequest, regions: newerRegions)
        XCTAssertEqual(coordinator.regions, newerRegions)
        XCTAssertNil(coordinator.message)
    }

    func testClearRemovesRegionsAndMessage() {
        var coordinator = VisualDocumentRegionDetectionCoordinator()
        let request = coordinator.begin(snapshotID: UUID())
        coordinator.complete(request, regions: [makeRegion()])

        coordinator.clear()

        XCTAssertEqual(coordinator.regions, [])
        XCTAssertNil(coordinator.message)
    }

    private func makeRegion(x: Double = 0.2) -> VisualDocumentRegion {
        VisualDocumentRegion(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
            kind: .stampOrSignature,
            boundingBox: NormalizedRect(x: x, y: 0.3, width: 0.2, height: 0.1),
            confidence: 0.84,
            image: UIImage()
        )
    }
}
