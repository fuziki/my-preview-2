import Foundation
import Observation

@Observable
final class FileBrowserViewModel {
    private(set) var items: [FileItem] = []
    private(set) var hasFolder: Bool = false
    private(set) var isLoading: Bool = false
    private var rootURL: URL? = nil

    func selectFolder(_ url: URL) async {
        rootURL?.stopAccessingSecurityScopedResource()
        guard url.startAccessingSecurityScopedResource() else { return }
        rootURL = url
        hasFolder = true
        await loadItems()
    }

    func loadItems() async {
        guard let url = rootURL else { return }
        isLoading = true
        let loaded: [FileItem] = await Task.detached(priority: .userInitiated) {
            // Bulk-fetch creationDate at directory scan time (near-zero extra cost)
            let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
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
        await MainActor.run {
            self.items = loaded
            self.isLoading = false
        }
    }
}
