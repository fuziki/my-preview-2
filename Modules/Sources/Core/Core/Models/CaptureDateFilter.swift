import Foundation

// MARK: - CaptureDateFilter

/// 撮影日時による絞り込み条件（開始〜終了の範囲指定）
/// 開始・終了はどちらも任意で、両端を含む（以上・以下）。
public struct CaptureDateFilter: Codable, Equatable {
    /// 範囲の開始日時（nilは下限なし）
    public var start: Date?
    /// 範囲の終了日時（nilは上限なし）
    public var end: Date?

    public init(start: Date? = nil, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    /// 開始・終了のどちらも未設定（＝絞り込みなし）かどうか
    public var isEmpty: Bool {
        start == nil && end == nil
    }

    /// 指定の撮影日時がこのフィルタ条件に合致するかを返す。
    /// 撮影日時が無い写真は、範囲が設定されている間は合致しない。
    public func matches(captureDate: Date?) -> Bool {
        if isEmpty { return true }
        guard let captureDate else { return false }
        if let start, captureDate < start { return false }
        if let end, captureDate > end { return false }
        return true
    }
}
