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
        didSet { onChange(ratingFilter, colorLabelFilter, savedFilter) }
    }

    var colorLabelFilter: Set<PhotoColorLabel> {
        didSet { onChange(ratingFilter, colorLabelFilter, savedFilter) }
    }

    var savedFilter: SavedFilter? {
        didSet { onChange(ratingFilter, colorLabelFilter, savedFilter) }
    }

    private let onChange: (RatingFilter?, Set<PhotoColorLabel>, SavedFilter?) -> Void

    init(
        ratingFilter: RatingFilter?,
        colorLabelFilter: Set<PhotoColorLabel>,
        savedFilter: SavedFilter?,
        onChange: @escaping (RatingFilter?, Set<PhotoColorLabel>, SavedFilter?) -> Void
    ) {
        self.ratingFilter = ratingFilter
        self.colorLabelFilter = colorLabelFilter
        self.savedFilter = savedFilter
        self.onChange = onChange
    }

    /// 星評価・カラーラベル・保存状態フィルタをすべてクリアする
    func clearFilters() {
        ratingFilter = nil
        colorLabelFilter = []
        savedFilter = nil
    }
}
