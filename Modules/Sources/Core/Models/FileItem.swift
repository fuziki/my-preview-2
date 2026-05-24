import Foundation

public struct FileItem: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let captureDate: Date?

    public nonisolated init(url: URL, captureDate: Date? = nil) {
        id = UUID()
        self.url = url
        name = url.lastPathComponent
        self.captureDate = captureDate
    }

    public nonisolated static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}
