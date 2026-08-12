import UIKit

public protocol ImageLoaderServiceProtocol: Sendable {
    func loadImage(from url: URL) async -> UIImage?
}

public final class ImageLoaderService: ImageLoaderServiceProtocol {
    private let tracker: FileLoadingTracker

    /// デコード済み画像のオンメモリキャッシュ。上限超過やメモリ逼迫時はシステムが自動的に解放する
    private let cache = NSCache<NSURL, UIImage>()

    public init(tracker: FileLoadingTracker, cacheLimitBytes: Int = 100 * 1024 * 1024) {
        self.tracker = tracker
        cache.totalCostLimit = cacheLimitBytes
    }

    public func loadImage(from url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        let load: () async -> UIImage? = {
            await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }.value
        }
        guard let image = await tracker.track(load) else { return nil }
        cache.setObject(image, forKey: url as NSURL, cost: Self.estimatedCost(of: image))
        return image
    }

    /// デコード後のピクセルバッファの概算バイト数をキャッシュコストとして扱う
    private static func estimatedCost(of image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 1 }
        return cgImage.bytesPerRow * cgImage.height
    }
}
