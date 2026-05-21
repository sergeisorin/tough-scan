import SwiftUI
import ToughScanCore

struct ScanReviewView: View {
    let session: ProgressiveScanSession
    let snapshot: DocumentSnapshot?
    let capturedPages: [ScannedPage]
    let onAddPage: () -> Void
    let onRescan: () -> Void

    @State private var activeExportBundle: ScanExportBundle?
    @State private var exportErrorMessage: String?

    private let exportService = ScanExportService()

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

                RecognizedTextPanel(blocks: session.recognizedTextBlocks)

                ExportSummaryPanel(pageCount: pagesForExport.count)

                if let exportErrorMessage {
                    Text(exportErrorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack(spacing: 12) {
                    Button("Rescan weak areas", action: onRescan)
                        .buttonStyle(.bordered)

                    Button("Add another page", action: onAddPage)
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
    }

    private var currentPage: ScannedPage? {
        guard let snapshot else {
            return nil
        }

        return ScannedPage(
            snapshot: snapshot,
            recognizedTextBlocks: session.recognizedTextBlocks
        )
    }

    private var pagesForExport: [ScannedPage] {
        capturedPages + (currentPage.map { [$0] } ?? [])
    }

    private func prepareExport() {
        do {
            activeExportBundle = try exportService.makeExportBundle(from: pagesForExport)
            exportErrorMessage = nil
        } catch {
            exportErrorMessage = "Could not prepare the local export. Try rescanning the page."
        }
    }
}

private struct ExportSummaryPanel: View {
    let pageCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pages ready: \(pageCount)")
                .font(.headline)
            Text("A single PDF and recovered text file will be prepared on this iPhone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

