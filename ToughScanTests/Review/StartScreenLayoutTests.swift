import XCTest

final class StartScreenLayoutTests: XCTestCase {
    func testShortViewportUsesCompactLayoutSoStartActionStaysReachable() {
        let layout = StartScreenLayout.metrics(forAvailableHeight: 690)

        XCTAssertTrue(layout.isCompact)
        XCTAssertLessThan(layout.heroHeight, StartScreenLayout.regular.heroHeight)
        XCTAssertLessThan(layout.verticalSpacing, StartScreenLayout.regular.verticalSpacing)
    }

    func testShortViewportFitsCompleteStartScreenWithoutScrolling() {
        let availableHeight: CGFloat = 690

        let layout = StartScreenLayout.metrics(forAvailableHeight: availableHeight)

        XCTAssertFalse(layout.usesScrolling)
        XCTAssertLessThanOrEqual(layout.estimatedContentHeight, availableHeight)
        XCTAssertLessThanOrEqual(layout.heroHeight, 104)
    }

    func testRegularViewportKeepsMoreBreathingRoomThanShortViewport() {
        let shortLayout = StartScreenLayout.metrics(forAvailableHeight: 690)
        let regularLayout = StartScreenLayout.metrics(forAvailableHeight: 852)

        XCTAssertFalse(regularLayout.isCompact)
        XCTAssertGreaterThan(regularLayout.heroHeight, shortLayout.heroHeight)
        XCTAssertGreaterThan(regularLayout.promiseRowVerticalPadding, shortLayout.promiseRowVerticalPadding)
        XCTAssertLessThanOrEqual(regularLayout.estimatedContentHeight, 852)
    }
}
