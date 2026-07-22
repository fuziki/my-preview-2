import Foundation

// MARK: - RatingFilter

/// レーティングによる絞り込み条件（星の数と比較方法の組み合わせ）
public struct RatingFilter: Codable {
    /// 比較方法
    public enum Comparison: CaseIterable, Codable {
        case atLeast   // 以上
        case atMost    // 以下
        case exactly   // 同値
    }

    /// 選択可能な星の数の範囲
    public static let starsRange = 0...5

    public var stars: Int
    public var comparison: Comparison

    public init(stars: Int, comparison: Comparison) {
        self.stars = stars
        self.comparison = comparison
    }

    /// 指定のレーティングがこのフィルタ条件に合致するかを返す
    public func matches(_ rating: Int) -> Bool {
        switch comparison {
        case .atLeast: return rating >= stars
        case .atMost: return rating <= stars
        case .exactly: return rating == stars
        }
    }
}
