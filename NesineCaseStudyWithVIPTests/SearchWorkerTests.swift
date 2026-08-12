import XCTest
@testable import NesineCaseStudyWithVIP

final class SearchWorkerTests: XCTestCase {
    func test_search_shouldUseSoftwareEndpointWithProvidedTerm() async throws {
        let expectedResponse = ITunesSearchResponse(resultCount: 0, results: [])
        let networkService = NetworkServiceSpy(response: expectedResponse)
        let worker = SearchWorker(networkService: networkService)

        _ = try await worker.search(term: "photo editor")

        let endpoints = await networkService.receivedEndpoints
        let endpoint = try XCTUnwrap(endpoints.first)
        XCTAssertEqual(endpoint.path, "/search")
        XCTAssertEqual(endpoint.method, .get)

        let query = Dictionary(
            uniqueKeysWithValues: endpoint.queryItems.compactMap { item in
                item.value.map { (item.name, $0) }
            }
        )
        XCTAssertEqual(query["term"], "photo editor")
        XCTAssertEqual(query["media"], "software")
    }
}
