import SnapKit
import UIKit

@MainActor
final class SearchViewController: UIViewController {
    private let interactor: SearchBusinessLogic
    private let router: SearchRoutingLogic
    private let imageDownloader: ImageDownloaderProtocol

    private let searchBar = UISearchBar()
    private let collectionView: UICollectionView
    private let stateLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    private var items: [Search.ScreenshotItem] = []
    private var debounceTask: Task<Void, Never>?

    init(
        interactor: SearchBusinessLogic,
        router: SearchRoutingLogic,
        imageDownloader: ImageDownloaderProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.imageDownloader = imageDownloader
        self.collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: Self.makeCollectionViewLayout()
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        interactor.reset()
    }

    deinit {
        debounceTask?.cancel()
    }
}

extension SearchViewController: SearchDisplayLogic {
    func display(viewModel: Search.Load.ViewModel) {
        switch viewModel.state {
        case .initial(let message):
            showMessage(message)
            items = []
            collectionView.reloadData()
        case .loading:
            items = []
            collectionView.reloadData()
            stateLabel.isHidden = true
            collectionView.isHidden = true
            activityIndicator.startAnimating()
        case .content(let items):
            self.items = items
            collectionView.reloadData()
            stateLabel.isHidden = true
            activityIndicator.stopAnimating()
            collectionView.isHidden = false
        case .empty(let message), .error(let message):
            showMessage(message)
            items = []
            collectionView.reloadData()
        }
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        debounceTask?.cancel()

        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            interactor.reset()
            return
        }

        // Debouncing avoids issuing a network request for every keystroke.
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.interactor.load(request: Search.Load.Request(term: term))
        }
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        debounceTask?.cancel()
        searchBar.resignFirstResponder()

        let term = (searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            interactor.reset()
            return
        }

        debounceTask = Task { [weak self] in
            guard let self else { return }
            await self.interactor.load(request: Search.Load.Request(term: term))
        }
    }
}

extension SearchViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard items.indices.contains(indexPath.item) else { return }
        router.routeToImagePreview(imageURL: items[indexPath.item].imageURL)
    }
}

extension SearchViewController: UICollectionViewDataSource {
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        items.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: ScreenshotCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as? ScreenshotCollectionViewCell else {
            return UICollectionViewCell()
        }

        cell.configure(
            with: items[indexPath.item],
            imageDownloader: imageDownloader
        )
        return cell
    }
}

private extension SearchViewController {
    static func makeCollectionViewLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        return layout
    }

    func setupUI() {
        title = "App Screenshots"
        view.backgroundColor = .systemBackground

        searchBar.delegate = self
        searchBar.placeholder = "Search apps"
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.accessibilityIdentifier = "appSearchBar"

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .systemBackground
        collectionView.keyboardDismissMode = .onDrag
        collectionView.register(
            ScreenshotCollectionViewCell.self,
            forCellWithReuseIdentifier: ScreenshotCollectionViewCell.reuseIdentifier
        )

        stateLabel.font = .preferredFont(forTextStyle: .body)
        stateLabel.textColor = .secondaryLabel
        stateLabel.textAlignment = .center
        stateLabel.numberOfLines = 0

        view.addSubview(searchBar)
        view.addSubview(collectionView)
        view.addSubview(stateLabel)
        view.addSubview(activityIndicator)
    }

    func setupConstraints() {
        searchBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        collectionView.snp.makeConstraints {
            $0.top.equalTo(searchBar.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        stateLabel.snp.makeConstraints {
            $0.center.equalTo(collectionView)
            $0.leading.trailing.equalToSuperview().inset(32)
        }

        activityIndicator.snp.makeConstraints {
            $0.center.equalTo(collectionView)
        }
    }

    func showMessage(_ message: String) {
        activityIndicator.stopAnimating()
        collectionView.isHidden = true
        stateLabel.text = message
        stateLabel.isHidden = false
    }
}

extension SearchViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let availableWidth = collectionView.bounds.width - 44
        let width = floor(availableWidth / 2)
        return CGSize(width: width, height: width * 1.35)
    }
}
