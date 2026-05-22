import Foundation

struct DocumentIntelligenceRunRequest: Equatable {
    let action: DocumentIntelligenceAction
    let sourceText: String
    let sourceID: String
    let runID: UUID

    init(
        action: DocumentIntelligenceAction,
        sourceText: String,
        sourceID: String,
        runID: UUID = UUID()
    ) {
        self.action = action
        self.sourceText = sourceText
        self.sourceID = sourceID
        self.runID = runID
    }
}

enum DocumentIntelligenceFailure: Equatable {
    case contextTooLong
    case modelAssetsUnavailable
    case unsupportedLocale
    case rateLimited
    case guardrail
    case generic

    var message: String {
        switch self {
        case .contextTooLong:
            return "This document is too long for one Apple Intelligence pass."
        case .modelAssetsUnavailable:
            return "Apple Intelligence is still preparing. Try again later."
        case .unsupportedLocale:
            return "Apple Intelligence is not available for this language or locale."
        case .rateLimited:
            return "Apple Intelligence is busy. Try again in a moment."
        case .guardrail:
            return "Apple Intelligence could not provide a suggestion for this document."
        case .generic:
            return "Apple Intelligence could not finish this action. Try again later."
        }
    }
}

enum DocumentIntelligenceRunState: Equatable {
    case idle
    case running(DocumentIntelligenceAction)
    case succeeded(DocumentIntelligenceAction)
    case emptySource(DocumentIntelligenceAction)
    case staleSource(DocumentIntelligenceAction)
    case unavailable(DocumentIntelligenceAvailability)
    case failed(DocumentIntelligenceAction, DocumentIntelligenceFailure)

    func statusMessage(for action: DocumentIntelligenceAction) -> String? {
        switch self {
        case .running(let runningAction) where runningAction == action:
            return "Running \(action.buttonTitle.lowercased()) locally."
        case .succeeded(let succeededAction) where succeededAction == action:
            return "Suggestion updated."
        case .failed(let failedAction, let failure) where failedAction == action:
            return failure.message
        case .emptySource(let emptyAction) where emptyAction == action:
            return "AI-assisted review needs recovered text first. Rescan weak areas or add a page before running this action."
        case .staleSource(let staleAction) where staleAction == action:
            return "Document text changed. Run the action again for the latest page set."
        case .idle, .unavailable, .running, .succeeded, .failed, .emptySource, .staleSource:
            return nil
        }
    }

    func buttonTitle(for action: DocumentIntelligenceAction) -> String {
        if case .failed(let failedAction, _) = self,
           failedAction == action {
            return "Retry \(action.buttonTitle.lowercased())"
        }

        return action.buttonTitle
    }
}

struct DocumentIntelligenceRunCoordinator {
    private(set) var notes = DocumentIntelligenceNotes()
    private(set) var state: DocumentIntelligenceRunState = .idle
    private var sourceID: String?
    private var runID: UUID?

    mutating func begin(
        action: DocumentIntelligenceAction,
        sourceText: String,
        availability: DocumentIntelligenceAvailability
    ) -> DocumentIntelligenceRunRequest? {
        guard availability.canGenerate else {
            state = .unavailable(availability)
            return nil
        }

        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            state = .emptySource(action)
            return nil
        }

        let request = DocumentIntelligenceRunRequest(
            action: action,
            sourceText: trimmedSource,
            sourceID: trimmedSource
        )
        sourceID = request.sourceID
        runID = request.runID
        state = .running(action)
        return request
    }

    mutating func complete(_ request: DocumentIntelligenceRunRequest, result: String) {
        if let runID,
           runID != request.runID {
            return
        }

        guard sourceID == request.sourceID else {
            state = .staleSource(request.action)
            return
        }

        notes = notes.updating(request.action, result: result)
        state = .succeeded(request.action)
        sourceID = nil
        runID = nil
    }

    mutating func fail(_ request: DocumentIntelligenceRunRequest, failure: DocumentIntelligenceFailure) {
        if let runID,
           runID != request.runID {
            return
        }

        guard sourceID == request.sourceID else {
            state = .staleSource(request.action)
            return
        }

        state = .failed(request.action, failure)
        sourceID = nil
        runID = nil
    }

    mutating func sourceDidChange(to newSourceText: String) {
        let newSourceID = newSourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard newSourceID != sourceID else {
            return
        }

        notes = DocumentIntelligenceNotes()
        sourceID = newSourceID.isEmpty ? nil : newSourceID
        runID = nil
        state = .idle
    }
}
