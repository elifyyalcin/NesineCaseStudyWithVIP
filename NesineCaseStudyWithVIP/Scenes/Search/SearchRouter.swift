import UIKit

@MainActor
protocol SearchRoutingLogic: AnyObject {
    func routeToImagePreview(imageURL: URL)
}

@MainActor
final class SearchRouter: SearchRoutingLogic {
    weak var viewController: UIViewController?
    private let imageDownloader: ImageDownloaderProtocol

    init(imageDownloader: ImageDownloaderProtocol) {
        self.imageDownloader = imageDownloader
    }

    func routeToImagePreview(imageURL: URL) {
        let previewViewController = ImagePreviewViewController(
            imageURL: imageURL,
            imageDownloader: imageDownloader
        )
        previewViewController.modalPresentationStyle = .fullScreen
        viewController?.present(previewViewController, animated: true)
    }
}
