import UIKit
import Core

protocol PhotoPageItemCellDelegate: AnyObject {
    func pageItemCellDidTap(_ cell: PhotoPageItemCell)
    func pageItemCellDidDoubleTap(_ cell: PhotoPageItemCell, at locationInImage: CGPoint)
    func pageItemCellDidChangeZoom(_ cell: PhotoPageItemCell)
}

/// UICollectionViewのスワイプナビゲーション内で使用される、1枚の写真を表示するセル。
/// PhotoZoomScrollViewを持ち、ImageLoaderServiceProtocol経由でURLから非同期で画像を読み込む。
final class PhotoPageItemCell: UICollectionViewCell {

    static let reuseIdentifier = "PhotoPageItemCell"

    // MARK: - プロパティ

    var index: Int = 0
    private(set) var loadedImage: UIImage?
    private var loadTask: Task<Void, Never>?

    weak var delegate: PhotoPageItemCellDelegate?

    let zoomScrollView = PhotoZoomScrollView()

    var isZoomed: Bool {
        zoomScrollView.zoomScale > zoomScrollView.minimumZoomScale + 0.001
    }

    // MARK: - 初期化

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .black
        setupScrollView()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - セットアップ

    private func setupScrollView() {
        contentView.addSubview(zoomScrollView)
        NSLayoutConstraint.activate([
            zoomScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            zoomScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            zoomScrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            zoomScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        zoomScrollView.onZoomChange = { [weak self] _ in
            guard let self else { return }
            delegate?.pageItemCellDidChangeZoom(self)
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

    // MARK: - 設定

    func configure(index: Int, url: URL, imageLoader: any ImageLoaderServiceProtocol) {
        self.index = index
        loadedImage = nil
        loadTask?.cancel()
        loadTask = Task { await self.loadImage(from: url, imageLoader: imageLoader) }
    }

    // MARK: - 画像表示

    /// 表示画像を差し替える（ズームはフィットへリセットされる）。
    func display(image: UIImage) {
        loadedImage = image
        zoomScrollView.display(image: image)
    }

    /// ズーム状態（倍率・パン位置）を維持したまま表示画像だけ差し替える（ボタン遷移での中央セル用）。
    /// 画像サイズが異なる場合、フィットに対する比率は変わり得る（呼び出し側が許容する前提）。
    func swapImageKeepingZoom(_ image: UIImage) {
        loadedImage = image
        zoomScrollView.swapImageKeepingZoom(image)
    }

    /// URLを非同期読み込みし、読み込み後にズーム状態を維持したまま画像だけ差し替える（ボタン遷移での中央セル用）。
    func reloadKeepingZoom(url: URL, imageLoader: any ImageLoaderServiceProtocol) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let image = await imageLoader.loadImage(from: url), !Task.isCancelled else { return }
            self?.swapImageKeepingZoom(image)
        }
    }

    /// 端の空白ページ（prev/next が存在しない）用に、読み込みを止めて画像を空にする。
    func showBlank() {
        loadTask?.cancel()
        loadTask = nil
        loadedImage = nil
        zoomScrollView.imageView.image = nil
    }

    // MARK: - 再利用

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        loadedImage = nil
        zoomScrollView.imageView.image = nil
    }

    // MARK: - プライベート

    private func loadImage(from url: URL, imageLoader: any ImageLoaderServiceProtocol) async {
        guard let image = await imageLoader.loadImage(from: url), !Task.isCancelled else { return }
        display(image: image)
    }

    @objc private func handleSingleTap() {
        delegate?.pageItemCellDidTap(self)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.pageItemCellDidDoubleTap(self, at: gesture.location(in: zoomScrollView.imageView))
    }
}
