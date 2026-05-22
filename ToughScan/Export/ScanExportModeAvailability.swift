struct ScanExportModeAvailability {
    let selectedMode: ScanExportMode
    let pages: [ScannedPage]
    private let isEligibleForRecomposition: (ScannedPage) -> Bool

    init(
        selectedMode: ScanExportMode,
        pages: [ScannedPage],
        isEligibleForRecomposition: @escaping (ScannedPage) -> Bool = RecomposedDocumentRenderer().isEligibleForRecomposition
    ) {
        self.selectedMode = selectedMode
        self.pages = pages
        self.isEligibleForRecomposition = isEligibleForRecomposition
    }

    var recomposedEligiblePageCount: Int {
        pages.filter(isEligibleForRecomposition).count
    }

    var isSelectedModeUnavailable: Bool {
        selectedMode == .recomposedPDFWithVisualMarks &&
            recomposedEligiblePageCount == 0
    }

    var message: String {
        switch selectedMode {
        case .originalImagePDF:
            return "Default. Preserves the recovered page image exactly as reviewed."
        case .recomposedPDFWithVisualMarks:
            guard !pages.isEmpty else {
                return "Cleaned/recomposed export becomes available after a page is ready."
            }

            guard recomposedEligiblePageCount > 0 else {
                return "Cleaned/recomposed export needs positioned OCR text. Use original-image PDF for this scan."
            }

            if recomposedEligiblePageCount < pages.count {
                return "Eligible pages will be recomposed; pages without positioned text will fall back to original-image PDF."
            }

            return "Experimental. Rebuilds text on a white page and overlays detected visual marks."
        }
    }
}
