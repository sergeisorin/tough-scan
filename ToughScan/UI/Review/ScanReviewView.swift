import SwiftUI
import ToughScanCore

struct ScanReviewView: View {
    let session: ProgressiveScanSession
    let snapshot: DocumentSnapshot?
    let capturedPages: [ScannedPage]
    let onAddPage: (StructuredDocument?) -> Void
    let onRemoveCapturedPage: (ScannedPage.ID) -> Void
    let onRescan: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @State private var activeExportBundle: ScanExportBundle?
    @State private var exportErrorMessage: String?
    @State private var structuredDocument: StructuredDocument?
    @State private var structuredRecognitionMessage: String?
    @State private var documentIntelligenceAvailability: DocumentIntelligenceAvailability = .unknown
    @State private var intelligenceRunCoordinator = DocumentIntelligenceRunCoordinator()
    @State private var includesIntelligenceNotesInExport = false
    @State private var copyConfirmationMessage: String?

    private let exportService = ScanExportService()
    private let structuredRecognitionService = StructuredDocumentRecognitionService()
    private let intelligenceService = DocumentIntelligenceService()
    private let intelligenceAvailabilityProvider: any DocumentIntelligenceAvailabilityProviding
    private let recoveredTextCopyController: RecoveredTextCopyController

    init(
        session: ProgressiveScanSession,
        snapshot: DocumentSnapshot?,
        capturedPages: [ScannedPage],
        onAddPage: @escaping (StructuredDocument?) -> Void,
        onRemoveCapturedPage: @escaping (ScannedPage.ID) -> Void,
        onRescan: @escaping () -> Void,
        intelligenceAvailabilityProvider: any DocumentIntelligenceAvailabilityProviding = SystemDocumentIntelligenceAvailabilityProvider(),
        recoveredTextCopyController: RecoveredTextCopyController = RecoveredTextCopyController()
    ) {
        self.session = session
        self.snapshot = snapshot
        self.capturedPages = capturedPages
        self.onAddPage = onAddPage
        self.onRemoveCapturedPage = onRemoveCapturedPage
        self.onRescan = onRescan
        self.intelligenceAvailabilityProvider = intelligenceAvailabilityProvider
        self.recoveredTextCopyController = recoveredTextCopyController
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
                    document: structuredDocument,
                    message: structuredRecognitionMessage
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
                        .disabled(recoveredTextSource.isEmpty)

                    Button("Add another page") {
                        onAddPage(structuredDocument)
                    }
                        .buttonStyle(.bordered)
                        .disabled(snapshot == nil)

                    Button("Export local result", action: prepareExport)
                    .buttonStyle(.borderedProminent)
                    .disabled(pagesForExport.isEmpty)
                }
                .controlSize(.large)
            }
            .padding(20)
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeExportBundle) { bundle in
            ShareSheetView(activityItems: bundle.fileURLs) {
                bundle.cleanup()
                activeExportBundle = nil
            }
        }
        .task(id: snapshot?.id) {
            await recognizeStructuredDocument()
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
            structuredDocument: structuredDocument
        )
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

    private var recoveredTextSource: String {
        ReviewTextSourceBuilder.makeSource(from: pagesForExport)
    }

    private func refreshDocumentIntelligenceAvailability() {
        documentIntelligenceAvailability = intelligenceAvailabilityProvider.currentAvailability()
    }

    private func prepareExport() {
        do {
            activeExportBundle = try exportService.makeExportBundle(
                from: pagesForExport,
                intelligenceNotes: intelligenceRunCoordinator.notes,
                includesIntelligenceNotes: includesIntelligenceNotesInExport
            )
            exportErrorMessage = nil
        } catch {
            exportErrorMessage = "Could not prepare the local export. Try rescanning the page."
        }
    }

    private func copyRecoveredText() {
        if recoveredTextCopyController.copyRecoveredText(from: pagesForExport) {
            copyConfirmationMessage = "Recovered text copied."
        } else {
            copyConfirmationMessage = "No recovered text is ready to copy yet."
        }
    }

    @MainActor
    private func recognizeStructuredDocument() async {
        guard let snapshot else {
            structuredDocument = nil
            structuredRecognitionMessage = nil
            return
        }

        structuredRecognitionMessage = "Analyzing document structure locally."

        do {
            structuredDocument = try await structuredRecognitionService.recognizeDocument(in: snapshot.image)
            structuredRecognitionMessage = nil
        } catch {
            structuredDocument = nil
            structuredRecognitionMessage = "Structured document analysis is unavailable for this scan."
        }
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

private struct StructuredDocumentPanel: View {
    let document: StructuredDocument?
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document structure")
                .font(.headline)

            if let document {
                if document.exportText.isEmpty {
                    Text("No structured paragraphs, tables, lists, or barcodes were detected.")
                        .foregroundStyle(.secondary)
                } else {
                    if !document.paragraphs.isEmpty {
                        Text("\(document.paragraphs.count) paragraph groups detected")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(Array(document.tables.enumerated()), id: \.offset) { index, table in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Table \(index + 1)")
                                .font(.subheadline.weight(.semibold))
                            Text(table.tsvText)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }

                    if !document.lists.isEmpty {
                        Text("\(document.lists.count) lists detected")
                            .foregroundStyle(.secondary)
                    }

                    if !document.barcodes.isEmpty {
                        Text("Barcodes: \(document.barcodes.joined(separator: ", "))")
                            .font(.caption)
                            .textSelection(.enabled)
                    }
                }
            } else {
                Text(message ?? "Document structure will appear after the page is analyzed.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PageSetPanel: View {
    let pageSet: ReviewPageSet
    let onRemoveCapturedPage: (ScannedPage.ID) -> Void

    @State private var pagePendingRemoval: ReviewPageSet.DisplayPage?
    @State private var isConfirmingPageRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Pages ready: \(pageSet.pagesForExport.count)")
                    .font(.headline)
                Text("Only the pages listed here will be included in the local PDF and text export.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if pageSet.displayPages.isEmpty {
                Text("No pages are ready for export yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pageSet.displayPages) { displayPage in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayPage.title)
                                .font(.subheadline.weight(.semibold))
                            Text(summary(for: displayPage))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if displayPage.canDelete {
                            Button(role: .destructive) {
                                pagePendingRemoval = displayPage
                                isConfirmingPageRemoval = true
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .frame(width: 44, height: 44)
                            .accessibilityLabel("Remove \(displayPage.title)")
                        } else {
                            Text("Included")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .confirmationDialog(
            "Remove page?",
            isPresented: $isConfirmingPageRemoval,
            titleVisibility: .visible
        ) {
            if let pagePendingRemoval {
                Button("Remove \(pagePendingRemoval.title)", role: .destructive) {
                    onRemoveCapturedPage(pagePendingRemoval.id)
                    self.pagePendingRemoval = nil
                }
            }
        } message: {
            if let pagePendingRemoval {
                Text("\(pagePendingRemoval.title) will be removed from this export set.")
            }
        }
    }

    private func summary(for displayPage: ReviewPageSet.DisplayPage) -> String {
        let visualQuality = Int(displayPage.visualQuality * 100)
        let lineLabel = displayPage.textLineCount == 1 ? "text line" : "text lines"
        return "\(visualQuality)% visual quality · \(displayPage.textLineCount) \(lineLabel)"
    }
}

private struct ConfidenceLegend: View {
    private let states: [ScanConfidenceState] = [
        .successful,
        .uncertain,
        .veryUncertain,
        .needsScan
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Confidence legend")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 10)], spacing: 10) {
                ForEach(states, id: \.self) { state in
                    let style = ConfidenceStateStyle.style(for: state)
                    HStack(spacing: 8) {
                        Image(systemName: style.symbolName)
                            .foregroundStyle(style.color)
                        Text(style.title)
                            .font(.subheadline.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(style.color.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel(style.title)
                }
            }
        }
    }
}

private struct RecognizedTextPanel: View {
    let blocks: [RecognizedTextBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovered text")
                .font(.headline)

            if blocks.isEmpty {
                Text("No text has enough evidence yet. Return to scanning and hold steady over missing regions.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    let style = ConfidenceStateStyle.style(
                        for: ScanConfidenceState.state(for: block.confidence)
                    )
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(block.confidence * 100))%")
                                .font(.caption.monospacedDigit())
                            Text(style.title)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(style.color)
                        .frame(width: 62, alignment: .trailing)

                        Text(block.text)
                            .font(.body)
                            .textSelection(.enabled)
                            .multilineTextAlignment(block.languageCode.contains("he") ? .trailing : .leading)
                            .frame(maxWidth: .infinity, alignment: block.languageCode.contains("he") ? .trailing : .leading)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }
}

