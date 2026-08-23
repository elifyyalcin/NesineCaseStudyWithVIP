import Foundation

@MainActor
protocol SearchBusinessLogic: AnyObject {
    func load(request: Search.Load.Request) async
    func reset()
}

@MainActor
final class SearchInteractor: SearchBusinessLogic {
    private let worker: SearchWorking
    private let presenter: SearchPresentationLogic
    private var requestGeneration = 0

    init(worker: SearchWorking, presenter: SearchPresentationLogic) {
        self.worker = worker
        self.presenter = presenter
    }

    func load(request: Search.Load.Request) async {
        requestGeneration += 1
        let generation = requestGeneration

        presenter.present(response: Search.Load.Response(state: .loading))

        do {
            let apiResponse = try await worker.search(term: request.term)
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }

            let screenshots = apiResponse.results.flatMap { result in
                result.screenshotUrls.map { url in
                    Search.Screenshot(
                        imageURL: url,
                        appName: result.trackName
                    )
                }
            }

            presenter.present(response: Search.Load.Response(state: .success(screenshots)))
        } catch is CancellationError {
            return
        } catch NetworkError.cancelled {
            return
        } catch {
            guard generation == requestGeneration else { return }
            presenter.present(response: Search.Load.Response(state: .failure))
        }
    }

    func reset() {
        requestGeneration += 1
        presenter.present(response: Search.Load.Response(state: .initial))
    }
}
