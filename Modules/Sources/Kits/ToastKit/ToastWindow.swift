import UIKit

final class ToastWindow: UIWindow {

    private var currentVC: ToastHostingController?

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        windowLevel = .alert + 1
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        windowLevel = .alert + 1
        backgroundColor = .clear
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        // ルートVCのビュー背面はタッチを透過させる
        if hit == rootViewController?.view { return nil }
        return hit
    }

    func present(item: ToastItem, completion: @escaping () -> Void) {
        isHidden = false
        let vc = ToastHostingController(item: item) { [weak self] in
            self?.isHidden = true
            self?.currentVC = nil
            completion()
        }
        currentVC = vc
        rootViewController = vc
        makeKeyAndVisible()
    }
}
