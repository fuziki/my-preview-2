import Core
import Foundation

/// ColorLabelStoreProtocolのテスト用モック
final class MockColorLabelStore: ColorLabelStoreProtocol {
    var labels: [URL: PhotoColorLabel] = [:]
    private(set) var removeAllCallCount = 0

    func label(for url: URL) -> PhotoColorLabel? {
        labels[url]
    }

    func setLabel(_ label: PhotoColorLabel?, for url: URL) {
        labels[url] = label
    }

    func allLabels() -> [URL: PhotoColorLabel] {
        labels
    }

    func removeAll() {
        removeAllCallCount += 1
        labels.removeAll()
    }
}
