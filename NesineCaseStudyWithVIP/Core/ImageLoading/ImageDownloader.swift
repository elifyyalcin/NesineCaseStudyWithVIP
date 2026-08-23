import UIKit

final class ImageDownloader: ImageDownloaderProtocol {
    private let session: URLSession
    private let cache: NSCache<NSURL, UIImage>
    private let limiter: ImageDownloadLimiter

    init(
        session: URLSession = .shared,
        cache: NSCache<NSURL, UIImage> = NSCache(),
        maximumConcurrentDownloads: Int = 3
    ) {
        self.session = session
        self.cache = cache
        self.limiter = ImageDownloadLimiter(limit: maximumConcurrentDownloads)
    }

    func image(from url: URL) async throws -> UIImage {
        try Task.checkCancellation()

        if let cachedImage = cache.object(forKey: url as NSURL) {
            return cachedImage
        }

        try await limiter.acquire()

        do {
            try Task.checkCancellation()

            if let cachedImage = cache.object(forKey: url as NSURL) {
                await limiter.release()
                return cachedImage
            }

            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ImageDownloadError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw ImageDownloadError.unacceptableStatusCode(httpResponse.statusCode)
            }

            guard let image = UIImage(data: data) else {
                throw ImageDownloadError.invalidImageData
            }

            cache.setObject(image, forKey: url as NSURL)
            await limiter.release()
            return image
        } catch {
            await limiter.release()
            throw error
        }
    }
}

private actor ImageDownloadLimiter {
    private struct Waiter {
        let id: Int
        let continuation: CheckedContinuation<Void, Error>
    }

    private let limit: Int
    private var activeCount = 0
    private var waiters: [Waiter] = []
    private var nextWaiterID = 0

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func acquire() async throws {
        try Task.checkCancellation()

        if activeCount < limit {
            activeCount += 1
            return
        }

        let waiterID = nextWaiterID
        nextWaiterID += 1

        try await withTaskCancellationHandler { // beklerken cancel olursa bunu handle et
            try await withCheckedThrowingContinuation { // slot yok beklet
                (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else { // waitera konmadan önce cancel kontrol
                    continuation.resume(throwing: CancellationError())
                    return
                }

                waiters.append(Waiter(id: waiterID, continuation: continuation))
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: waiterID) // waitera eklendikten sonra beklerken cancel
            }
        }

        do {
            try Task.checkCancellation() // permit aldıktan hemen sonra cancel oldu mu
        } catch {
            release()
            throw error
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            activeCount -= 1
            return
        }

        let nextWaiter = waiters.removeFirst()
        nextWaiter.continuation.resume()
    }

    private func cancelWaiter(id: Int) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else {
            return
        }

        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
