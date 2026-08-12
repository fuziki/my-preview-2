import UIKit
import SwiftUI
import Core

// MARK: - FileBrowserFilterViewController

/// フィルターのハーフモーダルを表すView Controller。
/// FileBrowserFilterViewModelの生成をこの中にカプセル化し、呼び出し側（AppContainer）は
/// ratingFilter・colorLabelFilter・onChangeの3引数のみを意識すればよい構造にする。
public final class FileBrowserFilterViewController: UIHostingController<FileBrowserFilterView> {

    public init(
        ratingFilter: RatingFilter?,
        colorLabelFilter: Set<PhotoColorLabel>,
        onChange: @escaping (RatingFilter?, Set<PhotoColorLabel>) -> Void
    ) {
        let viewModel = FileBrowserFilterViewModel(
            ratingFilter: ratingFilter,
            colorLabelFilter: colorLabelFilter,
            onChange: onChange
        )
        super.init(rootView: FileBrowserFilterView(viewModel: viewModel))
        // コンテンツ（SwiftUI）の理想サイズをpreferredContentSizeへ反映させ、
        // 呼び出し側（FileBrowserViewController）がハーフモーダルの高さをコンテンツに合わせられるようにする
        sizingOptions = [.preferredContentSize]
        // UIHostingControllerの既定の不透明背景を外す
        view.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
