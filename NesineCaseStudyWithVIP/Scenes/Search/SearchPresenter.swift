import Foundation

@MainActor
protocol SearchPresentationLogic: AnyObject {
    func present(response: Search.Load.Response)
}

@MainActor
protocol SearchDisplayLogic: AnyObject {
    func display(viewModel: Search.Load.ViewModel)
}

@MainActor
final class SearchPresenter: SearchPresentationLogic {
    weak var viewController: SearchDisplayLogic?

    func present(response: Search.Load.Response) {
        let state: Search.Load.ViewModel.State

        switch response.state {
        case .initial:
            state = .initial(message: "Search for an app")
        case .loading:
            state = .loading
        case .success(let screenshots) where screenshots.isEmpty:
            state = .empty(message: "No results found.")
        case .success(let screenshots):
            let items = screenshots.map {
                Search.ScreenshotItem(
                    imageURL: $0.imageURL,
                    appName: $0.appName ?? "Unknown App"
                )
            }
            state = .content(items)
        case .failure:
            state = .error(message: "Something went wrong. Please try again.")
        }

        viewController?.display(viewModel: Search.Load.ViewModel(state: state))
    }
}
