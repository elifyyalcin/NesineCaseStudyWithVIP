import SnapKit
import UIKit

@MainActor
final class ScreenshotCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = String(describing: ScreenshotCollectionViewCell.self)

    private let screenshotImageView = UIImageView()
    private let titleLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var imageTask: Task<Void, Never>?
    private var representedURL: URL?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(
        with item: Search.ScreenshotItem,
        imageDownloader: ImageDownloaderProtocol
    ) {
        imageTask?.cancel()
        representedURL = item.imageURL
        titleLabel.text = item.appName
        screenshotImageView.image = UIImage(systemName: "photo")
        screenshotImageView.tintColor = .tertiaryLabel
        activityIndicator.startAnimating()

        let url = item.imageURL
        imageTask = Task { [weak self] in
            do {
                let image = try await imageDownloader.image(from: url)
                guard !Task.isCancelled, let self, self.representedURL == url else {
                    return
                }

                self.screenshotImageView.image = image
                self.screenshotImageView.tintColor = nil
                self.activityIndicator.stopAnimating()
            } catch {
                guard !Task.isCancelled, let self, self.representedURL == url else {
                    return
                }
                self.screenshotImageView.image = UIImage(systemName: "exclamationmark.triangle")
                self.activityIndicator.stopAnimating()
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        representedURL = nil
        screenshotImageView.image = UIImage(systemName: "photo")
        titleLabel.text = nil
        activityIndicator.stopAnimating()
    }
}

private extension ScreenshotCollectionViewCell {
    func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        layer.masksToBounds = true

        screenshotImageView.contentMode = .scaleAspectFill
        screenshotImageView.clipsToBounds = true
        screenshotImageView.backgroundColor = .tertiarySystemBackground

        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 1

        contentView.addSubview(screenshotImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(activityIndicator)
    }

    func setupConstraints() {
        screenshotImageView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(titleLabel.snp.top).offset(-8)
        }

        titleLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(8)
            $0.bottom.equalToSuperview().inset(8)
            $0.height.equalTo(18)
        }

        activityIndicator.snp.makeConstraints {
            $0.center.equalTo(screenshotImageView)
        }
    }
}
