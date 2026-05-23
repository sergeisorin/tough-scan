import SwiftUI
import ToughScanCore

struct ScanReviewView: View {
    let session: ProgressiveScanSession
    let snapshot: DocumentSnapshot?
    let capturedPages: [ScannedPage]
    let initialConfirmedWords: [ConfirmedRecognizedWord]
    let onAddPage: (StructuredDocument?, [VisualDocumentRegion], [ConfirmedRecognizedWord]) -> Void
    let onRemoveCapturedPage: (ScannedPage.ID) -> Void
    let onRescan: (RecognizedWord?, [ConfirmedRecognizedWord]) -> Void

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
    @State private var confirmationDrafts: [String: String] = [:]
    @State private var confirmedWordText: [String: String] = [:]

    private let exportService = ScanExportService()
    private let structuredRecognitionService: any StructuredDocumentRecognizing
    private let visualRegionDetectionService: VisualDocumentRegionDetectionService
    private let intelligenceService = DocumentIntelligenceService()
    private let intelligenceAvailabilityProvider: any DocumentIntelligenceAvailabilityProviding
    private let recoveredTextCopyController: RecoveredTextCopyController

    init(
        session: ProgressiveScanSession,
        snapshot: DocumentSnapshot?,
        capturedPages: [ScannedPage],
        initialConfirmedWords: [ConfirmedRecognizedWord] = [],
        onAddPage: @escaping (StructuredDocument?, [VisualDocumentRegion], [ConfirmedRecognizedWord]) -> Void,
        onRemoveCapturedPage: @escaping (ScannedPage.ID) -> Void,
        onRescan: @escaping (RecognizedWord?, [ConfirmedRecognizedWord]) -> Void,
        intelligenceAvailabilityProvider: any DocumentIntelligenceAvailabilityProviding = SystemDocumentIntelligenceAvailabilityProvider(),
        recoveredTextCopyController: RecoveredTextCopyController = RecoveredTextCopyController(),
        structuredRecognitionService: any StructuredDocumentRecognizing = StructuredDocumentRecognitionService(),
        visualRegionDetectionService: VisualDocumentRegionDetectionService = VisualDocumentRegionDetectionService()
    ) {
        self.session = session
        self.snapshot = snapshot
        self.capturedPages = capturedPages
        self.initialConfirmedWords = initialConfirmedWords
        self.onAddPage = onAddPage
        self.onRemoveCapturedPage = onRemoveCapturedPage
        self.onRescan = onRescan
        self.intelligenceAvailabilityProvider = intelligenceAvailabilityProvider
        self.recoveredTextCopyController = recoveredTextCopyController
        self.structuredRecognitionService = structuredRecognitionService
        self.visualRegionDetectionService = visualRegionDetectionService
        _confirmedWordText = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: initialConfirmedWords.map {
                    (WordConfirmationRequestBuilder.requestID(for: $0.word), $0.resolvedText)
                }
            )
        )
    }

    private var reviewState: ScanReviewState {
        ScanReviewState(
            session: session,
            snapshot: snapshot,
            capturedPages: capturedPages,
            structuredRecognitionCoordinator: structuredRecognitionCoordinator,
            visualRegionDetectionCoordinator: visualRegionDetectionCoordinator,
            selectedExportMode: selectedExportMode,
            confirmedWords: confirmedWords
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Review recovered document")
                        .font(.title2.weight(.semibold))
                    Text("Check the scanned page first, then use the confidence grid to decide whether weak areas need another pass.")
                        .foregroundStyle(.secondary)
                }

                if let snapshot {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scanned page")
                            .font(.headline)
                        Text("This is the recovered page image that will be used for the default PDF export.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(uiImage: snapshot.previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityLabel("Scanned page preview")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Region confidence (4x6 grid)")
                        .font(.headline)
                    Text("Green is good enough. Orange is optional. Red or gray should be scanned again if possible.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NormalizedDocumentPreviewView(
                        snapshot: snapshot,
                        confidenceMap: session.confidenceMap,
                        showsOverlay: true,
                        recognizedWords: session.recognizedWords,
                        showsTextLineOverlay: false,
                        showsWordOverlay: true
                    )
                    .frame(height: 320)
                }

                ConfidenceLegend()

                if !confirmationRequests.isEmpty {
                    ConfirmationRequestsPanel(
                        requests: confirmationRequests,
                        confirmedWords: confirmedWords,
                        confirmedWordText: $confirmedWordText,
                        confirmationDrafts: $confirmationDrafts,
                        onRescan: onRescan
                    )
                }

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
                    Button("Rescan weak areas") {
                        onRescan(nil, confirmedWords)
                    }
                        .buttonStyle(.bordered)

                    Button("Copy recovered text", action: copyRecoveredText)
                        .buttonStyle(.bordered)
                        .disabled(recoveredTextSummary.isEmpty)

                    Button("Add another page") {
                        onAddPage(currentStructuredDocument, currentVisualRegions, confirmedWords)
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
        reviewState.currentPage
    }

    private var currentStructuredDocument: StructuredDocument? {
        reviewState.currentStructuredDocument
    }

    private var structuredRecognitionMessage: String? {
        reviewState.structuredRecognitionMessage
    }

    private var currentVisualRegions: [VisualDocumentRegion] {
        reviewState.currentVisualRegions
    }

    private var pagesForExport: [ScannedPage] {
        reviewState.pagesForExport
    }

    private var pageSet: ReviewPageSet {
        reviewState.pageSet
    }

    private var documentIntelligenceSource: String {
        reviewState.documentIntelligenceSource
    }

    private var documentIntelligenceSourceID: String {
        reviewState.documentIntelligenceSourceID
    }

    private var recoveredTextSummary: ReviewTextSourceSummary {
        reviewState.recoveredTextSummary
    }

    private var recoveredTextSource: String {
        reviewState.recoveredTextSource
    }

    private var confirmationRequests: [WordConfirmationRequest] {
        WordConfirmationRequestBuilder.makeRequests(from: session.recognizedWords)
    }

    private var confirmedWords: [ConfirmedRecognizedWord] {
        ConfirmedWordResolver.makeConfirmedWords(
            from: session.recognizedWords,
            confirmedTextByID: confirmedWordText
        )
    }

    private var showsImageOnlyExportMessage: Bool {
        reviewState.showsImageOnlyExportMessage
    }

    private var recomposedEligiblePageCount: Int {
        reviewState.recomposedEligiblePageCount
    }

    private var isSelectedExportModeUnavailable: Bool {
        reviewState.isSelectedExportModeUnavailable
    }

    private var exportModeMessage: String {
        reviewState.exportModeMessage
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

private struct ConfirmationRequestsPanel: View {
    let requests: [WordConfirmationRequest]
    let confirmedWords: [ConfirmedRecognizedWord]
    @Binding var confirmedWordText: [String: String]
    @Binding var confirmationDrafts: [String: String]
    let onRescan: (RecognizedWord?, [ConfirmedRecognizedWord]) -> Void

    private var confirmedCount: Int {
        requests.filter { confirmedWordText[$0.id] != nil }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confirmation requests")
                        .font(.headline)
                    Text("Confirm the words Tough Scan is not fully sure about, or rescan the highlighted text.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(confirmedCount)/\(requests.count)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(requests) { request in
                ConfirmationRequestCard(
                    request: request,
                    draft: Binding(
                        get: { confirmationDrafts[request.id] ?? request.suggestedText },
                        set: { confirmationDrafts[request.id] = $0 }
                    ),
                    confirmedText: confirmedWordText[request.id],
                    onConfirm: {
                        confirmedWordText[request.id] = confirmationDrafts[request.id] ?? request.suggestedText
                    },
                    onEditAgain: {
                        confirmedWordText[request.id] = nil
                    },
                    onRescan: {
                        onRescan(request.word, confirmedWords)
                    }
                )
            }
        }
    }

}

private struct ConfirmationRequestCard: View {
    let request: WordConfirmationRequest
    @Binding var draft: String
    let confirmedText: String?
    let onConfirm: () -> Void
    let onEditAgain: () -> Void
    let onRescan: () -> Void

    private var style: ConfidenceStateStyle {
        ConfidenceStateStyle.style(for: confirmedText == nil ? request.state : .successful)
    }

    private var isHebrew: Bool {
        request.word.languageCode.contains("he")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: style.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(style.color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(request.label)
                        .font(.subheadline.weight(.semibold))
                    Text(confirmedText == nil ? request.note : "Confirmed by you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if confirmedText != nil {
                    Button("Edit again", action: onEditAgain)
                        .font(.caption.weight(.medium))
                        .buttonStyle(.borderless)
                }
            }

            if let confirmedText {
                Text(confirmedText)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(isHebrew ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: isHebrew ? .trailing : .leading)
                    .padding(10)
                    .background(style.color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text(request.contextText)
                    .font(.callout)
                    .multilineTextAlignment(isHebrew ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: isHebrew ? .trailing : .leading)
                    .padding(10)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                TextField("Suggested cleanup", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(isHebrew ? .trailing : .leading)
                    .padding(10)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 10) {
                    Button("Confirm", action: onConfirm)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)

                    Button("Rescan", action: onRescan)
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(style.color.opacity(confirmedText == nil ? 0.08 : 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

