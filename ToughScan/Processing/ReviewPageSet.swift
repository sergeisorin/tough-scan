import Foundation

struct ReviewPageSet {
    struct DisplayPage: Identifiable {
        let id: UUID
        let page: ScannedPage
        let pageNumber: Int
        let isCurrent: Bool
        let canDelete: Bool

        var title: String {
            isCurrent ? "Current page" : "Page \(pageNumber)"
        }

        var textLineCount: Int {
            page.recognizedTextBlocks.count
        }

        var visualRegionCount: Int {
            page.visualRegions.count
        }

        var visualQuality: Double {
            page.snapshot.visualQuality
        }
    }

    let capturedPages: [ScannedPage]
    let currentPage: ScannedPage?

    var pagesForExport: [ScannedPage] {
        capturedPages + (currentPage.map { [$0] } ?? [])
    }

    var displayPages: [DisplayPage] {
        let capturedDisplayPages = capturedPages.enumerated().map { index, page in
            DisplayPage(
                id: page.id,
                page: page,
                pageNumber: index + 1,
                isCurrent: false,
                canDelete: true
            )
        }

        guard let currentPage else {
            return capturedDisplayPages
        }

        return capturedDisplayPages + [
            DisplayPage(
                id: currentPage.id,
                page: currentPage,
                pageNumber: capturedPages.count + 1,
                isCurrent: true,
                canDelete: false
            )
        ]
    }

    func removingCapturedPage(id: UUID) -> ReviewPageSet {
        ReviewPageSet(
            capturedPages: capturedPages.filter { $0.id != id },
            currentPage: currentPage
        )
    }
}

