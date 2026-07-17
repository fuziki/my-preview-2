import UIKit
import Core

/// シミュレータビルド用のThumbnailServiceモック。
/// モックサムネイルを生成し、実サービスと同様にキャッシュから同期取得できる。
/// cacheへのアクセスはMainActor上に限られるため@unchecked Sendableで問題ない。
public final class MockThumbnailService: ThumbnailServiceProtocol, @unchecked Sendable {
    private var cache: [URL: UIImage] = [:]

    public init() {}

    public func cachedThumbnail(for url: URL) -> UIImage? {
        cache[url]
    }

    public func loadThumbnail(url: URL, maxPixelSize: Int) async -> UIImage? {
        if let cached = cache[url] { return cached }
        let height = CGFloat(maxPixelSize)
        let image = MockImageFactory.render(
            number: MockImageFactory.number(from: url),
            size: CGSize(width: height * 0.75, height: height)
        )
        cache[url] = image
        return image
    }
}
