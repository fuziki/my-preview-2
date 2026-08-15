import Foundation
import Observation

/// フォトビューアのページング表示が保持する「3枚ウィンドウ」（prev/current/next）の状態を表すViewModel。
/// current は常に中央ページ（page 1）に固定される。端では prevURL / nextURL が nil になり、
/// そのページは空白セルになる（越えスワイプはViewController側のスクロール範囲クランプで防ぐ）。
/// ページ数を常に3で固定することで、ボタン遷移で中央セルが作り直されず、ズーム倍率が常に維持される。
/// 同一ウィンドウが再設定された場合は変化なしとして扱う（distinct until changed）。
@Observable
public final class PhotoPageItemViewModel {

    public private(set) var prevURL: URL?
    public private(set) var currentURL: URL
    public private(set) var nextURL: URL?

    public init(prevURL: URL?, currentURL: URL, nextURL: URL?) {
        self.prevURL = prevURL
        self.currentURL = currentURL
        self.nextURL = nextURL
    }

    /// 新しいウィンドウを設定する。3枚すべてが現在と同一なら何も変えず false を返す（distinct until changed）。
    @discardableResult
    public func update(prevURL: URL?, currentURL: URL, nextURL: URL?) -> Bool {
        guard self.prevURL != prevURL || self.currentURL != currentURL || self.nextURL != nextURL else {
            return false
        }
        self.prevURL = prevURL
        self.currentURL = currentURL
        self.nextURL = nextURL
        return true
    }

    /// コレクションビューのページ数（常に3で固定。中央固定＝ズーム維持のため端でも3枚）。
    public static let pageCount = 3

    /// current が位置するページ番号（常に中央 = 1）。
    public var centerPage: Int { 1 }

    /// 各ページに表示するURL（page 0 = prev, 1 = current, 2 = next）。無い端は nil（空白ページ）。
    public func url(atPage page: Int) -> URL? {
        switch page {
        case 0: return prevURL
        case 1: return currentURL
        case 2: return nextURL
        default: return nil
        }
    }
}
