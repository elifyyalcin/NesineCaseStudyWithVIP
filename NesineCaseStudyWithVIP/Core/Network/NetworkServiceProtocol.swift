import Foundation

protocol NetworkServiceProtocol {
    func request<T: Decodable>(
        endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T
}
