import UIKit

public protocol ImageLoaderServiceProtocol: Sendable {
    func loadImage(from url: URL) async -> UIImage?
}

public final class ImageLoaderService: ImageLoaderServiceProtocol {
    public init() {}

    public func loadImage(from url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
    }
}
