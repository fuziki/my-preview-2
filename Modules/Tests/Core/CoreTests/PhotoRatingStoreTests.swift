import Testing
import Foundation
import SwiftData
@testable import Core

struct PhotoRatingStoreTests {

    private func makeStore() -> PhotoRatingStore {
        let schema = Schema([PhotoRatingRecord.self])
        let container = try! ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return PhotoRatingStore(modelContainer: container)
    }

    @Test
    func rating_returnsZero_whenUnset() {
        let store = makeStore()
        #expect(store.rating(for: URL(string: "file:///a.jpg")!) == 0)
    }

    @Test
    func setRating_thenRating_returnsSetValue() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!

        store.setRating(3, for: url)

        #expect(store.rating(for: url) == 3)
    }

    @Test
    func setRating_overwritesExistingValue_forSameURL() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!

        store.setRating(3, for: url)
        store.setRating(5, for: url)

        #expect(store.rating(for: url) == 5)
    }

    @Test
    func setRating_zero_removesExistingRecord() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!
        store.setRating(3, for: url)

        store.setRating(0, for: url)

        #expect(store.rating(for: url) == 0)
    }

    @Test
    func setRating_negative_treatedAsZero_removesExistingRecord() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!
        store.setRating(3, for: url)

        store.setRating(-1, for: url)

        #expect(store.rating(for: url) == 0)
    }

    @Test
    func allRatings_returnsAllSetRatings_keyedByURL() {
        let store = makeStore()
        let urlA = URL(string: "file:///a.jpg")!
        let urlB = URL(string: "file:///b.jpg")!

        store.setRating(2, for: urlA)
        store.setRating(4, for: urlB)

        #expect(store.allRatings() == [urlA: 2, urlB: 4])
    }

    @Test
    func removeAll_clearsAllRatings() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!
        store.setRating(3, for: url)

        store.removeAll()

        #expect(store.rating(for: url) == 0)
        #expect(store.allRatings().isEmpty)
    }
}
