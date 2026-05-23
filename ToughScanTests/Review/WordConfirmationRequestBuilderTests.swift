import ToughScanCore
import XCTest

final class WordConfirmationRequestBuilderTests: XCTestCase {
    func testBuildsRequestsForReviewAndRescanWordsOnly() {
        let words = [
            makeWord("clear", confidence: 0.91),
            makeWord("maybe", confidence: 0.62),
            makeWord("weak", confidence: 0.34)
        ]

        let requests = WordConfirmationRequestBuilder.makeRequests(from: words)

        XCTAssertEqual(requests.map(\.uncertainText), ["weak", "maybe"])
        XCTAssertEqual(requests.map(\.state), [.veryUncertain, .uncertain])
        XCTAssertEqual(requests.first?.suggestedText, "weak")
        XCTAssertTrue(requests.first?.note.contains("34%") == true)
    }

    private func makeWord(_ text: String, confidence: Double) -> RecognizedWord {
        RecognizedWord(
            text: text,
            confidence: confidence,
            languageCode: "en",
            tileCoordinates: [TileCoordinate(column: 0, row: 0)],
            boundingBox: NormalizedRect(x: 0.1, y: 0.7, width: 0.1, height: 0.05),
            lineText: "Business #: \(text)",
            lineBoundingBox: NormalizedRect(x: 0.1, y: 0.7, width: 0.4, height: 0.05)
        )
    }
}
