import Core
import Foundation

/// PhotoLibraryServiceProtocolのテスト用モック
final class MockPhotoLibraryService: PhotoLibraryServiceProtocol {
    /// trueにすると保存時にエラーをスローする
    var shouldThrow = false
    var saveCallCount = 0

    func save(fileURL: URL) async throws {
        saveCallCount += 1
        if shouldThrow {
            throw PhotoLibraryError.unauthorized
        }
    }
}
