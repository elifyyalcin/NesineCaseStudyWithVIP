import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let networkService = NetworkService()
        let imageDownloader = ImageDownloader()
        let searchViewController = SearchBuilder.build(
            networkService: networkService,
            imageDownloader: imageDownloader
        )

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: searchViewController)
        window.makeKeyAndVisible()
        self.window = window
    }
}

