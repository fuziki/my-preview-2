import Core

/// FileItemは本体側でEquatableに適合しないため、テストで`==`比較するために
/// このテストターゲットへ個別にリトロアクティブ適合させる。
extension FileItem: Equatable {
    // idは生成のたびに異なるため、同一ファイルの判定にはurlのみを比較する
    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }
}
