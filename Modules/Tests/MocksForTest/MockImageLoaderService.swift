import Core
import UIKit

/// ImageLoaderServiceProtocolのテスト用モック
public final class MockImageLoaderService: ImageLoaderServiceProtocol, @unchecked Sendable {
    /// loadImageが返す画像（nilで「画像なし」を表現）
    public var stubbedImage: UIImage? = UIImage()
    public private(set) var loadCallCount = 0

    public init() {}

    public func loadImage(from url: URL) async -> UIImage? {
        loadCallCount += 1
        return stubbedImage
    }
}
