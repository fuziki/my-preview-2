import UIKit
import Core

protocol PhotoPageContentViewControllerDelegate: AnyObject {
    func pageContentDidTap(_ vc: PhotoPageContentViewController)
    func pageContentDidDoubleTap(_ vc: PhotoPageContentViewController, at locationInImage: CGPoint)
    func pageContentDidChangeZoom(_ vc: PhotoPageContentViewController)
}

/// UIPageViewController の各ページとして使う、1枚の写真を表示するViewController。
/// PhotoZoomScrollView を持ち、ImageLoaderServiceProtocol 経由でURLから非同期に画像を読み込む。
/// ボタン遷移では `updatePhoto(url:index:keepZoom:)` でズーム状態を維持したまま画像だけ差し替える。
final class PhotoPageContentViewController: UIViewController {

    // MARK: - プロパティ

    private(set) var index: Int
    private(set) var loadedImage: UIImage?
    private var loadTask: Task<Void, Never>?

    weak var delegate: PhotoPageContentViewControllerDelegate?

    let zoomScrollView = PhotoZoomScrollView()

    var isZoomed: Bool {
        zoomScrollView.zoomScale > zoomScrollView.minimumZoomScale + 0.001
    }

    private let imageLoader: any ImageLoaderServiceProtocol

    // MARK: - 初期化

    init(index: Int, url: URL, imageLoader: any ImageLoaderServiceProtocol) {
        self.index = index
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
        load(url: url, keepZoom: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScrollView()
        setupGestures()
        // init 時に読み込んだ画像がすでにあれば表示へ反映する
        if let image = loadedImage {
            zoomScrollView.display(image: image)
        }
    }

    // MARK: - セットアップ

    private func setupScrollView() {
        view.addSubview(zoomScrollView)
        NSLayoutConstraint.activate([
            zoomScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            zoomScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            zoomScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            zoomScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        zoomScrollView.onZoomChange = { [weak self] _ in
            guard let self else { return }
            delegate?.pageContentDidChangeZoom(self)
        }
    }

    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)

        zoomScrollView.addGestureRecognizer(singleTap)
        zoomScrollView.addGestureRecognizer(doubleTap)
    }

    // MARK: - 画像更新

    /// ボタン遷移などで、ズーム状態を維持したまま別の写真へ差し替える。
    /// 読み込み完了までは旧画像を維持し、完了後に `swapImageKeepingZoom` で差し替えるため暗転しない。
    func updatePhoto(url: URL, index: Int, keepZoom: Bool) {
        self.index = index
        load(url: url, keepZoom: keepZoom)
    }

    // MARK: - プライベート

    private func load(url: URL, keepZoom: Bool) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let image = await self?.imageLoader.loadImage(from: url), !Task.isCancelled, let self else { return }
            loadedImage = image
            // まだ view が読み込まれていない場合は viewDidLoad が loadedImage を表示する
            guard isViewLoaded else { return }
            if keepZoom {
                zoomScrollView.swapImageKeepingZoom(image)
            } else {
                zoomScrollView.display(image: image)
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }

    @objc private func handleSingleTap() {
        delegate?.pageContentDidTap(self)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.pageContentDidDoubleTap(self, at: gesture.location(in: zoomScrollView.imageView))
    }
}
