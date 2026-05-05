import Foundation

/// 写真URLごとの最終保存日時を保持する。フォトビューアーセッション間で共有される。
protocol SavedDateStoreProtocol: AnyObject {
    func date(for url: URL) -> Date?
    func setDate(_ date: Date, for url: URL)
}

final class SavedDateStore: SavedDateStoreProtocol {
    private var dates: [URL: Date] = [:]

    func date(for url: URL) -> Date? {
        dates[url]
    }

    func setDate(_ date: Date, for url: URL) {
        dates[url] = date
    }
}
