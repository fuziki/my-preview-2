import UIKit

public protocol ImageLoaderServiceProtocol: Sendable {
    func loadImage(from url: URL) async -> UIImage?
}

public final class ImageLoaderService: ImageLoaderServiceProtocol {
    private let tracker: FileLoadingTracker

    public init(tracker: FileLoadingTracker) {
        self.tracker = tracker
    }

    public func loadImage(from url: URL) async -> UIImage? {
        let load: () async -> UIImage? = {
            await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url) else { return nil }
                return UIImage(data: data)
            }.value
        }
        return await tracker.track(load)
    }
}
