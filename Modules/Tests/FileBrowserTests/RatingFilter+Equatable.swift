import Core

/// RatingFilterは本体側でEquatableに適合しないため、テストで`==`比較するために
/// このテストターゲットへ個別にリトロアクティブ適合させる。
extension RatingFilter: Equatable {
    public static func == (lhs: RatingFilter, rhs: RatingFilter) -> Bool {
        lhs.stars == rhs.stars && lhs.comparison == rhs.comparison
    }
}
