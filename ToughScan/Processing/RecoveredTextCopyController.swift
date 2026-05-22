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

struct RecoveredTextCopyController {
    private let clipboard: ClipboardCopying

    init(clipboard: ClipboardCopying = PasteboardClipboard()) {
        self.clipboard = clipboard
    }

    @discardableResult
    func copyRecoveredText(from pages: [ScannedPage]) -> Bool {
        let source = ReviewTextSourceBuilder.makeSource(from: pages)
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        clipboard.copy(source)
        return true
    }
}
