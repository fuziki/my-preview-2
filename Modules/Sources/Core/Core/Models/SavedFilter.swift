import Foundation

// MARK: - SavedFilter

/// 保存状態による絞り込み条件
public enum SavedFilter: Codable, CaseIterable {
    case savedOnly
    case unsavedOnly

    /// 指定の保存日時（未保存の場合はnil）がこのフィルタ条件に合致するかを返す
    public func matches(savedDate: Date?) -> Bool {
        switch self {
        case .savedOnly: return savedDate != nil
        case .unsavedOnly: return savedDate == nil
        }
    }
}
