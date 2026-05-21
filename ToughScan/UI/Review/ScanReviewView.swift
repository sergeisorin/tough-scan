import SwiftUI
import ToughScanCore

struct ScanReviewView: View {
    let session: ProgressiveScanSession
    let snapshot: DocumentSnapshot?
    let capturedPages: [ScannedPage]
    let onAddPage: (StructuredDocument?) -> Void
    let onRemoveCapturedPage: (ScannedPage.ID) -> Void
    let onRescan: () -> Void

    @State private var activeExportBundle: ScanExportBundle?
    @State private var exportErrorMessage: String?
    @State private var structuredDocument: StructuredDocument?
    @State private var structuredRecognitionMessage: String?

    private let exportService = ScanExportService()
    private let structuredRecognitionService = StructuredDocumentRecognitionService()

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
                    showsOverlay: true
                )
                .frame(height: 420)

                ConfidenceLegend()

                if let snapshot {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Selectable image text")
                            .font(.headline)
                        Text("Use Live Text here to select, copy, translate, or open detected data from the reconstructed page.")
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

                PageSetPanel(
                    pageSet: pageSet,
                    onRemoveCapturedPage: onRemoveCapturedPage
                )

                if let exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button("Rescan weak areas", action: onRescan)
                        .buttonStyle(.bordered)

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
    }

    private var currentPage: ScannedPage? {
        guard let snapshot else {
            return nil
        }

        return ScannedPage(
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

    private func prepareExport() {
        do {
            activeExportBundle = try exportService.makeExportBundle(from: pagesForExport)
            exportErrorMessage = nil
        } catch {
            exportErrorMessage = "Could not prepare the local export. Try rescanning the page."
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
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(Int(block.confidence * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)

                        Text(block.text)
                            .font(.body)
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

