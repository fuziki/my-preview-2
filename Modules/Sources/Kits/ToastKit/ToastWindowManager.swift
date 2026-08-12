import UIKit

@MainActor
final class ToastWindowManager {
    static let shared = ToastWindowManager()

    private var windowScene: UIWindowScene?
    private var toastWindow: ToastWindow?

    var isReady: Bool { windowScene != nil }

    func setup(windowScene: UIWindowScene) {
        self.windowScene = windowScene
    }

    func present(item: ToastItem, completion: @escaping () -> Void) {
        guard let scene = windowScene else { return }

        let window: ToastWindow
        if let existing = toastWindow {
            window = existing
        } else {
            let w = ToastWindow(windowScene: scene)
            toastWindow = w
            window = w
        }
        window.present(item: item) { [weak self] in
            self?.toastWindow = nil
            completion()
        }
    }
}
