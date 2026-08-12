import Core
import Foundation

/// PhotoRatingStoreProtocolのテスト用モック
public final class MockPhotoRatingStore: PhotoRatingStoreProtocol {
    public var ratings: [URL: Int] = [:]
    public private(set) var removeAllCallCount = 0

    public init() {}

    public func rating(for url: URL) -> Int {
        ratings[url] ?? 0
    }

    public func setRating(_ rating: Int, for url: URL) {
        if rating <= 0 {
            ratings[url] = nil
        } else {
            ratings[url] = rating
        }
    }

    public func allRatings() -> [URL: Int] {
        ratings
    }

    public func removeAll() {
        removeAllCallCount += 1
        ratings.removeAll()
    }
}
