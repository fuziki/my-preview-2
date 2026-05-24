import Core
import Foundation

/// SavedDateStoreProtocolのテスト用モック
final class MockSavedDateStore: SavedDateStoreProtocol {
    private var dates: [URL: Date] = [:]

    func date(for url: URL) -> Date? {
        dates[url]
    }

    func setDate(_ date: Date, for url: URL) {
        dates[url] = date
    }
}
