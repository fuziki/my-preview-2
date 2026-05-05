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

final class ThumbnailCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        return iv
    }()

    private var loadingTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadingTask?.cancel()
        loadingTask = nil
        imageView.image = nil
    }

    func configure(with url: URL, thumbnailPixelSize: Int) {
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
}
