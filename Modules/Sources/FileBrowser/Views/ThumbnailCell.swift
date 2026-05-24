import UIKit
import ImageIO

// MARK: - ThumbnailCache

final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSURL, UIImage>()

    private init() {
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}

// MARK: - Thumbnail Generation

nonisolated func makeThumbnail(url: URL, maxPixelSize: Int) -> UIImage? {
    let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else { return nil }

    // 高速パス: 埋め込みサムネイルを使用する
    let fastOptions: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
    ]

    guard let embedded = CGImageSourceCreateThumbnailAtIndex(source, 0, fastOptions as CFDictionary) else { return nil }
    let ui = UIImage(cgImage: embedded)
    return ui
}

// MARK: - ThumbnailCell

public final class ThumbnailCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        return iv
    }()

    // 「最後に表示」バッジのラベル
    private let lastViewedLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "最後に表示"
        label.textColor = .white
        label.font = .systemFont(ofSize: 9, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 1
        return label
    }()

    // 「最後に表示」バッジの背景（半透明の黒帯）
    private let lastViewedBadge: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        v.isHidden = true
        return v
    }()

    private var loadingTask: Task<Void, Never>?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        contentView.addSubview(imageView)
        contentView.addSubview(lastViewedBadge)
        lastViewedBadge.addSubview(lastViewedLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // バッジは下部全幅に配置する
            lastViewedBadge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            lastViewedBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            lastViewedBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            lastViewedLabel.topAnchor.constraint(equalTo: lastViewedBadge.topAnchor, constant: 3),
            lastViewedLabel.bottomAnchor.constraint(equalTo: lastViewedBadge.bottomAnchor, constant: -3),
            lastViewedLabel.leadingAnchor.constraint(equalTo: lastViewedBadge.leadingAnchor, constant: 4),
            lastViewedLabel.trailingAnchor.constraint(equalTo: lastViewedBadge.trailingAnchor, constant: -4),
        ])
    }

    required public init?(coder: NSCoder) { fatalError() }

    override public func prepareForReuse() {
        super.prepareForReuse()
        loadingTask?.cancel()
        loadingTask = nil
        imageView.image = nil
        lastViewedBadge.isHidden = true
    }

    public func configure(with url: URL, thumbnailPixelSize: Int) {
        // キャッシュヒット（同期）— フリッカーなし
        if let cached = ThumbnailCache.shared.image(for: url) {
            imageView.image = cached
            return
        }

        loadingTask = Task { @MainActor [weak self] in
            let image = await Task.detached(priority: .userInitiated) {
                makeThumbnail(url: url, maxPixelSize: thumbnailPixelSize)
            }.value

            guard !Task.isCancelled, let self else { return }

            if let image {
                ThumbnailCache.shared.setImage(image, for: url)
            }
            imageView.image = image
        }
    }

    /// 「最後に表示」バッジの表示状態を設定する
    public func setLastViewed(_ show: Bool) {
        lastViewedBadge.isHidden = !show
    }
}
