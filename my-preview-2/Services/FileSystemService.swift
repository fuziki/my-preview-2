import Foundation

protocol FileSystemServiceProtocol: AnyObject {
    func scanForJPEGs(in folderURL: URL) async -> [FileItem]
}

final class FileSystemService: FileSystemServiceProtocol {
    func scanForJPEGs(in folderURL: URL) async -> [FileItem] {
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
}
