import Foundation

protocol SearchWorking {
    func search(term: String) async throws -> ITunesSearchResponse
}

final class SearchWorker: SearchWorking {
    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
    }

    func search(term: String) async throws -> ITunesSearchResponse {
        try await networkService.request(
            endpoint: .softwareSearch(term: term),
            responseType: ITunesSearchResponse.self
        )
    }
}
