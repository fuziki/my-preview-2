import Foundation

/// 写真URLごとの最終保存日時を保持する。フォトビューアーセッション間で共有される。
public protocol SavedDateStoreProtocol {
    func date(for url: URL) -> Date?
    func setDate(_ date: Date, for url: URL)
}

public final class SavedDateStore: SavedDateStoreProtocol {
    private var dates: [URL: Date] = [:]

    public init() {}

    public func date(for url: URL) -> Date? {
        dates[url]
    }

    public func setDate(_ date: Date, for url: URL) {
        dates[url] = date
    }
}
