import UIKit
import FileBrowser

/// アプリのウィンドウを生成して返す。SceneDelegateから呼び出す。
/// AppState.shared.container からFileBrowserViewControllerを生成してナビゲーション階層を構築する。
public func makeWindow(windowScene: UIWindowScene) -> UIWindow {
    let fileBrowserVC = AppState.shared.container.makeFileBrowserViewController()
    let navController = UINavigationController(rootViewController: fileBrowserVC)
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = navController
    window.makeKeyAndVisible()
    return window
}
