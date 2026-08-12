import Testing
import Foundation
import SwiftData
@testable import Core

struct ColorLabelStoreTests {

    private func makeStore() -> ColorLabelStore {
        let schema = Schema([ColorLabelRecord.self])
        let container = try! ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ColorLabelStore(modelContainer: container)
    }

    @Test
    func label_returnsNil_whenUnset() {
        let store = makeStore()
        #expect(store.label(for: URL(string: "file:///a.jpg")!) == nil)
    }

    @Test
    func setLabel_thenLabel_returnsSetValue() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!

        store.setLabel(.red, for: url)

        #expect(store.label(for: url) == .red)
    }

    @Test
    func setLabel_overwritesExistingValue_forSameURL() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!

        store.setLabel(.red, for: url)
        store.setLabel(.blue, for: url)

        #expect(store.label(for: url) == .blue)
    }

    @Test
    func setLabel_nil_removesExistingRecord() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!
        store.setLabel(.red, for: url)

        store.setLabel(nil, for: url)

        #expect(store.label(for: url) == nil)
    }

    @Test
    func allLabels_returnsAllSetLabels_keyedByURL() {
        let store = makeStore()
        let urlA = URL(string: "file:///a.jpg")!
        let urlB = URL(string: "file:///b.jpg")!

        store.setLabel(.red, for: urlA)
        store.setLabel(.green, for: urlB)

        #expect(store.allLabels() == [urlA: .red, urlB: .green])
    }

    @Test
    func removeAll_clearsAllLabels() {
        let store = makeStore()
        let url = URL(string: "file:///a.jpg")!
        store.setLabel(.red, for: url)

        store.removeAll()

        #expect(store.label(for: url) == nil)
        #expect(store.allLabels().isEmpty)
    }
}
