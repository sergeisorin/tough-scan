import Foundation
import UIKit

protocol ClipboardCopying {
    func copy(_ text: String)
}

struct PasteboardClipboard: ClipboardCopying {
    func copy(_ text: String) {
        UIPasteboard.general.string = text
    }
}

struct RecoveredTextCopyResult: Equatable {
    let didCopy: Bool
    let message: String
    let summary: ReviewTextSourceSummary
}

struct RecoveredTextCopyController {
    private let clipboard: ClipboardCopying

    init(clipboard: ClipboardCopying = PasteboardClipboard()) {
        self.clipboard = clipboard
    }

    @discardableResult
    func copyRecoveredText(from pages: [ScannedPage]) -> Bool {
        copyRecoveredTextResult(from: pages).didCopy
    }

    @discardableResult
    func copyRecoveredTextResult(from pages: [ScannedPage]) -> RecoveredTextCopyResult {
        let summary = ReviewTextSourceBuilder.makeSummary(from: pages)
        guard !summary.isEmpty else {
            return RecoveredTextCopyResult(
                didCopy: false,
                message: "No recovered text is ready to copy yet.",
                summary: summary
            )
        }

        clipboard.copy(summary.text)
        return RecoveredTextCopyResult(
            didCopy: true,
            message: "Copied \(summary.sourceDescription) from \(summary.copyablePageDescription).",
            summary: summary
        )
    }
}
