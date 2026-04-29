import Foundation

struct FileItem: Hashable, Sendable, Identifiable {
    let id: UUID
    let url: URL
    let name: String

    nonisolated init(url: URL) {
        id = UUID()
        self.url = url
        name = url.lastPathComponent
    }

    nonisolated static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
