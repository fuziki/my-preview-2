import Core
import Foundation

/// FileSystemServiceProtocolのテスト用モック
final class MockFileSystemService: FileSystemServiceProtocol {
    var stubbedItems: [FileItem] = []
    var scanCallCount = 0

    func scanForJPEGs(in folderURL: URL) async -> [FileItem] {
        scanCallCount += 1
        return stubbedItems
    }
}
