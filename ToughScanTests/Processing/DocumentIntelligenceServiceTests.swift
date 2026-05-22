import XCTest

final class DocumentIntelligenceServiceTests: XCTestCase {
    func testSummaryActionRequestsThreeBulletsForSourceText() async throws {
        let generator = RecordingIntelligenceGenerator(response: "• Summary")
        let service = DocumentIntelligenceService(generator: generator)

        let result = try await service.perform(.summarize, sourceText: "Invoice total 42")
        let request = await generator.lastRequest

        XCTAssertEqual(result, "• Summary")
        XCTAssertTrue(request?.instructions.contains("three concise bullets") == true)
        XCTAssertTrue(request?.prompt.contains("Invoice total 42") == true)
    }

    func testKeyDetailsActionRequestsSpecificDocumentFields() async throws {
        let generator = RecordingIntelligenceGenerator(response: "Names: Ari")
        let service = DocumentIntelligenceService(generator: generator)

        _ = try await service.perform(.extractKeyDetails, sourceText: "Ari paid 42 on May 22")
        let request = await generator.lastRequest

        XCTAssertTrue(request?.instructions.contains("names, dates, phone numbers, emails, addresses, amounts, and document type") == true)
    }

    func testCleanedTextActionPreservesUncertainWordsInBrackets() async throws {
        let generator = RecordingIntelligenceGenerator(response: "Clean text")
        let service = DocumentIntelligenceService(generator: generator)

        _ = try await service.perform(.suggestCleanedText, sourceText: "raw scann")
        let request = await generator.lastRequest

        XCTAssertTrue(request?.instructions.contains("Preserve uncertain words in brackets") == true)
        XCTAssertTrue(request?.prompt.contains("raw scann") == true)
    }

    func testRejectsEmptySourceText() async {
        let generator = RecordingIntelligenceGenerator(response: "Unused")
        let service = DocumentIntelligenceService(generator: generator)

        do {
            _ = try await service.perform(.summarize, sourceText: "   \n")
            XCTFail("Expected empty source error")
        } catch DocumentIntelligenceService.Error.emptySource {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLimitsVeryLongSourceBeforeSendingToModel() async throws {
        let generator = RecordingIntelligenceGenerator(response: "Limited")
        let service = DocumentIntelligenceService(generator: generator, maxSourceCharacters: 24)

        _ = try await service.perform(.summarize, sourceText: String(repeating: "A", count: 80))
        let request = await generator.lastRequest

        XCTAssertTrue(request?.prompt.contains("[Document text was shortened to fit the local model context.]") == true)
        XCTAssertFalse(request?.prompt.contains(String(repeating: "A", count: 80)) == true)
    }
}

private actor RecordingIntelligenceGenerator: DocumentIntelligenceGenerating {
    private(set) var lastRequest: (instructions: String, prompt: String)?
    private let response: String

    init(response: String) {
        self.response = response
    }

    func generate(instructions: String, prompt: String) async throws -> String {
        lastRequest = (instructions, prompt)
        return response
    }
}
