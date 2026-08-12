import UIKit

// MARK: - UISheetPresentationController.Detent.Identifier + ContentFitting

public extension UISheetPresentationController.Detent.Identifier {
    /// `contentFittingSheetDetent(presentingViewWidth:)` が返すDetentの識別子。
    /// `sheet.largestUndimmedDetentIdentifier` に指定すると、シート表示中も裏のViewを操作できる
    /// （ダイミングビューが外れ、シート範囲外へのタッチが裏のViewへそのまま届くようになる）。
    static let contentFitting = UISheetPresentationController.Detent.Identifier("contentFitting")
}

// MARK: - UIViewController + ContentFittingSheetDetent

public extension UIViewController {

    /// このViewControllerをUISheetPresentationControllerで表示する際に、
    /// コンテンツの理想の高さにフィットするDetentを構成して返す。
    /// 呼び出し側は`present`を呼ぶ**前**にこのメソッドで取得したDetentを`sheet.detents`へ設定する。
    ///
    /// `present`前にレイアウトを確定して`preferredContentSize`へ反映しておくことで、
    /// 初回のdetent評価時に高さ0が返り、シートが左下から浮き出るように見える現象
    /// （iOS 26のシート遷移で顕在化する）を回避する。
    ///
    /// - Parameter presentingViewWidth: シートを表示する画面の幅（`presentingViewController.view.bounds.width`）
    func contentFittingSheetDetent(presentingViewWidth: CGFloat) -> UISheetPresentationController.Detent {
        loadViewIfNeeded()
        view.layoutIfNeeded()
        let fittingSize = view.systemLayoutSizeFitting(
            CGSize(width: presentingViewWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        preferredContentSize = CGSize(width: presentingViewWidth, height: fittingSize.height)
        return .custom(identifier: .contentFitting) { [weak self] _ in
            self?.preferredContentSize.height ?? fittingSize.height
        }
    }
}
