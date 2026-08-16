import UIKit
import Core

/// フォトビューアの写真ページングを担う子ViewController。
/// 内部に `UIPageViewController`（`.scroll`）を持ち、各ページを `PhotoPageContentViewController` で表示する。
///
/// - スワイプ: `UIPageViewController` の `dataSource` が端で `nil` を返すため、越えスワイプは自然に防がれる
///   （クランプや空白ページの特殊処理は不要）。移動完了は `didFinishAnimating` で検知し `onPageChanged` で通知する。
/// - ボタン等（プログラム遷移）: `moveToIndex(_:)` で現在ページのVCを作り直さず、ズーム状態を維持したまま
///   画像だけ差し替える。既に同じインデックスなら何もしない（冪等）。
public final class PhotoPageItemViewController: UIViewController {

    // MARK: - コールバック

    /// スワイプで別ページへ移動完了した時に呼ばれる（新しいインデックスと表示中画像を通知）。
    public var onPageChanged: ((Int, UIImage?) -> Void)?
    /// 写真がシングルタップされた時に呼ばれる（オーバーレイ表示切替などに使う）。
    public var onTap: (() -> Void)?
    /// 写真がダブルタップされた時に呼ばれる（引数はタップ位置＝画像座標）。
    public var onDoubleTap: ((CGPoint) -> Void)?
    /// 現在ページのズーム倍率が変化した時に呼ばれる。
    public var onZoomChanged: (() -> Void)?

    // MARK: - 依存

    private let allURLs: [URL]
    private let imageLoader: any ImageLoaderServiceProtocol
    /// 初期表示ページ。実際のページ設定は viewDidLoad で行う。
    private let initialIndex: Int

    // MARK: - UIPageViewController

    private let pageViewController = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal,
        options: [.interPageSpacing: 16]
    )

    // MARK: - 初期化

    public init(allURLs: [URL], initialIndex: Int, imageLoader: any ImageLoaderServiceProtocol) {
        self.allURLs = allURLs
        self.initialIndex = initialIndex
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ライフサイクル

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        addChild(pageViewController)
        pageViewController.view.frame = view.bounds
        pageViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)

        pageViewController.dataSource = self
        pageViewController.delegate = self

        let clamped = min(max(initialIndex, 0), max(0, allURLs.count - 1))
        pageViewController.setViewControllers(
            [makeContentViewController(index: clamped)],
            direction: .forward,
            animated: false
        )
    }

    // MARK: - 現在ページ

    /// 現在表示中のページVC。親がズーム状態の問い合わせやドラッグズーム操作に使う。
    var currentContentViewController: PhotoPageContentViewController? {
        pageViewController.viewControllers?.first as? PhotoPageContentViewController
    }

    // MARK: - プログラム遷移（ボタン・PiP・フィルタ自動遷移）

    /// 指定インデックスへプログラム遷移する。現在ページのVCを作り直さず、ズーム維持で画像だけ差し替える。
    /// 既に同じインデックスを表示している場合は何もしない（スワイプ後の同期呼び出しは冪等に無視される）。
    public func moveToIndex(_ index: Int) {
        guard allURLs.indices.contains(index),
              let current = currentContentViewController,
              index != current.index else { return }
        current.updatePhoto(url: allURLs[index], index: index, keepZoom: true)
        // dataSource を差し直して、UIPageViewController がキャッシュした隣接ページを破棄・再問い合わせさせる。
        // 現在ページのVC自体は入れ替えないため、ズーム状態は保持される。
        pageViewController.dataSource = nil
        pageViewController.dataSource = self
    }

    // MARK: - プライベート

    private func makeContentViewController(index: Int) -> PhotoPageContentViewController {
        let vc = PhotoPageContentViewController(index: index, url: allURLs[index], imageLoader: imageLoader)
        vc.delegate = self
        return vc
    }
}

// MARK: - UIPageViewControllerDataSource

extension PhotoPageItemViewController: UIPageViewControllerDataSource {
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let content = viewController as? PhotoPageContentViewController, content.index > 0 else { return nil }
        return makeContentViewController(index: content.index - 1)
    }

    public func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let content = viewController as? PhotoPageContentViewController,
              content.index < allURLs.count - 1 else { return nil }
        return makeContentViewController(index: content.index + 1)
    }
}

// MARK: - UIPageViewControllerDelegate

extension PhotoPageItemViewController: UIPageViewControllerDelegate {
    public func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed, let current = currentContentViewController else { return }
        onPageChanged?(current.index, current.loadedImage)
    }
}

// MARK: - PhotoPageContentViewControllerDelegate

extension PhotoPageItemViewController: PhotoPageContentViewControllerDelegate {
    func pageContentDidTap(_ vc: PhotoPageContentViewController) {
        onTap?()
    }

    func pageContentDidDoubleTap(_ vc: PhotoPageContentViewController, at locationInImage: CGPoint) {
        onDoubleTap?(locationInImage)
    }

    func pageContentDidChangeZoom(_ vc: PhotoPageContentViewController) {
        guard vc === currentContentViewController else { return }
        onZoomChanged?()
    }
}
