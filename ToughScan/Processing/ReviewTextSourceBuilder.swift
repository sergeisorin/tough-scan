import Foundation

struct ReviewTextSourceSummary: Equatable {
    let text: String
    let copyablePageCount: Int
    let usesStructuredText: Bool
    let usesOCRText: Bool

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var sourceDescription: String {
        switch (usesStructuredText, usesOCRText) {
        case (true, true):
            return "structured and OCR text"
        case (true, false):
            return "structured text"
        case (false, true):
            return "OCR text"
        case (false, false):
            return "no copyable text"
        }
    }

    var copyablePageDescription: String {
        copyablePageCount == 1 ? "1 page" : "\(copyablePageCount) pages"
    }
}

enum ReviewTextSourceBuilder {
    static func makeSource(from pages: [ScannedPage]) -> String {
        makeSummary(from: pages).text
    }

    static func makeSummary(from pages: [ScannedPage]) -> ReviewTextSourceSummary {
        var usesStructuredText = false
        var usesOCRText = false

        let pageTexts = pages.enumerated()
            .compactMap { index, page -> String? in
                guard let body = textBody(for: page) else {
                    return nil
                }

                usesStructuredText = usesStructuredText || body.usesStructuredText
                usesOCRText = usesOCRText || body.usesOCRText

                return "Page \(index + 1)\n\(body.text)"
            }

        return ReviewTextSourceSummary(
            text: pageTexts.joined(separator: "\n\n"),
            copyablePageCount: pageTexts.count,
            usesStructuredText: usesStructuredText,
            usesOCRText: usesOCRText
        )
    }

    private static func textBody(for page: ScannedPage) -> TextBody? {
        if let structuredText = page.structuredDocument?.exportText,
           !structuredText.isEmpty {
            return TextBody(text: structuredText, usesStructuredText: true, usesOCRText: false)
        }

        let ocrText = page.recognizedTextBlocks
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        guard !ocrText.isEmpty else {
            return nil
        }

        return TextBody(text: ocrText, usesStructuredText: false, usesOCRText: true)
    }
}

private struct TextBody {
    let text: String
    let usesStructuredText: Bool
    let usesOCRText: Bool
}
