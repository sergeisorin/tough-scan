import Foundation

struct DocumentIntelligenceNotes: Equatable {
    var summary: String?
    var keyDetails: String?
    var cleanedTextSuggestion: String?

    var isEmpty: Bool {
        summary == nil && keyDetails == nil && cleanedTextSuggestion == nil
    }

    var exportText: String {
        [
            section(title: DocumentIntelligenceAction.summarize.title, text: summary),
            section(title: DocumentIntelligenceAction.extractKeyDetails.title, text: keyDetails),
            section(title: DocumentIntelligenceAction.suggestCleanedText.title, text: cleanedTextSuggestion)
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")
    }

    func updating(_ action: DocumentIntelligenceAction, result: String) -> DocumentIntelligenceNotes {
        var copy = self

        switch action {
        case .summarize:
            copy.summary = result
        case .extractKeyDetails:
            copy.keyDetails = result
        case .suggestCleanedText:
            copy.cleanedTextSuggestion = result
        }

        return copy
    }

    private func section(title: String, text: String?) -> String? {
        guard let text else {
            return nil
        }

        return "\(title)\n\(text)"
    }
}
