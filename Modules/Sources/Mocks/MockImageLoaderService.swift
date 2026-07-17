import UIKit
import Core

/// シミュレータビルド用のImageLoaderServiceモック。
/// ファイルを読まず、URLの番号を描画したモック画像を返す。
public final class MockImageLoaderService: ImageLoaderServiceProtocol {
    public init() {}

    public func loadImage(from url: URL) async -> UIImage? {
        MockImageFactory.render(
            number: MockImageFactory.number(from: url),
            size: CGSize(width: 1200, height: 1600)
        )
    }
}
