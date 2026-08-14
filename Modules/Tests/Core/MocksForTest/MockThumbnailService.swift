import Core
import UIKit

/// ThumbnailServiceProtocolのテスト用モック
public final class MockThumbnailService: ThumbnailServiceProtocol, @unchecked Sendable {
    /// cachedThumbnail / loadThumbnailが返すサムネイル（nilで「未キャッシュ・読み込み失敗」を表現）
    public var stubbedThumbnail: UIImage? = nil
    public private(set) var loadCallCount = 0

    public init() {}

    public func cachedThumbnail(for url: URL) -> UIImage? {
        stubbedThumbnail
    }

    public func loadThumbnail(url: URL, maxPixelSize: Int) async -> UIImage? {
        loadCallCount += 1
        return stubbedThumbnail
    }
}
