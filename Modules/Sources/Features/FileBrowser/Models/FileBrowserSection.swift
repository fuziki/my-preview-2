import Foundation
import Core

public struct FileBrowserSection: Sendable {
    public nonisolated struct ID: Hashable, Sendable {
        public let dateKey: String
    }
    public let id: ID
    public let items: [FileItem]
}
