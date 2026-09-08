import UIKit
import SwiftUI
import Core

// MARK: - FileBrowserBulkSaveViewController

/// 「全て保存」の進捗オーバーレイを表すView Controller。
/// FileBrowserBulkSaveViewModelの生成をこの中にカプセル化し、呼び出し側（AppContainer）は
/// urls・dependencies・onURLSavedのみを意識すればよい構造にする。
/// フルスクリーンモーダル（.overFullScreen）で表示される想定で、呼び出し側
/// （FileBrowserViewController）が isModalInPresentation = true を設定し、中断ボタン以外での
/// 操作・破棄を防ぐ。
public final class FileBrowserBulkSaveViewController: UIHostingController<FileBrowserBulkSaveView> {

    public init(
        urls: [URL],
        dependencies: FileBrowserBulkSaveDependencies,
        onURLSaved: @escaping (URL, Date) -> Void
    ) {
        let viewModel = FileBrowserBulkSaveViewModel(urls: urls, dependencies: dependencies, onURLSaved: onURLSaved)
        super.init(rootView: FileBrowserBulkSaveView(viewModel: viewModel))
        // 完了・中断・失敗のいずれかでこの画面自身を閉じる
        viewModel.onFinished = { [weak self] in
            self?.dismiss(animated: true)
        }
        // UIHostingControllerの既定の不透明背景を外し、裏のファイルブラウザが透けて見えるようにする
        view.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
