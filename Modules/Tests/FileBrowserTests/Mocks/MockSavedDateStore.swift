import Core
import Foundation

/// SavedDateStoreProtocolのテスト用モック
final class MockSavedDateStore: SavedDateStoreProtocol {
    private(set) var dates: [URL: Date] = [:]
    private(set) var removeAllCallCount = 0

    func date(for url: URL) -> Date? {
        dates[url]
    }

    func setDate(_ date: Date, for url: URL) {
        dates[url] = date
    }

    func removeAll() {
        removeAllCallCount += 1
        dates.removeAll()
    }
}
