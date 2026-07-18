import Core
import Foundation

/// PhotoRatingStoreProtocolのテスト用モック
final class MockPhotoRatingStore: PhotoRatingStoreProtocol {
    var ratings: [URL: Int] = [:]
    private(set) var removeAllCallCount = 0

    func rating(for url: URL) -> Int {
        ratings[url] ?? 0
    }

    func setRating(_ rating: Int, for url: URL) {
        if rating <= 0 {
            ratings[url] = nil
        } else {
            ratings[url] = rating
        }
    }

    func allRatings() -> [URL: Int] {
        ratings
    }

    func removeAll() {
        removeAllCallCount += 1
        ratings.removeAll()
    }
}
