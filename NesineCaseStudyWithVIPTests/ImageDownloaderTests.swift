import UIKit
import XCTest
@testable import NesineCaseStudyWithVIP

final class ImageDownloaderTests: XCTestCase {
    private var session: URLSession?

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        URLProtocolStub.handler = nil
        session?.invalidateAndCancel()
        session = nil
        super.tearDown()
    }

    func test_imageDownloader_whenImageIsCached_shouldAvoidAnotherNetworkRequest() async throws {
        let counter = RequestCounter()
        let imageData = try makeImageData()
        URLProtocolStub.handler = { request in
            await counter.increment()
            return (try makeHTTPResponse(for: request, statusCode: 200), imageData)
        }
        let downloader = ImageDownloader(session: try XCTUnwrap(session))
        let url = try XCTUnwrap(URL(string: "https://example.com/cached.png"))

        _ = try await downloader.image(from: url)
        _ = try await downloader.image(from: url)

        let requestCount = await counter.count
        XCTAssertEqual(requestCount, 1)
    }

    func test_imageDownloader_whenRequestFails_shouldReturnError() async throws {
        URLProtocolStub.handler = { request in
            (try makeHTTPResponse(for: request, statusCode: 500), Data())
        }
        let downloader = ImageDownloader(session: try XCTUnwrap(session))
        let url = try XCTUnwrap(URL(string: "https://example.com/failure.png"))

        do {
            _ = try await downloader.image(from: url)
            XCTFail("Expected image loading to fail")
        } catch let error as ImageDownloadError {
            XCTAssertEqual(error, .unacceptableStatusCode(500))
        } catch {
            XCTFail("Received unexpected error: \(error)")
        }
    }

    func test_imageDownloader_shouldNeverExceedThreeConcurrentDownloads() async throws {
        let gate = AsyncGate()
        let probe = ConcurrencyProbe()
        let imageData = try makeImageData()
        URLProtocolStub.handler = { request in
            await probe.begin()
            await gate.wait()
            await probe.end()
            return (try makeHTTPResponse(for: request, statusCode: 200), imageData)
        }
        let downloader = ImageDownloader(session: try XCTUnwrap(session))
        let urls = try (0..<8).map { index in
            try XCTUnwrap(URL(string: "https://example.com/\(index).png"))
        }

        let tasks = urls.map { url in
            Task {
                try await downloader.image(from: url)
            }
        }

        await probe.waitUntilActiveCountReaches(3)
        let initialMaximum = await probe.maximumActiveCount
        XCTAssertEqual(initialMaximum, 3)
        await gate.open()

        for task in tasks {
            _ = try await task.value
        }
        let finalMaximum = await probe.maximumActiveCount
        XCTAssertLessThanOrEqual(finalMaximum, 3)
    }

    func test_imageDownloader_whenTaskIsCancelled_shouldCancelRequest() async throws {
        let probe = ConcurrencyProbe()
        URLProtocolStub.handler = { request in
            await probe.begin()
            try await Task.sleep(nanoseconds: 5_000_000_000)
            await probe.end()
            return (try makeHTTPResponse(for: request, statusCode: 200), Data())
        }
        let downloader = ImageDownloader(session: try XCTUnwrap(session))
        let url = try XCTUnwrap(URL(string: "https://example.com/cancelled.png"))

        let task = Task {
            try await downloader.image(from: url)
        }
        await probe.waitUntilActiveCountReaches(1)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected.
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cancelled)
        } catch {
            XCTFail("Received unexpected error: \(error)")
        }
    }

    func test_imageDownloader_whenCancelledWhileWaiting_shouldFinishWithoutPermitRelease() async throws {
        let gate = AsyncGate()
        let probe = ConcurrencyProbe()
        let counter = RequestCounter()
        let imageData = try makeImageData()
        URLProtocolStub.handler = { request in
            await counter.increment()
            await probe.begin()
            await gate.wait()
            await probe.end()
            return (try makeHTTPResponse(for: request, statusCode: 200), imageData)
        }
        let downloader = ImageDownloader(
            session: try XCTUnwrap(session),
            maximumConcurrentDownloads: 1
        )
        let activeURL = try XCTUnwrap(URL(string: "https://example.com/active.png"))
        let waitingURL = try XCTUnwrap(URL(string: "https://example.com/waiting.png"))

        let activeTask = Task {
            try await downloader.image(from: activeURL)
        }
        await probe.waitUntilActiveCountReaches(1)

        let waitingTask = Task {
            try await downloader.image(from: waitingURL)
        }
        await Task.yield()
        waitingTask.cancel()

        let cancellationFinished = expectation(description: "Waiting task cancelled")
        Task {
            do {
                _ = try await waitingTask.value
                XCTFail("Expected cancellation")
            } catch is CancellationError {
                cancellationFinished.fulfill()
            } catch {
                XCTFail("Received unexpected error: \(error)")
            }
        }

        await fulfillment(of: [cancellationFinished], timeout: 1)
        let requestCount = await counter.count
        XCTAssertEqual(requestCount, 1)

        await gate.open()
        _ = try await activeTask.value
    }
}

private func makeHTTPResponse(
    for request: URLRequest,
    statusCode: Int
) throws -> HTTPURLResponse {
    let url = try XCTUnwrap(request.url)
    return try XCTUnwrap(
        HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/png"]
        )
    )
}

private func makeImageData() throws -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
    let image = renderer.image { context in
        UIColor.systemBlue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    return try XCTUnwrap(image.pngData())
}
