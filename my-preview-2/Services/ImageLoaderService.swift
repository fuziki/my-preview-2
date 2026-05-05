import UIKit

protocol ImageLoaderServiceProtocol: AnyObject {
    func loadImage(from url: URL) async -> UIImage?
}

final class ImageLoaderService: ImageLoaderServiceProtocol {
    func loadImage(from url: URL) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
    }
}
