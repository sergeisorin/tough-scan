import XCTest

final class DocumentIntelligenceNotesTests: XCTestCase {
    func testExportTextIncludesOnlyAvailableSections() {
        let notes = DocumentIntelligenceNotes(
            summary: "Three bullet summary",
            keyDetails: nil,
            cleanedTextSuggestion: "Cleaned text"
        )

        XCTAssertEqual(
            notes.exportText,
            """
            Summary
            Three bullet summary

            Cleaned text suggestion
            Cleaned text
            """
        )
    }

    func testUpdatingMergesNewActionWithoutDroppingExistingNotes() {
        let notes = DocumentIntelligenceNotes(summary: "Existing summary")
            .updating(.extractKeyDetails, result: "Names: Ari")

        XCTAssertEqual(notes.summary, "Existing summary")
        XCTAssertEqual(notes.keyDetails, "Names: Ari")
        XCTAssertNil(notes.cleanedTextSuggestion)
    }
}
