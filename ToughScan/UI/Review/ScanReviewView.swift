import SwiftUI
import ToughScanCore

struct ScanReviewView: View {
    let session: ProgressiveScanSession
    let snapshot: DocumentSnapshot?
    let capturedPages: [ScannedPage]
    let onAddPage: (StructuredDocument?, [VisualDocumentRegion]) -> Void
    let onRemoveCapturedPage: (ScannedPage.ID) -> Void
    let onRescan: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var activeExportBundle: ScanExportBundle?
    @State private var exportErrorMessage: String?
    @State private var structuredRecognitionCoordinator = StructuredDocumentRecognitionCoordinator()
    @State private var visualRegionDetectionCoordinator = VisualDocumentRegionDetectionCoordinator()
    @State private var documentIntelligenceAvailability: DocumentIntelligenceAvailability = .unknown
    @State private var intelligenceRunCoordinator = DocumentIntelligenceRunCoordinator()
    @State private var includesIntelligenceNotesInExport = false
    @State private var selectedExportMode: ScanExportMode = .originalImagePDF
    @State private var copyConfirmationMessage: String?

    private let exportService = ScanExportService()
    private let recomposedDocumentRenderer = RecomposedDocumentRenderer()
    private let structuredRecognitionService: any StructuredDocumentRecognizing
    private let visualRegionDetectionService: VisualDocumentRegionDetectionService
    private let intelligenceService = DocumentIntelligenceService()
    private let intelligenceAvailabilityProvider: any DocumentIntelligenceAvailabilityProviding
    private let recoveredTextCopyController: RecoveredTextCopyController

    init(
        session: ProgressiveScanSession,
        snapshot: DocumentSnapshot?,
        capturedPages: [ScannedPage],
        onAddPage: @escaping (StructuredDocument?, [VisualDocumentRegion]) -> Void,
        onRemoveCapturedPage: @escaping (ScannedPage.ID) -> Void,
        onRescan: @escaping () -> Void,
        intelligenceAvailabilityProvider: any DocumentIntelligenceAvailabilityProviding = SystemDocumentIntelligenceAvailabilityProvider(),
        recoveredTextCopyController: RecoveredTextCopyController = RecoveredTextCopyController(),
        structuredRecognitionService: any StructuredDocumentRecognizing = StructuredDocumentRecognitionService(),
        visualRegionDetectionService: VisualDocumentRegionDetectionService = VisualDocumentRegionDetectionService()
    ) {
        self.session = session
        self.snapshot = snapshot
        self.capturedPages = capturedPages
        self.onAddPage = onAddPage
        self.onRemoveCapturedPage = onRemoveCapturedPage
        self.onRescan = onRescan
        self.intelligenceAvailabilityProvider = intelligenceAvailabilityProvider
        self.recoveredTextCopyController = recoveredTextCopyController
        self.structuredRecognitionService = structuredRecognitionService
        self.visualRegionDetectionService = visualRegionDetectionService
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review recovered document")
                        .font(.title2.weight(.semibold))
                    Text("Use the overlay to decide whether to export or scan weak areas again.")
                        .foregroundStyle(.secondary)
                }

                NormalizedDocumentPreviewView(
                    snapshot: snapshot,
                    confidenceMap: session.confidenceMap,
                    showsOverlay: true,
                    recognizedTextBlocks: session.recognizedTextBlocks
                )
                .frame(height: 420)

                ConfidenceLegend()

                if let snapshot {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Selectable image text")
                            .font(.headline)
                        Text("Use Live Text here to select, copy, or open detected data from the reconstructed page.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        LiveTextImageView(image: snapshot.image)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                RecognizedTextPanel(blocks: session.recognizedTextBlocks)

                StructuredDocumentPanel(
                    document: currentStructuredDocument,
                    message: structuredRecognitionMessage
                )

                VisualMarksPanel(
                    regions: currentVisualRegions,
                    message: visualRegionDetectionCoordinator.message
                )

                IntelligenceReviewPanel(
                    availability: documentIntelligenceAvailability,
                    sourceText: documentIntelligenceSource,
                    notes: intelligenceRunCoordinator.notes,
                    runState: intelligenceRunCoordinator.state,
                    onRunAction: runDocumentIntelligence
                )

                PageSetPanel(
                    pageSet: pageSet,
                    onRemoveCapturedPage: onRemoveCapturedPage
                )

                if let exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let copyConfirmationMessage {
                    Text(copyConfirmationMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if showsImageOnlyExportMessage {
                    Text("Image-only PDF export is available, but no copyable text is ready yet. Rescan weak areas to improve text recovery.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                CopyableTextPanel(summary: recoveredTextSummary)

                ExportModePanel(
                    selectedMode: $selectedExportMode,
                    message: exportModeMessage
                )

                if !intelligenceRunCoordinator.notes.isEmpty {
                    Toggle("Include intelligence notes in export", isOn: $includesIntelligenceNotesInExport)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button("Rescan weak areas", action: onRescan)
                        .buttonStyle(.bordered)

                    Button("Copy recovered text", action: copyRecoveredText)
                        .buttonStyle(.bordered)
                        .disabled(recoveredTextSummary.isEmpty)

                    Button("Add another page") {
                        onAddPage(currentStructuredDocument, currentVisualRegions)
                    }
                        .buttonStyle(.bordered)
                        .disabled(snapshot == nil)

                    Button("Export local result", action: prepareExport)
                    .buttonStyle(.borderedProminent)
                    .disabled(pagesForExport.isEmpty || isSelectedExportModeUnavailable)
                }
                .controlSize(.large)
            }
            .padding(20)
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeExportBundle, onDismiss: cleanupActiveExportBundle) { bundle in
            ShareSheetView(activityItems: bundle.fileURLs) {
                cleanupActiveExportBundle()
            }
        }
        .onDisappear {
            cleanupActiveExportBundle()
        }
        .task(id: snapshot?.id) {
            await recognizeStructuredDocument()
        }
        .task(id: snapshot?.id) {
            await detectVisualRegions()
        }
        .task {
            refreshDocumentIntelligenceAvailability()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            refreshDocumentIntelligenceAvailability()
        }
        .onChange(of: documentIntelligenceSourceID) { _, _ in
            intelligenceRunCoordinator.sourceDidChange(to: documentIntelligenceSource)
            includesIntelligenceNotesInExport = false
        }
    }

    private var currentPage: ScannedPage? {
        guard let snapshot else {
            return nil
        }

        return ScannedPage(
            id: snapshot.id,
            snapshot: snapshot,
            recognizedTextBlocks: session.recognizedTextBlocks,
            structuredDocument: structuredRecognitionCoordinator.document(for: snapshot.id),
            visualRegions: currentVisualRegions
        )
    }

    private var currentStructuredDocument: StructuredDocument? {
        guard let snapshot else {
            return nil
        }

        return structuredRecognitionCoordinator.document(for: snapshot.id)
    }

    private var structuredRecognitionMessage: String? {
        structuredRecognitionCoordinator.message
    }

    private var currentVisualRegions: [VisualDocumentRegion] {
        guard let snapshot else {
            return []
        }

        return visualRegionDetectionCoordinator.regions(for: snapshot.id)
    }

    private var pagesForExport: [ScannedPage] {
        pageSet.pagesForExport
    }

    private var pageSet: ReviewPageSet {
        ReviewPageSet(capturedPages: capturedPages, currentPage: currentPage)
    }

    private var documentIntelligenceSource: String {
        recoveredTextSource
    }

    private var documentIntelligenceSourceID: String {
        documentIntelligenceSource
    }

    private var recoveredTextSummary: ReviewTextSourceSummary {
        ReviewTextSourceBuilder.makeSummary(from: pagesForExport)
    }

    private var recoveredTextSource: String {
        recoveredTextSummary.text
    }

    private var showsImageOnlyExportMessage: Bool {
        !pagesForExport.isEmpty && recoveredTextSummary.isEmpty
    }

    private var recomposedEligiblePageCount: Int {
        pagesForExport.filter { recomposedDocumentRenderer.isEligibleForRecomposition($0) }.count
    }

    private var isSelectedExportModeUnavailable: Bool {
        selectedExportMode == .recomposedPDFWithVisualMarks &&
            recomposedEligiblePageCount == 0
    }

    private var exportModeMessage: String {
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

    private func refreshDocumentIntelligenceAvailability() {
        documentIntelligenceAvailability = intelligenceAvailabilityProvider.currentAvailability()
    }

    private func prepareExport() {
        do {
            cleanupActiveExportBundle()
            activeExportBundle = try exportService.makeExportBundle(
                from: pagesForExport,
                intelligenceNotes: intelligenceRunCoordinator.notes,
                includesIntelligenceNotes: includesIntelligenceNotesInExport,
                exportMode: selectedExportMode
            )
            exportErrorMessage = nil
        } catch {
            exportErrorMessage = "Could not prepare the local export. Try rescanning the page."
        }
    }

    private func cleanupActiveExportBundle() {
        activeExportBundle?.cleanup()
        activeExportBundle = nil
    }

    private func copyRecoveredText() {
        copyConfirmationMessage = recoveredTextCopyController.copyRecoveredTextResult(from: pagesForExport).message
    }

    @MainActor
    private func recognizeStructuredDocument() async {
        guard let snapshot else {
            structuredRecognitionCoordinator.clear()
            return
        }

        let request = structuredRecognitionCoordinator.begin(snapshotID: snapshot.id)

        do {
            let document = try await structuredRecognitionService.recognizeDocument(in: snapshot.image)
            structuredRecognitionCoordinator.complete(request, document: document)
        } catch {
            structuredRecognitionCoordinator.fail(request)
        }
    }

    @MainActor
    private func detectVisualRegions() async {
        guard let snapshot else {
            visualRegionDetectionCoordinator.clear()
            return
        }

        let request = visualRegionDetectionCoordinator.begin(snapshotID: snapshot.id)
        let regions = await visualRegionDetectionService.detectVisualRegions(
            in: snapshot.image,
            textBlocks: session.recognizedTextBlocks
        )
        visualRegionDetectionCoordinator.complete(request, regions: regions)
    }

    @MainActor
    private func runDocumentIntelligence(_ action: DocumentIntelligenceAction) {
        Task {
            await performDocumentIntelligence(action)
        }
    }

    @MainActor
    private func performDocumentIntelligence(_ action: DocumentIntelligenceAction) async {
        guard let request = intelligenceRunCoordinator.begin(
            action: action,
            sourceText: documentIntelligenceSource,
            availability: documentIntelligenceAvailability
        ) else {
            return
        }

        do {
            let result = try await intelligenceService.perform(request.action, sourceText: request.sourceText)
            intelligenceRunCoordinator.complete(request, result: result)
        } catch DocumentIntelligenceService.Error.generationFailed(let failure) {
            intelligenceRunCoordinator.fail(request, failure: failure)
        } catch {
            intelligenceRunCoordinator.fail(request, failure: .generic)
        }
    }
}

