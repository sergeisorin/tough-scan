import XCTest

final class DocumentIntelligenceRunCoordinatorTests: XCTestCase {
    func testBeginCreatesRequestAndRunningState() throws {
        var coordinator = DocumentIntelligenceRunCoordinator()

        let request = try XCTUnwrap(coordinator.begin(
            action: .summarize,
            sourceText: "Page 1\nInvoice",
            availability: .available
        ))

        XCTAssertEqual(request.action, .summarize)
        XCTAssertEqual(request.sourceText, "Page 1\nInvoice")
        XCTAssertEqual(coordinator.state, .running(.summarize))
    }

    func testCompleteStoresResultForMatchingSource() throws {
        var coordinator = DocumentIntelligenceRunCoordinator()
        let request = try XCTUnwrap(coordinator.begin(
            action: .summarize,
            sourceText: "Page 1\nInvoice",
            availability: .available
        ))

        coordinator.complete(request, result: "Three bullets")

        XCTAssertEqual(coordinator.notes.summary, "Three bullets")
        XCTAssertEqual(coordinator.state, .succeeded(.summarize))
    }

    func testSourceChangeClearsNotesAndPreventsStaleCompletion() throws {
        var coordinator = DocumentIntelligenceRunCoordinator()
        let summaryRequest = try XCTUnwrap(coordinator.begin(
            action: .summarize,
            sourceText: "Page 1\nOld",
            availability: .available
        ))
        coordinator.complete(summaryRequest, result: "Existing summary")

        let request = try XCTUnwrap(coordinator.begin(
            action: .extractKeyDetails,
            sourceText: "Page 1\nOld",
            availability: .available
        ))
        coordinator.sourceDidChange(to: "Page 1\nNew")
        coordinator.complete(request, result: "Names: Ari")

        XCTAssertTrue(coordinator.notes.isEmpty)
        XCTAssertEqual(coordinator.state, .staleSource(.extractKeyDetails))
    }

    func testEmptySourceAndUnavailableAvailabilityDoNotCreateRequests() {
        var coordinator = DocumentIntelligenceRunCoordinator()

        XCTAssertNil(coordinator.begin(action: .summarize, sourceText: " \n ", availability: .available))
        XCTAssertEqual(coordinator.state, .emptySource(.summarize))

        XCTAssertNil(coordinator.begin(action: .summarize, sourceText: "Text", availability: .modelNotReady))
        XCTAssertEqual(coordinator.state, .unavailable(.modelNotReady))
    }

    func testFailureAllowsRetryForSameAction() throws {
        var coordinator = DocumentIntelligenceRunCoordinator()
        let request = try XCTUnwrap(coordinator.begin(
            action: .suggestCleanedText,
            sourceText: "Page 1\nRaw",
            availability: .available
        ))

        coordinator.fail(request, failure: .generic)

        XCTAssertEqual(coordinator.state, .failed(.suggestCleanedText, .generic))
        XCTAssertNotNil(coordinator.begin(
            action: .suggestCleanedText,
            sourceText: "Page 1\nRaw",
            availability: .available
        ))
        XCTAssertEqual(coordinator.state, .running(.suggestCleanedText))
    }

    func testOlderCompletionForSameSourceDoesNotReplaceNewerRun() throws {
        var coordinator = DocumentIntelligenceRunCoordinator()
        let olderRequest = try XCTUnwrap(coordinator.begin(
            action: .summarize,
            sourceText: "Page 1\nSame",
            availability: .available
        ))
        let newerRequest = try XCTUnwrap(coordinator.begin(
            action: .extractKeyDetails,
            sourceText: "Page 1\nSame",
            availability: .available
        ))

        coordinator.complete(olderRequest, result: "Older summary")

        XCTAssertTrue(coordinator.notes.isEmpty)
        XCTAssertEqual(coordinator.state, .running(.extractKeyDetails))

        coordinator.complete(newerRequest, result: "Names: Ari")
        XCTAssertEqual(coordinator.notes.keyDetails, "Names: Ari")
        XCTAssertEqual(coordinator.state, .succeeded(.extractKeyDetails))
    }

    func testOlderCompletionForStaleSourceDoesNotReplaceNewerRun() throws {
        var coordinator = DocumentIntelligenceRunCoordinator()
        let olderRequest = try XCTUnwrap(coordinator.begin(
            action: .summarize,
            sourceText: "Page 1\nOld",
            availability: .available
        ))
        coordinator.sourceDidChange(to: "Page 1\nNew")
        let newerRequest = try XCTUnwrap(coordinator.begin(
            action: .extractKeyDetails,
            sourceText: "Page 1\nNew",
            availability: .available
        ))

        coordinator.complete(olderRequest, result: "Older summary")

        XCTAssertTrue(coordinator.notes.isEmpty)
        XCTAssertEqual(coordinator.state, .running(.extractKeyDetails))

        coordinator.complete(newerRequest, result: "Names: Ari")
        XCTAssertEqual(coordinator.notes.keyDetails, "Names: Ari")
        XCTAssertEqual(coordinator.state, .succeeded(.extractKeyDetails))
    }

    func testRunStateProvidesPerActionStatusAndRetryTitle() {
        let failedState = DocumentIntelligenceRunState.failed(.summarize, .rateLimited)

        XCTAssertEqual(
            failedState.statusMessage(for: .summarize),
            "Apple Intelligence is busy. Try again in a moment."
        )
        XCTAssertNil(failedState.statusMessage(for: .extractKeyDetails))
        XCTAssertEqual(failedState.buttonTitle(for: .summarize), "Retry summarize")
        XCTAssertEqual(failedState.buttonTitle(for: .extractKeyDetails), "Extract key details")

        let runningState = DocumentIntelligenceRunState.running(.extractKeyDetails)
        XCTAssertEqual(
            runningState.statusMessage(for: .extractKeyDetails),
            "Running extract key details locally."
        )
        XCTAssertNil(runningState.statusMessage(for: .summarize))
    }
}
