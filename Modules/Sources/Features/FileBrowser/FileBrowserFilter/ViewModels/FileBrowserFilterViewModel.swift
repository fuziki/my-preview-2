import Foundation
import Observation
import Core

// MARK: - FileBrowserFilterViewModel

/// フィルターのハーフモーダル専用ViewModel。
/// FileBrowserViewModelとは独立した状態を持ち、変更のたびにonChangeで呼び出し元へ通知する。
/// 呼び出し元（FileBrowserViewController）がonChange内でFileBrowserViewModelへ反映することで、
/// 裏のファイルリストがリアルタイムに更新される。
/// FileBrowserFilterViewController内でのみ生成されるため、モジュール外には公開しない。
@Observable
final class FileBrowserFilterViewModel {

    var ratingFilter: RatingFilter? {
        didSet { onChange(ratingFilter, colorLabelFilter) }
    }

    var colorLabelFilter: Set<PhotoColorLabel> {
        didSet { onChange(ratingFilter, colorLabelFilter) }
    }

    private let onChange: (RatingFilter?, Set<PhotoColorLabel>) -> Void

    init(
        ratingFilter: RatingFilter?,
        colorLabelFilter: Set<PhotoColorLabel>,
        onChange: @escaping (RatingFilter?, Set<PhotoColorLabel>) -> Void
    ) {
        self.ratingFilter = ratingFilter
        self.colorLabelFilter = colorLabelFilter
        self.onChange = onChange
    }

    /// 星評価・カラーラベルフィルタを両方クリアする
    func clearFilters() {
        ratingFilter = nil
        colorLabelFilter = []
    }
}
