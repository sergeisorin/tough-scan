import CoreGraphics
import ToughScanCore
import XCTest

final class DocumentDetectionGeometryMapperTests: XCTestCase {
    func testMapsVisionLowerLeftCoordinatesToTopLeftDocumentCoordinates() {
        let observation = DocumentDetectionGeometryMapper.geometryObservation(
            topLeft: CGPoint(x: 0.1, y: 0.9),
            topRight: CGPoint(x: 0.9, y: 0.88),
            bottomRight: CGPoint(x: 0.92, y: 0.1),
            bottomLeft: CGPoint(x: 0.08, y: 0.12),
            confidence: 0.84
        )

        XCTAssertEqual(observation.quad.topLeft.x, 0.1, accuracy: 0.001)
        XCTAssertEqual(observation.quad.topLeft.y, 0.1, accuracy: 0.001)
        XCTAssertEqual(observation.quad.bottomRight.x, 0.92, accuracy: 0.001)
        XCTAssertEqual(observation.quad.bottomRight.y, 0.9, accuracy: 0.001)
        XCTAssertEqual(observation.confidence, 0.84, accuracy: 0.001)
    }
}
