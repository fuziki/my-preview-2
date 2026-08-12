import Foundation

public struct FileItem: Identifiable {
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
}
