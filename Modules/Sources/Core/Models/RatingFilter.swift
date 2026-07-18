import Foundation

// MARK: - RatingFilter

/// レーティングによる絞り込み条件（星の数と比較方法の組み合わせ）
public struct RatingFilter: Hashable, Sendable {
    /// 比較方法
    public enum Comparison: String, CaseIterable, Sendable {
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

// MARK: - UserDefaults永続化用の文字列表現

extension RatingFilter: RawRepresentable {
    /// "atLeast:3" 形式の文字列表現
    public var rawValue: String { "\(comparison.rawValue):\(stars)" }

    public init?(rawValue: String) {
        let parts = rawValue.split(separator: ":")
        guard parts.count == 2,
              let comparison = Comparison(rawValue: String(parts[0])),
              let stars = Int(parts[1]),
              Self.starsRange.contains(stars) else { return nil }
        self.init(stars: stars, comparison: comparison)
    }
}
