import UIKit
import FileBrowser
import ToastKit

/// アプリのウィンドウを生成して返す。SceneDelegateから呼び出す。
/// AppState.shared.container からFileBrowserViewControllerを生成してナビゲーション階層を構築する。
/// 同じwindowSceneにファイル読み込みインジゲーターウィンドウも作成する。
public func makeWindow(windowScene: UIWindowScene) -> UIWindow {
    let container = AppState.shared.container

    AppState.shared.indicatorWindow = LoadingIndicatorWindow(
        windowScene: windowScene,
        tracker: container.tracker
    )
    ToastKit.setup(windowScene: windowScene)

    let fileBrowserVC = container.makeFileBrowserViewController()
    let navController = UINavigationController(rootViewController: fileBrowserVC)
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = navController
    window.makeKeyAndVisible()
    return window
}
