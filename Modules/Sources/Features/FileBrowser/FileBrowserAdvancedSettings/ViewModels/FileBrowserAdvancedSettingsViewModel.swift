import Foundation
import Observation
import Core

// MARK: - FileBrowserAdvancedSettingsViewModel

/// 詳細設定画面専用ViewModel。
/// FileBrowserViewModelとは独立した状態を持ち、変更のたびにonChange系クロージャで呼び出し元へ通知する。
/// 呼び出し元（FileBrowserViewController）がクロージャ内でFileBrowserViewModelへ反映することで、
/// 裏のファイルリストへ変更が伝わる。
/// FileBrowserAdvancedSettingsViewController内でのみ生成されるため、モジュール外には公開しない。
@Observable
final class FileBrowserAdvancedSettingsViewModel {

    /// PiP自動送りの間隔（秒）の選択可能範囲
    static let pipAutoAdvanceIntervalSecondsRange = UserDefaultsSettings.pipAutoAdvanceIntervalSecondsRange

    var isRatingEnabled: Bool {
        didSet { onRatingEnabledChange(isRatingEnabled) }
    }

    var pipAutoAdvanceIntervalSeconds: Int {
        didSet { onPipAutoAdvanceIntervalSecondsChange(pipAutoAdvanceIntervalSeconds) }
    }

    private let onRatingEnabledChange: (Bool) -> Void
    private let onPipAutoAdvanceIntervalSecondsChange: (Int) -> Void
    private let onClearCacheRequested: () -> (isRatingEnabled: Bool, pipAutoAdvanceIntervalSeconds: Int)

    init(
        isRatingEnabled: Bool,
        pipAutoAdvanceIntervalSeconds: Int,
        onRatingEnabledChange: @escaping (Bool) -> Void,
        onPipAutoAdvanceIntervalSecondsChange: @escaping (Int) -> Void,
        onClearCacheRequested: @escaping () -> (isRatingEnabled: Bool, pipAutoAdvanceIntervalSeconds: Int)
    ) {
        self.isRatingEnabled = isRatingEnabled
        self.pipAutoAdvanceIntervalSeconds = pipAutoAdvanceIntervalSeconds
        self.onRatingEnabledChange = onRatingEnabledChange
        self.onPipAutoAdvanceIntervalSecondsChange = onPipAutoAdvanceIntervalSecondsChange
        self.onClearCacheRequested = onClearCacheRequested
    }

    /// キャッシュを消去し、リセット後の値をこのViewModelへも反映する
    func clearCache() {
        let defaults = onClearCacheRequested()
        isRatingEnabled = defaults.isRatingEnabled
        pipAutoAdvanceIntervalSeconds = defaults.pipAutoAdvanceIntervalSeconds
    }
}
