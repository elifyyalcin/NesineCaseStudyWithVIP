import Foundation
@testable import NesineCaseStudyWithVIP

actor NetworkServiceSpy: NetworkServiceProtocol {
    private let response: Any
    private(set) var receivedEndpoints: [Endpoint] = []

    init(response: Any) {
        self.response = response
    }

    func request<T: Decodable>(
        endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        receivedEndpoints.append(endpoint)

        guard let typedResponse = response as? T else {
            throw TestError.typeMismatch
        }
        return typedResponse
    }
}
