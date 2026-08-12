import Foundation

enum NetworkError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case unacceptableStatusCode(Int)
    case decoding
    case transport
    case cancelled
    case unknown
}
