import ToughScanCore
import XCTest

final class ReviewPageSetTests: XCTestCase {
    func testPagesForExportKeepCapturedPagesBeforeCurrentPage() {
        let firstCaptured = makePage(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "First")
        let secondCaptured = makePage(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, text: "Second")
        let current = makePage(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, text: "Current")

        let pageSet = ReviewPageSet(
            capturedPages: [firstCaptured, secondCaptured],
            currentPage: current
        )

        XCTAssertEqual(pageSet.pagesForExport.map(\.id), [
            firstCaptured.id,
            secondCaptured.id,
            current.id
        ])
    }

    func testRemovingCapturedPageExcludesItFromExport() {
        let firstCaptured = makePage(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, text: "First")
        let secondCaptured = makePage(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, text: "Second")
        let current = makePage(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, text: "Current")

        let pageSet = ReviewPageSet(
            capturedPages: [firstCaptured, secondCaptured],
            currentPage: current
        )
        .removingCapturedPage(id: firstCaptured.id)

        XCTAssertEqual(pageSet.pagesForExport.map(\.id), [
            secondCaptured.id,
            current.id
        ])
    }

    func testCurrentPageRemainsIncludedAndNonDeletable() throws {
        let current = makePage(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, text: "Current")

        let pageSet = ReviewPageSet(capturedPages: [], currentPage: current)
        let displayPage = try XCTUnwrap(pageSet.displayPages.first)

        XCTAssertEqual(pageSet.pagesForExport.map(\.id), [current.id])
        XCTAssertTrue(displayPage.isCurrent)
        XCTAssertFalse(displayPage.canDelete)
        XCTAssertEqual(displayPage.title, "Current page")
        XCTAssertEqual(displayPage.textLineCount, 1)
        XCTAssertEqual(displayPage.visualQuality, 0.82)
    }

    func testCapturedPagesKeepVisualRegions() throws {
        let current = makePage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            text: "Current",
            visualRegions: [makeVisualRegion()]
        )

        let pageSet = ReviewPageSet(capturedPages: [current], currentPage: nil)
        let displayPage = try XCTUnwrap(pageSet.displayPages.first)

        XCTAssertEqual(pageSet.pagesForExport.first?.visualRegions.count, 1)
        XCTAssertEqual(displayPage.visualRegionCount, 1)
    }

    private func makePage(
        id: UUID,
        text: String,
        visualRegions: [VisualDocumentRegion] = []
    ) -> ScannedPage {
        ScannedPage(
            id: id,
            snapshot: DocumentSnapshot(
                image: makeImage(),
                visualQuality: 0.82
            ),
            recognizedTextBlocks: [
                RecognizedTextBlock(
                    text: text,
                    confidence: 0.91,
                    languageCode: "en",
                    tileCoordinates: [TileCoordinate(column: 0, row: 0)]
                )
            ],
            visualRegions: visualRegions
        )
    }

    private func makeVisualRegion() -> VisualDocumentRegion {
        VisualDocumentRegion(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
            kind: .stampOrSignature,
            boundingBox: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.2),
            confidence: 0.78,
            image: makeImage()
        )
    }

    private func makeImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
        }
    }
}

