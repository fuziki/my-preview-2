import UIKit

protocol PhotoPageItemDelegate: AnyObject {
    func pageItemDidTap(_ vc: PhotoPageItemViewController)
    func pageItemDidDoubleTap(_ vc: PhotoPageItemViewController, at locationInImage: CGPoint)
}

/// UIPageViewControllerのスワイプナビゲーション内で使用される、1枚の写真を表示するページ。
/// PhotoZoomScrollViewを持ち、URLから非同期で画像を読み込む。
final class PhotoPageItemViewController: UIViewController {

    // MARK: - プロパティ

    var index: Int
    let url: URL
    private(set) var loadedImage: UIImage?

    weak var delegate: PhotoPageItemDelegate?

    let zoomScrollView = PhotoZoomScrollView()

    var isZoomed: Bool {
        zoomScrollView.zoomScale > zoomScrollView.minimumZoomScale + 0.001
    }

    // MARK: - 初期化

    init(index: Int, url: URL) {
        self.index = index
        self.url = url
        super.init(nibName: nil, bundle: nil)
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
        Task { await loadImage() }
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

    // MARK: - 画像表示

    /// 向きが一致する場合はズームレベルを維持したまま表示画像を差し替える。
    func display(image: UIImage, previousOrientation: ImageOrientation? = nil) {
        loadedImage = image
        zoomScrollView.display(image: image, previousOrientation: previousOrientation)
    }

    // MARK: - プライベート

    private func loadImage() async {
        let url = self.url
        let data = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value
        guard let data, let image = UIImage(data: data) else { return }
        display(image: image)
    }

    @objc private func handleSingleTap() {
        delegate?.pageItemDidTap(self)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.pageItemDidDoubleTap(self, at: gesture.location(in: zoomScrollView.imageView))
    }
}
