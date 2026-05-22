import Foundation

enum ReviewTextSourceBuilder {
    static func makeSource(from pages: [ScannedPage]) -> String {
        pages.enumerated()
            .compactMap { index, page in
                let body = textBody(for: page)
                guard !body.isEmpty else {
                    return nil
                }

                return "Page \(index + 1)\n\(body)"
            }
            .joined(separator: "\n\n")
    }

    private static func textBody(for page: ScannedPage) -> String {
        if let structuredText = page.structuredDocument?.exportText,
           !structuredText.isEmpty {
            return structuredText
        }

        return page.recognizedTextBlocks
            .map(\.text)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
    }
}
