import Foundation

/// フィルター済み写真リストの唯一の真実（SSOT）。FileBrowser と PhotoViewer が共有する。
/// FileBrowser が `setURLs` で公開し、PhotoViewer がフィルター外れの写真を `remove` で除去する。
/// セッション内共有のインメモリ状態（永続化しない）。
public protocol PhotoCollectionStoreProtocol: AnyObject {
    var urls: [URL] { get }
    func setURLs(_ urls: [URL])
    func remove(url: URL)
}

public final class PhotoCollectionStore: PhotoCollectionStoreProtocol {
    public private(set) var urls: [URL] = []

    public init() {}

    public func setURLs(_ urls: [URL]) {
        self.urls = urls
    }

    public func remove(url: URL) {
        urls.removeAll { $0 == url }
    }
}
