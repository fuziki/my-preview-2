import UIKit
import SwiftUI

// MARK: - ToastHostingController

final class ToastHostingController: UIViewController, UIGestureRecognizerDelegate {

    private let item: ToastItem
    private let dismissCallback: () -> Void

    private enum State { case appearing, visible, dismissing }
    private var state: State = .appearing

    private var dismissTask: Task<Void, Never>?
    private var dragStartY: CGFloat = 0
    private var isTouching = false
    private var isDragging = false

    // フレームベースレイアウトなので translatesAutoresizingMaskIntoConstraints = true
    private var hostingView: UIView!

    private let horizontalPadding: CGFloat = 16
    private let maxWidth: CGFloat = 400
    private let topSpacing: CGFloat = 8

    init(item: ToastItem, dismissCallback: @escaping () -> Void) {
        self.item = item
        self.dismissCallback = dismissCallback
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupHostingView()
        setupGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    // MARK: - Setup

    private func setupHostingView() {
        let toastView = ToastContentView(content: item.viewBuilder())
        let hosting = UIHostingController(rootView: toastView)
        hosting.view.backgroundColor = .clear
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
        // フレームで手動配置するため translatesAutoresizingMaskIntoConstraints を true にする
        hosting.view.translatesAutoresizingMaskIntoConstraints = true
        hostingView = hosting.view
    }

    private func setupGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.cancelsTouchesInView = false
        pan.delegate = self
        hostingView.addGestureRecognizer(pan)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0
        longPress.cancelsTouchesInView = false
        longPress.delegate = self
        hostingView.addGestureRecognizer(longPress)
    }

    // MARK: - UIGestureRecognizerDelegate

    // ロングプレス（タッチ保持検出）とパン（ドラッグ）を同時に認識させる
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    // MARK: - Layout

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // ドラッグ中は位置をリセットしない
        guard !isDragging else { return }
        layoutToastView()
    }

    private func layoutToastView() {
        guard let hostingView else { return }

        let statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        let availableWidth = min(view.bounds.width - horizontalPadding * 2, maxWidth)

        let fittingSize = hostingView.systemLayoutSizeFitting(
            CGSize(width: availableWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .fittingSizeLevel
        )
        let toastWidth  = min(fittingSize.width, availableWidth)
        let toastHeight = fittingSize.height
        let toastX      = (view.bounds.width - toastWidth) / 2
        let toastY      = statusBarHeight + topSpacing

        hostingView.frame = CGRect(x: toastX, y: toastY, width: toastWidth, height: toastHeight)
    }

    // MARK: - Animation

    private func animateIn() {
        guard state == .appearing else { return }
        layoutToastView()

        let targetY = hostingView.frame.origin.y
        let startY  = targetY - hostingView.frame.height - 20
        hostingView.frame.origin.y = startY
        hostingView.alpha = 0

        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            self.hostingView.frame.origin.y = targetY
            self.hostingView.alpha = 1
        } completion: { _ in
            self.state = .visible
            self.scheduleDismiss()
        }
    }

    private func animateOut(velocity: CGFloat = 0, completion: @escaping () -> Void) {
        guard state != .dismissing else { return }
        state = .dismissing
        cancelDismissTimer()

        let statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        let targetY = hostingView.frame.origin.y - hostingView.frame.height - statusBarHeight - 40
        let springVel = abs(velocity) / max(abs(targetY - hostingView.frame.origin.y), 1)

        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: springVel,
            options: .curveEaseIn
        ) {
            self.hostingView.frame.origin.y = targetY
            self.hostingView.alpha = 0
        } completion: { _ in
            completion()
            self.dismissCallback()
        }
    }

    // MARK: - Timer

    private func scheduleDismiss() {
        cancelDismissTimer()
        dismissTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(item.duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            while self.isTouching {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard !Task.isCancelled else { return }
            }
            await MainActor.run { self.animateOut {} }
        }
    }

    private func cancelDismissTimer() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    // MARK: - Gesture handlers

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            isTouching = true
            cancelDismissTimer()
        case .ended, .cancelled, .failed:
            isTouching = false
            if state == .visible { scheduleDismiss() }
        default:
            break
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: view)
        let velocity    = recognizer.velocity(in: view)

        switch recognizer.state {
        case .began:
            isDragging = true
            isTouching = true
            cancelDismissTimer()
            dragStartY = hostingView.frame.origin.y

        case .changed:
            let rawDelta = translation.y
            // 上方向は素直に追従、下方向はバネ感を持たせる
            let delta = rawDelta < 0 ? rawDelta : rawDelta * 0.3
            hostingView.frame.origin.y = dragStartY + delta

        case .ended, .cancelled:
            isDragging = false
            isTouching = false
            let isFlickUp   = velocity.y < -200
            let isDraggedUp = hostingView.frame.origin.y < dragStartY - 30

            if isFlickUp || isDraggedUp {
                animateOut(velocity: velocity.y) {}
            } else {
                UIView.animate(
                    withDuration: 0.4,
                    delay: 0,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 0.3,
                    options: .curveEaseOut
                ) {
                    self.hostingView.frame.origin.y = self.dragStartY
                }
                if state == .visible { scheduleDismiss() }
            }

        default:
            break
        }
    }
}

// MARK: - ToastContentView

private struct ToastContentView<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .foregroundStyle(.primary)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(Color.white.opacity(0.4), in: Capsule())
            .background {
                Capsule()
                    .glassEffect(.regular, in: .capsule)
            }
            .contentShape(Capsule())
            .fixedSize()
    }
}
