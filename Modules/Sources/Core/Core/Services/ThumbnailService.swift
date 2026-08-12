import UIKit
import ImageIO

public protocol ThumbnailServiceProtocol: Sendable {
    /// キャッシュに存在する場合は同期で返す（フリッカー防止）
    func cachedThumbnail(for url: URL) -> UIImage?
    func loadThumbnail(url: URL, maxPixelSize: Int) async -> UIImage?
}

public final class ThumbnailService: ThumbnailServiceProtocol, @unchecked Sendable {
    private let tracker: FileLoadingTracker
    private let cache = ThumbnailCache()

    public init(tracker: FileLoadingTracker) {
        self.tracker = tracker
    }

    public func cachedThumbnail(for url: URL) -> UIImage? {
        cache.image(for: url)
    }

    public func loadThumbnail(url: URL, maxPixelSize: Int) async -> UIImage? {
        let image = await tracker.track {
            await Task.detached(priority: .userInitiated) {
                Self.make(url: url, maxPixelSize: maxPixelSize)
            }.value
        }
        if let image { cache.setImage(image, for: url) }
        return image
    }

    private static nonisolated func make(url: URL, maxPixelSize: Int) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private final class ThumbnailCache: @unchecked Sendable {
    private let cache = NSCache<NSURL, UIImage>()

    init() {
        cache.countLimit = 500
        cache.totalCostLimit = 100 * 1024 * 1024
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func setImage(_ image: UIImage, for url: URL) {
        cache.setObject(image, forKey: url as NSURL)
    }
}
