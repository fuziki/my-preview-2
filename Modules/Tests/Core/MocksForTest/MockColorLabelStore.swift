import Core
import Foundation

/// ColorLabelStoreProtocolのテスト用モック
public final class MockColorLabelStore: ColorLabelStoreProtocol {
    public var labels: [URL: PhotoColorLabel] = [:]
    public private(set) var removeAllCallCount = 0

    public init() {}

    public func label(for url: URL) -> PhotoColorLabel? {
        labels[url]
    }

    public func setLabel(_ label: PhotoColorLabel?, for url: URL) {
        labels[url] = label
    }

    public func allLabels() -> [URL: PhotoColorLabel] {
        labels
    }

    public func removeAll() {
        removeAllCallCount += 1
        labels.removeAll()
    }
}
