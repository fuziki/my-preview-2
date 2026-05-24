import Core
import UIKit

/// ImageLoaderServiceProtocolのテスト用モック
final class MockImageLoaderService: ImageLoaderServiceProtocol, @unchecked Sendable {
    /// loadImageが返す画像（nilで「画像なし」を表現）
    var stubbedImage: UIImage? = UIImage()
    var loadCallCount = 0

    func loadImage(from url: URL) async -> UIImage? {
        loadCallCount += 1
        return stubbedImage
    }
}
