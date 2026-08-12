import Core
import Foundation

/// SavedDateStoreProtocolのテスト用モック
public final class MockSavedDateStore: SavedDateStoreProtocol {
    public private(set) var dates: [URL: Date] = [:]
    public private(set) var removeAllCallCount = 0

    public init() {}

    public func date(for url: URL) -> Date? {
        dates[url]
    }

    public func setDate(_ date: Date, for url: URL) {
        dates[url] = date
    }

    public func removeAll() {
        removeAllCallCount += 1
        dates.removeAll()
    }
}
