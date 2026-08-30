import Testing
import Foundation
@testable import Core

// MARK: - テスト

struct PhotoCollectionStoreTests {

    let url1 = URL(fileURLWithPath: "/tmp/photo1.jpg")
    let url2 = URL(fileURLWithPath: "/tmp/photo2.jpg")
    let url3 = URL(fileURLWithPath: "/tmp/photo3.jpg")

    // MARK: - 初期状態

    @Test
    func initialState_urlsIsEmpty() {
        let store = PhotoCollectionStore()
        #expect(store.urls.isEmpty)
    }

    // MARK: - setURLs

    @Test
    func setURLs_replacesContents() {
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2])
        #expect(store.urls == [url1, url2])
    }

    @Test
    func setURLs_calledAgain_fullyReplacesPreviousContents() {
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2])
        store.setURLs([url3])
        #expect(store.urls == [url3])
    }

    @Test
    func setURLs_preservesOrder() {
        let store = PhotoCollectionStore()
        store.setURLs([url3, url1, url2])
        #expect(store.urls == [url3, url1, url2])
    }

    @Test
    func setURLs_withEmptyArray_clearsContents() {
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2])
        store.setURLs([])
        #expect(store.urls.isEmpty)
    }

    // MARK: - remove

    @Test
    func remove_removesMatchingURL() {
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2, url3])
        store.remove(url: url2)
        #expect(store.urls == [url1, url3])
    }

    @Test
    func remove_preservesOrderOfRemainingURLs() {
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2, url3])
        store.remove(url: url1)
        #expect(store.urls == [url2, url3])
    }

    @Test
    func remove_lastRemainingURL_leavesEmptyList() {
        let store = PhotoCollectionStore()
        store.setURLs([url1])
        store.remove(url: url1)
        #expect(store.urls.isEmpty)
    }

    @Test
    func remove_nonExistentURL_isNoOp() {
        let store = PhotoCollectionStore()
        store.setURLs([url1, url2])
        store.remove(url: url3)
        #expect(store.urls == [url1, url2])
    }

    @Test
    func remove_fromEmptyStore_isNoOp() {
        let store = PhotoCollectionStore()
        store.remove(url: url1)
        #expect(store.urls.isEmpty)
    }
}
