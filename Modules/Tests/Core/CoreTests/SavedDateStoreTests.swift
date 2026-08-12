import Testing
import Foundation
import SwiftData
@testable import Core

struct SavedDateStoreTests {

    private func makeStore() -> SavedDateStore {
        let schema = Schema([SavedDateRecord.self])
        let container = try! ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return SavedDateStore(modelContainer: container)
    }

    @Test
    func date_returnsNil_whenUnset() {
        let store = makeStore()
        #expect(store.date(for: URL(string: "file:///a.jpg")!) == nil)
    }

    @Test
    func setDate_thenDate_returnsSetValue() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        store.setDate(date, for: url)

        #expect(store.date(for: url) == date)
    }

    @Test
    func setDate_overwritesExistingValue_forSameURL() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!
        let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDate = Date(timeIntervalSince1970: 1_700_000_100)

        store.setDate(firstDate, for: url)
        store.setDate(secondDate, for: url)

        #expect(store.date(for: url) == secondDate)
    }

    @Test
    func removeAll_clearsAllDates() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!
        store.setDate(Date(timeIntervalSince1970: 1_700_000_000), for: url)

        store.removeAll()

        #expect(store.date(for: url) == nil)
    }
}
