import SwiftUI

struct IntelligenceReviewPanel: View {
    let availability: DocumentIntelligenceAvailability
    let sourceText: String
    let notes: DocumentIntelligenceNotes
    let runState: DocumentIntelligenceRunState
    let onRunAction: (DocumentIntelligenceAction) -> Void

    private var canRunActions: Bool {
        availability.canGenerate && !sourceText.isEmpty && !isRunning
    }

    private var isRunning: Bool {
        if case .running = runState {
            return true
        }

        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI-assisted review")
                    .font(.headline)
                Text("Use Apple Intelligence on supported devices to summarize, extract, or clean recovered text. Notes are local and advisory.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !availability.canGenerate {
                availabilityMessage
            } else if sourceText.isEmpty {
                Text("AI-assisted review needs recovered text first. Rescan weak areas or add a page, then copy and export remain available when text is recovered.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                actionList
            }

            if notes.isEmpty && canRunActions {
                Text("Run an action to generate notes for this review.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if !notes.isEmpty {
                generatedNotes
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var availabilityMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(availability.title)
                .font(.subheadline.weight(.semibold))
            Text(availability.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var actionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(DocumentIntelligenceAction.allCases, id: \.self) { action in
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        onRunAction(action)
                    } label: {
                        if case .running(let runningAction) = runState,
                           runningAction == action {
                            ProgressView()
                        } else {
                            Text(runState.buttonTitle(for: action))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canRunActions)

                    if let statusMessage = runState.statusMessage(for: action) {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var generatedNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = notes.summary {
                GeneratedNoteSection(title: DocumentIntelligenceAction.summarize.title, text: summary)
            }

            if let keyDetails = notes.keyDetails {
                GeneratedNoteSection(title: DocumentIntelligenceAction.extractKeyDetails.title, text: keyDetails)
            }

            if let cleanedTextSuggestion = notes.cleanedTextSuggestion {
                GeneratedNoteSection(title: DocumentIntelligenceAction.suggestCleanedText.title, text: cleanedTextSuggestion)
            }
        }
    }
}

private struct GeneratedNoteSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
