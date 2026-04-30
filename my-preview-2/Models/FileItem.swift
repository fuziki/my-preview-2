import Foundation

struct FileItem: Hashable, Sendable, Identifiable {
    let id: UUID
    let url: URL
    let name: String
    let captureDate: Date?

    nonisolated init(url: URL, captureDate: Date? = nil) {
        id = UUID()
        self.url = url
        name = url.lastPathComponent
        self.captureDate = captureDate
    }

    nonisolated static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
