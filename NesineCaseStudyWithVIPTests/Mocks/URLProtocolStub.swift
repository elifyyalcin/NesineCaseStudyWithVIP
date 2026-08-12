import Foundation

final class URLProtocolStub: URLProtocol {
    typealias Handler = (URLRequest) async throws -> (HTTPURLResponse, Data)

    static var handler: Handler?
    private var loadingTask: Task<Void, Never>?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: TestError.expected)
            return
        }

        loadingTask = Task {
            do {
                let (response, data) = try await handler(request)
                try Task.checkCancellation()
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}

actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let currentWaiters = waiters
        waiters.removeAll()
        currentWaiters.forEach { $0.resume() }
    }
}

actor ConcurrencyProbe {
    private(set) var maximumActiveCount = 0
    private var activeCount = 0
    private var targetWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func begin() {
        activeCount += 1
        maximumActiveCount = max(maximumActiveCount, activeCount)

        let reached = targetWaiters.filter { activeCount >= $0.0 }
        targetWaiters.removeAll { activeCount >= $0.0 }
        reached.forEach { $0.1.resume() }
    }

    func end() {
        activeCount -= 1
    }

    func waitUntilActiveCountReaches(_ target: Int) async {
        guard activeCount < target else { return }
        await withCheckedContinuation { targetWaiters.append((target, $0)) }
    }
}

actor RequestCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}
