import Foundation
import FoundationModels

enum DocumentIntelligenceAction: CaseIterable, Equatable {
    case summarize
    case extractKeyDetails
    case suggestCleanedText

    var title: String {
        switch self {
        case .summarize:
            return "Summary"
        case .extractKeyDetails:
            return "Key details"
        case .suggestCleanedText:
            return "Cleaned text suggestion"
        }
    }

    var buttonTitle: String {
        switch self {
        case .summarize:
            return "Summarize"
        case .extractKeyDetails:
            return "Extract key details"
        case .suggestCleanedText:
            return "Suggest cleaned text"
        }
    }

    var instructions: String {
        switch self {
        case .summarize:
            return """
            Summarize the scanned document in exactly three concise bullets.
            Do not infer facts that are not present in the text.
            Keep generated text advisory and avoid adding personal data that is not visible in the source.
            """
        case .extractKeyDetails:
            return """
            Extract names, dates, phone numbers, emails, addresses, amounts, and document type from the scanned document.
            Use a compact labeled list. Write "Not found" for a category if it is not visible.
            Do not guess missing values.
            """
        case .suggestCleanedText:
            return """
            Suggest cleaned OCR text while preserving the original meaning and line breaks where useful.
            Preserve uncertain words in brackets.
            Do not add information that is not present in the source text.
            """
        }
    }
}

protocol DocumentIntelligenceGenerating {
    func generate(instructions: String, prompt: String) async throws -> String
}

final class DocumentIntelligenceService {
    enum Error: Swift.Error, Equatable {
        case emptySource
        case generationFailed(DocumentIntelligenceFailure)
    }

    private let generator: DocumentIntelligenceGenerating
    private let maxSourceCharacters: Int

    init(
        generator: DocumentIntelligenceGenerating = FoundationModelsDocumentIntelligenceGenerator(),
        maxSourceCharacters: Int = 12_000
    ) {
        self.generator = generator
        self.maxSourceCharacters = maxSourceCharacters
    }

    func perform(_ action: DocumentIntelligenceAction, sourceText: String) async throws -> String {
        let trimmedSource = sourceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            throw Error.emptySource
        }

        let prompt = """
        Analyze the following scanned document text.
        \(limitedSource(trimmedSource))
        """

        do {
            return try await generator
                .generate(instructions: action.instructions, prompt: prompt)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw Error.generationFailed(Self.failure(from: error))
        }
    }

    private func limitedSource(_ source: String) -> String {
        guard source.count > maxSourceCharacters else {
            return source
        }

        let limitIndex = source.index(source.startIndex, offsetBy: maxSourceCharacters)
        return """
        [Document text was shortened to fit the local model context.]
        \(source[..<limitIndex])
        """
    }

    private static func failure(from error: Swift.Error) -> DocumentIntelligenceFailure {
        guard let generationError = error as? LanguageModelSession.GenerationError else {
            return .generic
        }

        switch generationError {
        case .exceededContextWindowSize:
            return .contextTooLong
        case .assetsUnavailable:
            return .modelAssetsUnavailable
        case .unsupportedLanguageOrLocale:
            return .unsupportedLocale
        case .rateLimited:
            return .rateLimited
        case .guardrailViolation, .refusal:
            return .guardrail
        case .unsupportedGuide, .decodingFailure, .concurrentRequests:
            return .generic
        @unknown default:
            return .generic
        }
    }
}

private struct FoundationModelsDocumentIntelligenceGenerator: DocumentIntelligenceGenerating {
    func generate(instructions: String, prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(sampling: .greedy, temperature: 0.2, maximumResponseTokens: 600)
        )
        return response.content
    }
}
