import Core
import Foundation

/// PhotoLibraryServiceProtocolのテスト用モック
public final class MockPhotoLibraryService: PhotoLibraryServiceProtocol {
    /// trueにすると保存時にエラーをスローする
    public var shouldThrow = false
    public private(set) var saveCallCount = 0

    public init() {}

    public func save(fileURL: URL) async throws {
        saveCallCount += 1
        if shouldThrow {
            throw PhotoLibraryError.unauthorized
        }
    }
}
