import UIKit

/// アプリ全体で共有されるシングルトン状態。
/// AppContainerのライフタイムを管理し、アプリ起動から終了まで保持する。
final class AppState {
    static let shared = AppState()

    let container = AppContainer()
    /// インジゲーターウィンドウへの強参照（解放防止）
    var indicatorWindow: UIWindow?

    private init() {}
}
