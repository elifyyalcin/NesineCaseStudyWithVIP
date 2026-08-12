import UIKit

protocol ImageDownloaderProtocol {
    func image(from url: URL) async throws -> UIImage
}

enum ImageDownloadError: Error, Equatable {
    case invalidResponse
    case unacceptableStatusCode(Int)
    case invalidImageData
}
