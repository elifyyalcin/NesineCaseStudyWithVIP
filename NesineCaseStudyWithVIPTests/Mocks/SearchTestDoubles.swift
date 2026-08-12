import XCTest
@testable import NesineCaseStudyWithVIP

enum TestError: Error {
    case expected
    case typeMismatch
}

final class SearchWorkerStub: SearchWorking {
    private let result: Result<ITunesSearchResponse, Error>

    init(result: Result<ITunesSearchResponse, Error>) {
        self.result = result
    }

    func search(term: String) async throws -> ITunesSearchResponse {
        try result.get()
    }
}

actor ControllableSearchWorker: SearchWorking {
    private var responseContinuations: [
        String: CheckedContinuation<ITunesSearchResponse, Error>
    ] = [:]
    private var requestedTerms: Set<String> = []
    private var requestWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]

    func search(term: String) async throws -> ITunesSearchResponse {
        requestedTerms.insert(term)
        requestWaiters.removeValue(forKey: term)?.forEach { $0.resume() }

        return try await withCheckedThrowingContinuation { continuation in
            responseContinuations[term] = continuation
        }
    }

    func waitUntilRequested(_ term: String) async {
        guard !requestedTerms.contains(term) else { return }

        await withCheckedContinuation { continuation in
            requestWaiters[term, default: []].append(continuation)
        }
    }

    func complete(term: String, with response: ITunesSearchResponse) {
        responseContinuations.removeValue(forKey: term)?.resume(returning: response)
    }
}

@MainActor
final class SearchPresentationSpy: SearchPresentationLogic {
    private(set) var responses: [Search.Load.Response] = []
    var onPresent: ((Search.Load.Response) -> Void)?

    func present(response: Search.Load.Response) {
        responses.append(response)
        onPresent?(response)
    }
}

@MainActor
final class SearchDisplaySpy: SearchDisplayLogic {
    private(set) var viewModels: [Search.Load.ViewModel] = []

    func display(viewModel: Search.Load.ViewModel) {
        viewModels.append(viewModel)
    }
}
