import SwiftUI
import Core
import Localization

// MARK: - FileBrowserAdvancedSettingsView

/// 設定メニューの「詳細設定」からpushで表示する詳細設定画面。
/// レーティング機能のオンオフ・PiP自動送り間隔・キャッシュ消去をひとつの画面にまとめる。
public struct FileBrowserAdvancedSettingsView: View {

    // FileBrowserAdvancedSettingsViewControllerから渡された値をこのViewが保持する。
    // 参照型（@Observable）なので@Stateで保持してもプロパティの変更はそのままonChange系クロージャへ伝播する。
    @State private var viewModel: FileBrowserAdvancedSettingsViewModel
    @State private var isShowingClearCacheConfirmation = false

    init(viewModel: FileBrowserAdvancedSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section {
                Toggle(L10n.FileBrowser.ratingFeature, isOn: $viewModel.isRatingEnabled)
            }

            Section {
                Stepper(
                    L10n.FileBrowser.pipAutoAdvanceIntervalValue(viewModel.pipAutoAdvanceIntervalSeconds),
                    value: $viewModel.pipAutoAdvanceIntervalSeconds,
                    in: FileBrowserAdvancedSettingsViewModel.pipAutoAdvanceIntervalSecondsRange
                )
            } header: {
                Text(L10n.FileBrowser.pipAutoAdvanceInterval)
            }

            Section {
                Button(L10n.FileBrowser.clearCache, role: .destructive) {
                    isShowingClearCacheConfirmation = true
                }
            }
        }
        .alert(
            L10n.FileBrowser.clearCache,
            isPresented: $isShowingClearCacheConfirmation
        ) {
            Button(L10n.Common.cancel, role: .cancel) {}
            Button(L10n.Common.clear, role: .destructive) {
                viewModel.clearCache()
            }
        } message: {
            Text(L10n.FileBrowser.clearCacheAlertMessage)
        }
    }
}
