import XCTest
@testable import NesineCaseStudyWithVIP

@MainActor
final class SearchInteractorTests: XCTestCase {
    func test_search_whenWorkerSucceeds_shouldPresentScreenshots() async {
        let response = makeResponse(urlGroups: [["one", "two"]])
        let presenter = SearchPresentationSpy()
        let interactor = SearchInteractor(
            worker: SearchWorkerStub(result: .success(response)),
            presenter: presenter
        )

        await interactor.load(request: Search.Load.Request(term: "game"))

        XCTAssertEqual(presenter.responses.count, 2)
        guard case .success(let screenshots) = presenter.responses.last?.state else {
            return XCTFail("Expected a success response")
        }
        XCTAssertEqual(screenshots.count, 2)
    }

    func test_search_whenWorkerReturnsNoResults_shouldPresentEmptyScreenshots() async {
        let presenter = SearchPresentationSpy()
        let interactor = SearchInteractor(
            worker: SearchWorkerStub(
                result: .success(ITunesSearchResponse(resultCount: 0, results: []))
            ),
            presenter: presenter
        )

        await interactor.load(request: Search.Load.Request(term: "missing"))

        guard case .success(let screenshots) = presenter.responses.last?.state else {
            return XCTFail("Expected a success response")
        }
        XCTAssertTrue(screenshots.isEmpty)
    }

    func test_search_whenWorkerFails_shouldPresentError() async {
        let presenter = SearchPresentationSpy()
        let interactor = SearchInteractor(
            worker: SearchWorkerStub(result: .failure(TestError.expected)),
            presenter: presenter
        )

        await interactor.load(request: Search.Load.Request(term: "game"))

        guard case .failure = presenter.responses.last?.state else {
            return XCTFail("Expected a failure response")
        }
    }

    func test_search_shouldFlattenAllScreenshotURLsFromAllResults() async {
        let presenter = SearchPresentationSpy()
        let interactor = SearchInteractor(
            worker: SearchWorkerStub(
                result: .success(makeResponse(urlGroups: [["one", "two"], ["three", "four"]]))
            ),
            presenter: presenter
        )

        await interactor.load(request: Search.Load.Request(term: "game"))

        guard case .success(let screenshots) = presenter.responses.last?.state else {
            return XCTFail("Expected a success response")
        }
        XCTAssertEqual(
            screenshots.map(\.imageURL.absoluteString),
            [
                "https://example.com/one.png",
                "https://example.com/two.png",
                "https://example.com/three.png",
                "https://example.com/four.png"
            ]
        )
    }

    func test_search_whenOlderRequestFinishesLast_shouldNotPresentStaleResult() async {
        let worker = ControllableSearchWorker()
        let presenter = SearchPresentationSpy()
        let interactor = SearchInteractor(worker: worker, presenter: presenter)

        let olderTask = Task {
            await interactor.load(request: Search.Load.Request(term: "old"))
        }
        await worker.waitUntilRequested("old")

        let newerTask = Task {
            await interactor.load(request: Search.Load.Request(term: "new"))
        }
        await worker.waitUntilRequested("new")

        await worker.complete(term: "new", with: makeResponse(urlGroups: [["new"]]))
        await newerTask.value
        await worker.complete(term: "old", with: makeResponse(urlGroups: [["old"]]))
        await olderTask.value

        let presentedURLs = presenter.responses.compactMap { response -> URL? in
            guard case .success(let screenshots) = response.state else { return nil }
            return screenshots.first?.imageURL
        }
        XCTAssertEqual(presentedURLs.map(\.absoluteString), ["https://example.com/new.png"])
    }
}

private extension SearchInteractorTests {
    func makeResponse(urlGroups: [[String]]) -> ITunesSearchResponse {
        let results = urlGroups.enumerated().map { index, names in
            SoftwareResult(
                trackName: "App \(index)",
                screenshotUrls: names.compactMap {
                    URL(string: "https://example.com/\($0).png")
                }
            )
        }
        return ITunesSearchResponse(resultCount: results.count, results: results)
    }
}
