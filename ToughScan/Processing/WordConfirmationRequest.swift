import Foundation
import ToughScanCore

struct WordConfirmationRequest: Identifiable, Equatable {
    let id: String
    let word: RecognizedWord
    let state: ScanConfidenceState
    let label: String
    let contextText: String
    let uncertainText: String
    let suggestedText: String
    let note: String
}

enum WordConfirmationRequestBuilder {
    static func makeRequests(from words: [RecognizedWord]) -> [WordConfirmationRequest] {
        words
            .filter { $0.state != .successful }
            .sorted(by: sortWeakestFirst)
            .map { word in
                let text = word.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let confidence = Int((word.confidence * 100).rounded())

                return WordConfirmationRequest(
                    id: requestID(for: word),
                    word: word,
                    state: word.state,
                    label: "\(title(for: word.state)) word",
                    contextText: word.lineText ?? text,
                    uncertainText: text,
                    suggestedText: text,
                    note: "\(confidence)% model confidence. Confirm the text or rescan this word."
                )
            }
    }

    private static func title(for state: ScanConfidenceState) -> String {
        switch state {
        case .successful:
            return "Successful"
        case .uncertain:
            return "Review"
        case .veryUncertain:
            return "Rescan"
        case .needsScan:
            return "Needed"
        }
    }

    private static func sortWeakestFirst(_ lhs: RecognizedWord, _ rhs: RecognizedWord) -> Bool {
        if lhs.state != rhs.state {
            return lhs.state < rhs.state
        }

        if lhs.confidence != rhs.confidence {
            return lhs.confidence < rhs.confidence
        }

        return lhs.text < rhs.text
    }

    static func requestID(for word: RecognizedWord) -> String {
        let centerX = word.boundingBox.x + (word.boundingBox.width / 2)
        let centerY = word.boundingBox.y + (word.boundingBox.height / 2)

        return [
            word.languageCode,
            word.tileCoordinates.map { "\($0.column):\($0.row)" }.joined(separator: ","),
            String(format: "%.2f", centerX),
            String(format: "%.2f", centerY)
        ].joined(separator: "|")
    }
}
