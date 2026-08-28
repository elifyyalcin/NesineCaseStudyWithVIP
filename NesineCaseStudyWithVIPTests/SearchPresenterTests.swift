import XCTest
@testable import NesineCaseStudyWithVIP

@MainActor
final class SearchPresenterTests: XCTestCase {
    func test_presentSuccess_shouldMapScreenshotsToContentViewModel() throws {
        let display = SearchDisplaySpy()
        let presenter = SearchPresenter()
        presenter.viewController = display
        let url = try XCTUnwrap(URL(string: "https://example.com/image.png"))
        let screenshots = [
            Search.Screenshot(imageURL: url, appName: "Example App")
        ]

        presenter.present(response: Search.Load.Response(state: .success(screenshots)))

        guard case .content(let items) = display.viewModels.last?.state else {
            return XCTFail("Expected content state")
        }
        XCTAssertEqual(items.first?.imageURL, url)
        XCTAssertEqual(items.first?.appName, "Example App")
    }

    func test_presentEmptySuccess_shouldMapToEmptyState() {
        let display = SearchDisplaySpy()
        let presenter = SearchPresenter()
        presenter.viewController = display

        presenter.present(response: Search.Load.Response(state: .success([])))

        guard case .empty(let message) = display.viewModels.last?.state else {
            return XCTFail("Expected empty state")
        }
        XCTAssertEqual(message, "No results found.")
    }

    func test_presentFailure_shouldMapToUserFriendlyError() {
        let display = SearchDisplaySpy()
        let presenter = SearchPresenter()
        presenter.viewController = display

        presenter.present(response: Search.Load.Response(state: .failure))

        guard case .error(let message) = display.viewModels.last?.state else {
            return XCTFail("Expected error state")
        }
        XCTAssertEqual(message, "Something went wrong. Please try again.")
        XCTAssertFalse(message.contains("Error Domain"))
    }
}
