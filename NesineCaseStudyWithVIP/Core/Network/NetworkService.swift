import Foundation

final class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func request<T: Decodable>(
        endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw NetworkError.unacceptableStatusCode(httpResponse.statusCode)
            }

            return try decoder.decode(responseType, from: data)

        } catch is CancellationError {
            throw NetworkError.cancelled
        } catch let error as NetworkError {
            throw error
        } catch is DecodingError {
            throw NetworkError.decoding
        } catch is URLError {
            throw NetworkError.transport
        } catch {
            throw NetworkError.unknown
        }
    }
}
