import SnapKit
import UIKit

@MainActor
final class ImagePreviewViewController: UIViewController {
    private let imageURL: URL
    private let imageDownloader: ImageDownloaderProtocol
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let errorLabel = UILabel()
    private var imageTask: Task<Void, Never>?

    init(imageURL: URL, imageDownloader: ImageDownloaderProtocol) {
        self.imageURL = imageURL
        self.imageDownloader = imageDownloader
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
        loadImage()
    }

    deinit {
        imageTask?.cancel()
    }
}

private extension ImagePreviewViewController {
    func setupUI() {
        view.backgroundColor = .black

        imageView.contentMode = .scaleAspectFit

        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.accessibilityLabel = "Close"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        activityIndicator.color = .white

        errorLabel.text = "Image could not be loaded."
        errorLabel.textColor = .white
        errorLabel.textAlignment = .center
        errorLabel.isHidden = true

        view.addSubview(imageView)
        view.addSubview(closeButton)
        view.addSubview(activityIndicator)
        view.addSubview(errorLabel)
    }

    func setupConstraints() {
        closeButton.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            $0.trailing.equalTo(view.safeAreaLayoutGuide).inset(16)
            $0.size.equalTo(36)
        }

        imageView.snp.makeConstraints {
            $0.top.equalTo(closeButton.snp.bottom).offset(12)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(12)
        }

        activityIndicator.snp.makeConstraints {
            $0.center.equalToSuperview()
        }

        errorLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(32)
        }
    }

    func loadImage() {
        activityIndicator.startAnimating()

        imageTask = Task { [weak self, imageURL, imageDownloader] in
            do {
                let image = try await imageDownloader.image(from: imageURL)
                guard !Task.isCancelled, let self else { return }
                self.activityIndicator.stopAnimating()
                self.imageView.image = image
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.activityIndicator.stopAnimating()
                self.errorLabel.isHidden = false
            }
        }
    }

    @objc func closeTapped() {
        dismiss(animated: true)
    }
}
