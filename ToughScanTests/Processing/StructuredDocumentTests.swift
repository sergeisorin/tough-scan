import XCTest

final class StructuredDocumentTests: XCTestCase {
    func testExportTextCombinesParagraphsListsTablesAndBarcodes() {
        let document = StructuredDocument(
            paragraphs: ["First paragraph", "Second paragraph"],
            tables: [StructuredTable(rows: [["Name", "Amount"], ["Ari", "42"]])],
            lists: [StructuredList(items: ["First item", "Second item"])],
            barcodes: ["abc-123"]
        )

        XCTAssertEqual(
            document.exportText,
            """
            First paragraph
            Second paragraph

            - First item
            - Second item

            Name\tAmount
            Ari\t42

            Barcodes
            abc-123
            """
        )
    }

    func testExportTextOmitsEmptySections() {
        let document = StructuredDocument(
            paragraphs: ["   "],
            tables: [StructuredTable(rows: [])],
            lists: [StructuredList(items: [])],
            barcodes: []
        )

        XCTAssertEqual(document.exportText, "")
    }
}
