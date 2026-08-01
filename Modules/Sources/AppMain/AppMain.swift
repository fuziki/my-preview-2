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

/// windowSceneのジオメトリ（向き・利用可能サイズ）が変化した際に呼ばれる。
/// `window.frame`を直接書き換えるのではなく、通常のレイアウトパスに再計算を促すだけにする
/// （WWDC26「Modernize your UIKit app」が案内する、`effectiveGeometry`/各VCの`view.bounds`に
/// 基づく設計に沿う。`window.frame`/`UIScreen`は非推奨とされている）。
/// SceneDelegateの`windowScene(_:didUpdateEffectiveGeometry:)`から呼び出す。
public func handleWindowSceneGeometryChange(_ windowScene: UIWindowScene) {
    windowScene.keyWindow?.rootViewController?.view.setNeedsLayout()
}
