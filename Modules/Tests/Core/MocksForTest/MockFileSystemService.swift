import Core
import Foundation

/// FileSystemServiceProtocolのテスト用モック
public final class MockFileSystemService: FileSystemServiceProtocol {
    public var stubbedItems: [FileItem] = []
    public private(set) var scanCallCount = 0

    public init() {}

    public func scanForJPEGs(in folderURL: URL) async -> [FileItem] {
        scanCallCount += 1
        return stubbedItems
    }
}
