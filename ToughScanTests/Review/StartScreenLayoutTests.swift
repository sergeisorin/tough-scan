import XCTest

final class StartScreenLayoutTests: XCTestCase {
    func testShortViewportUsesCompactLayoutSoStartActionStaysReachable() {
        let layout = StartScreenLayout.metrics(forAvailableHeight: 690)

        XCTAssertTrue(layout.isCompact)
        XCTAssertLessThan(layout.heroHeight, StartScreenLayout.regular.heroHeight)
        XCTAssertLessThan(layout.verticalSpacing, StartScreenLayout.regular.verticalSpacing)
    }
}
