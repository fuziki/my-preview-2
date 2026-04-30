import Foundation
import Observation

@Observable
final class FileBrowserViewModel {
    private(set) var items: [FileItem] = []
    private(set) var hasFolder: Bool = false
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
        let loaded = await Task.detached(priority: .userInitiated) {
            let contents = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            return (contents ?? [])
                .filter { ["jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                .map { FileItem(url: $0) }
        }.value
        await MainActor.run {
            self.items = loaded
        }
    }
}
