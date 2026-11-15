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
        didSet { onChange(ratingFilter, colorLabelFilter, savedFilter, captureDateFilter) }
    }

    var colorLabelFilter: Set<PhotoColorLabel> {
        didSet { onChange(ratingFilter, colorLabelFilter, savedFilter, captureDateFilter) }
    }

    var savedFilter: SavedFilter? {
        didSet { onChange(ratingFilter, colorLabelFilter, savedFilter, captureDateFilter) }
    }

    var captureDateFilter: CaptureDateFilter? {
        didSet { onChange(ratingFilter, colorLabelFilter, savedFilter, captureDateFilter) }
    }

    private let onChange: (RatingFilter?, Set<PhotoColorLabel>, SavedFilter?, CaptureDateFilter?) -> Void

    init(
        ratingFilter: RatingFilter?,
        colorLabelFilter: Set<PhotoColorLabel>,
        savedFilter: SavedFilter?,
        captureDateFilter: CaptureDateFilter?,
        onChange: @escaping (RatingFilter?, Set<PhotoColorLabel>, SavedFilter?, CaptureDateFilter?) -> Void
    ) {
        self.ratingFilter = ratingFilter
        self.colorLabelFilter = colorLabelFilter
        self.savedFilter = savedFilter
        self.captureDateFilter = captureDateFilter
        self.onChange = onChange
    }

    /// 撮影日時フィルタの開始日時（nilは下限なし）
    var captureDateStart: Date? { captureDateFilter?.start }

    /// 撮影日時フィルタの終了日時（nilは上限なし）
    var captureDateEnd: Date? { captureDateFilter?.end }

    /// 開始日時を設定する。開始・終了がどちらもnilになる場合はフィルタ自体を解除する
    func setCaptureDateStart(_ date: Date?) {
        updateCaptureDateFilter(start: date, end: captureDateEnd)
    }

    /// 終了日時を設定する。開始・終了がどちらもnilになる場合はフィルタ自体を解除する
    func setCaptureDateEnd(_ date: Date?) {
        updateCaptureDateFilter(start: captureDateStart, end: date)
    }

    private func updateCaptureDateFilter(start: Date?, end: Date?) {
        let newFilter = CaptureDateFilter(start: start, end: end)
        captureDateFilter = newFilter.isEmpty ? nil : newFilter
    }

    /// 星評価・カラーラベル・保存状態・撮影日時フィルタをすべてクリアする
    func clearFilters() {
        ratingFilter = nil
        colorLabelFilter = []
        savedFilter = nil
        captureDateFilter = nil
    }
}
