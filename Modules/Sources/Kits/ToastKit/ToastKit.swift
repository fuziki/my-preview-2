import UIKit
import SwiftUI

@MainActor
public enum ToastKit {

    // MARK: Configuration

    struct Configuration {
        /// 1件あたりの表示時間（秒）。デフォルト 3.0
        var displayDuration: TimeInterval = 3.0
        /// 前の通知が消えてから次を表示するまでの間隔（秒）。デフォルト 0.4
        var interItemSpacing: TimeInterval = 0.4
    }

    static var configuration = Configuration()

    // MARK: Setup

    /// アプリ起動時に一度だけ呼ぶ。makeWindow(windowScene:) 内で呼ぶこと。
    public static func setup(windowScene: UIWindowScene) {
        ToastWindowManager.shared.setup(windowScene: windowScene)
    }

    // MARK: Show

    public static func show<Content: View>(
        duration: TimeInterval? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        assert(ToastWindowManager.shared.isReady, "ToastKit.show が呼ばれましたが setup(windowScene:) がまだ呼ばれていません")
        let item = ToastItem(
            duration: duration ?? configuration.displayDuration,
            viewBuilder: { AnyView(content()) }
        )
        ToastQueue.shared.enqueue(item)
    }
}
