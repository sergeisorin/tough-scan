import ToughScanCore

struct ScanReviewState {
    let session: ProgressiveScanSession
    let snapshot: DocumentSnapshot?
    let capturedPages: [ScannedPage]
    let structuredRecognitionCoordinator: StructuredDocumentRecognitionCoordinator
    let visualRegionDetectionCoordinator: VisualDocumentRegionDetectionCoordinator
    let selectedExportMode: ScanExportMode

    private let recomposedDocumentRenderer = RecomposedDocumentRenderer()

    var currentPage: ScannedPage? {
        guard let snapshot else {
            return nil
        }

        return ScannedPage(
            id: snapshot.id,
            snapshot: snapshot,
            recognizedTextBlocks: session.recognizedTextBlocks,
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

    var recomposedEligiblePageCount: Int {
        pagesForExport.filter { recomposedDocumentRenderer.isEligibleForRecomposition($0) }.count
    }

    var isSelectedExportModeUnavailable: Bool {
        selectedExportMode == .recomposedPDFWithVisualMarks &&
            recomposedEligiblePageCount == 0
    }

    var exportModeMessage: String {
        switch selectedExportMode {
        case .originalImagePDF:
            return "Default. Preserves the recovered page image exactly as reviewed."
        case .recomposedPDFWithVisualMarks:
            guard !pagesForExport.isEmpty else {
                return "Cleaned/recomposed export becomes available after a page is ready."
            }

            guard recomposedEligiblePageCount > 0 else {
                return "Cleaned/recomposed export needs positioned OCR text. Use original-image PDF for this scan."
            }

            if recomposedEligiblePageCount < pagesForExport.count {
                return "Eligible pages will be recomposed; pages without positioned text will fall back to original-image PDF."
            }

            return "Experimental. Rebuilds text on a white page and overlays detected visual marks."
        }
    }
}
