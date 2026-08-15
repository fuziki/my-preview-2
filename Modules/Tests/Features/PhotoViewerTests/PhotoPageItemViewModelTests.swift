import Testing
import Foundation
@testable import PhotoViewer

// MARK: - テスト
// PhotoPageItemViewModel の 3枚ウィンドウ（prev/current/next）と distinct until changed を検証する。

struct PhotoPageItemViewModelTests {

    let url1 = URL(fileURLWithPath: "/tmp/photo1.jpg")
    let url2 = URL(fileURLWithPath: "/tmp/photo2.jpg")
    let url3 = URL(fileURLWithPath: "/tmp/photo3.jpg")

    @Test
    func url_atPage_mapsPrevCurrentNext() {
        let vm = PhotoPageItemViewModel(prevURL: url1, currentURL: url2, nextURL: url3)
        #expect(vm.url(atPage: 0) == url1)
        #expect(vm.url(atPage: 1) == url2)
        #expect(vm.url(atPage: 2) == url3)
    }

    @Test
    func url_atEdge_returnsNilForMissingNeighbor() {
        let vm = PhotoPageItemViewModel(prevURL: nil, currentURL: url1, nextURL: url2)
        #expect(vm.url(atPage: 0) == nil)
        #expect(vm.url(atPage: 1) == url1)
        #expect(vm.url(atPage: 2) == url2)
    }

    @Test
    func centerPage_isAlwaysOne() {
        let vm = PhotoPageItemViewModel(prevURL: nil, currentURL: url1, nextURL: nil)
        #expect(vm.centerPage == 1)
    }

    @Test
    func update_withSameWindow_returnsFalse() {
        let vm = PhotoPageItemViewModel(prevURL: url1, currentURL: url2, nextURL: url3)
        let changed = vm.update(prevURL: url1, currentURL: url2, nextURL: url3)
        #expect(changed == false)
    }

    @Test
    func update_withChangedWindow_returnsTrueAndUpdates() {
        let vm = PhotoPageItemViewModel(prevURL: url1, currentURL: url2, nextURL: url3)
        let changed = vm.update(prevURL: url2, currentURL: url3, nextURL: nil)
        #expect(changed == true)
        #expect(vm.prevURL == url2)
        #expect(vm.currentURL == url3)
        #expect(vm.nextURL == nil)
    }

    @Test
    func update_onlyNextChanged_returnsTrue() {
        let vm = PhotoPageItemViewModel(prevURL: url1, currentURL: url2, nextURL: nil)
        let changed = vm.update(prevURL: url1, currentURL: url2, nextURL: url3)
        #expect(changed == true)
        #expect(vm.nextURL == url3)
    }
}
