import UIKit
import SwiftUI
import Localization

// MARK: - FileBrowserAdvancedSettingsViewController

/// 詳細設定画面を表すView Controller。設定メニューの「詳細設定」からpushで表示される。
/// FileBrowserAdvancedSettingsViewModelの生成をこの中にカプセル化し、呼び出し側（AppContainer）は
/// 現在値と各種変更クロージャのみを意識すればよい構造にする。
public final class FileBrowserAdvancedSettingsViewController: UIHostingController<FileBrowserAdvancedSettingsView> {

    public init(
        isRatingEnabled: Bool,
        pipAutoAdvanceIntervalSeconds: Int,
        onRatingEnabledChange: @escaping (Bool) -> Void,
        onPipAutoAdvanceIntervalSecondsChange: @escaping (Int) -> Void,
        onClearCacheRequested: @escaping () -> (isRatingEnabled: Bool, pipAutoAdvanceIntervalSeconds: Int)
    ) {
        let viewModel = FileBrowserAdvancedSettingsViewModel(
            isRatingEnabled: isRatingEnabled,
            pipAutoAdvanceIntervalSeconds: pipAutoAdvanceIntervalSeconds,
            onRatingEnabledChange: onRatingEnabledChange,
            onPipAutoAdvanceIntervalSecondsChange: onPipAutoAdvanceIntervalSecondsChange,
            onClearCacheRequested: onClearCacheRequested
        )
        super.init(rootView: FileBrowserAdvancedSettingsView(viewModel: viewModel))
        title = L10n.FileBrowser.advancedSettings
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
