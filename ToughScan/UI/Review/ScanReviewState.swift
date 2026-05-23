import ToughScanCore

struct ScanReviewState {
    let session: ProgressiveScanSession
    let snapshot: DocumentSnapshot?
    let capturedPages: [ScannedPage]
    let structuredRecognitionCoordinator: StructuredDocumentRecognitionCoordinator
    let visualRegionDetectionCoordinator: VisualDocumentRegionDetectionCoordinator
    let selectedExportMode: ScanExportMode
    var confirmedWords: [ConfirmedRecognizedWord] = []

    var currentPage: ScannedPage? {
        guard let snapshot else {
            return nil
        }

        return ScannedPage(
            id: snapshot.id,
            snapshot: snapshot,
            recognizedTextBlocks: session.recognizedTextBlocks,
            recognizedWords: session.recognizedWords,
            confirmedWords: confirmedWords,
            structuredDocument: currentStructuredDocument,
            visualRegions: currentVisualRegions
        )
    }

    var currentStructuredDocument: StructuredDocument? {
        guard let snapshot else {
            return nil
        }

        return structuredRecognitionCoordinator.document(for: snapshot.id)
    }

    var structuredRecognitionMessage: String? {
        structuredRecognitionCoordinator.message
    }

    var currentVisualRegions: [VisualDocumentRegion] {
        guard let snapshot else {
            return []
        }

        return visualRegionDetectionCoordinator.regions(for: snapshot.id)
    }

    var pageSet: ReviewPageSet {
        ReviewPageSet(capturedPages: capturedPages, currentPage: currentPage)
    }

    var pagesForExport: [ScannedPage] {
        pageSet.pagesForExport
    }

    var recoveredTextSummary: ReviewTextSourceSummary {
        ReviewTextSourceBuilder.makeSummary(from: pagesForExport)
    }

    var recoveredTextSource: String {
        recoveredTextSummary.text
    }

    var documentIntelligenceSource: String {
        recoveredTextSource
    }

    var documentIntelligenceSourceID: String {
        documentIntelligenceSource
    }

    var showsImageOnlyExportMessage: Bool {
        !pagesForExport.isEmpty && recoveredTextSummary.isEmpty
    }

    var exportModeAvailability: ScanExportModeAvailability {
        ScanExportModeAvailability(selectedMode: selectedExportMode, pages: pagesForExport)
    }

    var recomposedEligiblePageCount: Int {
        exportModeAvailability.recomposedEligiblePageCount
    }

    var isSelectedExportModeUnavailable: Bool {
        exportModeAvailability.isSelectedModeUnavailable
    }

    var exportModeMessage: String {
        exportModeAvailability.message
    }
}
