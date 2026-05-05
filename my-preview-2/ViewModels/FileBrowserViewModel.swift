import Foundation
import Observation

@Observable
final class FileBrowserViewModel {
    private(set) var items: [FileItem] = []
    private(set) var hasFolder: Bool = false
    private(set) var isLoading: Bool = false
    private var rootURL: URL? = nil

    private let fileSystemService: any FileSystemServiceProtocol

    init(fileSystemService: any FileSystemServiceProtocol) {
        self.fileSystemService = fileSystemService
    }

    func selectFolder(_ url: URL) async {
        rootURL?.stopAccessingSecurityScopedResource()
        guard url.startAccessingSecurityScopedResource() else { return }
        rootURL = url
        hasFolder = true
        await loadItems()
    }

    private func loadItems() async {
        guard let url = rootURL else { return }
        isLoading = true
        items = await fileSystemService.scanForJPEGs(in: url)
        isLoading = false
    }
}
