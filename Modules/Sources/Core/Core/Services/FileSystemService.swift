import Foundation

public protocol FileSystemServiceProtocol {
    func scanForJPEGs(in folderURL: URL) async -> [FileItem]
}

public final class FileSystemService: FileSystemServiceProtocol {
    private let tracker: FileLoadingTracker

    public init(tracker: FileLoadingTracker) {
        self.tracker = tracker
    }

    public func scanForJPEGs(in folderURL: URL) async -> [FileItem] {
        let scan: () async -> [FileItem] = {
            await Task.detached(priority: .userInitiated) {
                let contents = try? FileManager.default.contentsOfDirectory(
                    at: folderURL,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: .skipsHiddenFiles
                )
                return (contents ?? [])
                    .filter { ["jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
                    .map { url -> FileItem in
                        let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                        return FileItem(url: url, captureDate: date)
                    }
                    .sorted {
                        ($0.captureDate ?? .distantFuture) < ($1.captureDate ?? .distantFuture)
                    }
            }.value
        }
        return await tracker.track(scan)
    }
}
