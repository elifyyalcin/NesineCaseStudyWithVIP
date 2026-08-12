import UIKit

enum SearchBuilder {
    @MainActor
    static func build(
        networkService: NetworkServiceProtocol,
        imageDownloader: ImageDownloaderProtocol
    ) -> UIViewController {
        let worker = SearchWorker(networkService: networkService)
        let presenter = SearchPresenter()
        let interactor = SearchInteractor(worker: worker, presenter: presenter)
        let router = SearchRouter(imageDownloader: imageDownloader)
        let viewController = SearchViewController(
            interactor: interactor,
            router: router,
            imageDownloader: imageDownloader
        )

        presenter.viewController = viewController
        router.viewController = viewController
        return viewController
    }
}
