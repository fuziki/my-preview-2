import UIKit
import Core

protocol PhotoPageItemCellDelegate: AnyObject {
    func pageItemCellDidTap(_ cell: PhotoPageItemCell)
    func pageItemCellDidDoubleTap(_ cell: PhotoPageItemCell, at locationInImage: CGPoint)
    func pageItemCellDidChangeZoom(_ cell: PhotoPageItemCell)
}

/// UICollectionView（diffable）の1ページ分の写真セル。安定した識別子（UUID）に紐づく。
/// PhotoZoomScrollView を持ち、URLから非同期に画像を読み込む。
/// - `configure(url:imageLoader:)`: 画像を読み込みフィットへリセットして表示する（新規・reconfigure用）。
/// - `updateKeepingZoomIfSameAspect(url:imageLoader:)`: 読み込み後、縦横比が同じならズーム維持で画像だけ差し替える（違えばリセット。ボタン/PiP遷移の表示セル用）。
final class PhotoPageItemCell: UICollectionViewCell {

    // MARK: - プロパティ

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

    // MARK: - 画像

    /// 画像を読み込み、フィットへリセットして表示する（新規・reconfigure 用）。
    func configure(url: URL, imageLoader: any ImageLoaderServiceProtocol) {
        loadedImage = nil
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let image = await imageLoader.loadImage(from: url), !Task.isCancelled, let self else { return }
            loadedImage = image
            zoomScrollView.display(image: image)
        }
    }

    /// 読み込み後、新旧画像の縦横比が同じならズーム状態を維持したまま画像だけ差し替える（ボタン/PiP遷移の表示セル用）。
    /// 縦横比が変わる場合（横長→縦長など）は swapImageKeepingZoom だと潰れて表示されるため、フィットへリセットする。
    /// 読み込み完了までは旧画像を維持するため暗転しない。
    func updateKeepingZoomIfSameAspect(url: URL, imageLoader: any ImageLoaderServiceProtocol) {
        let oldImage = loadedImage
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let image = await imageLoader.loadImage(from: url), !Task.isCancelled, let self else { return }
            loadedImage = image
            if let oldImage, Self.sameAspect(oldImage, image) {
                zoomScrollView.swapImageKeepingZoom(image)
            } else {
                zoomScrollView.display(image: image)
            }
        }
    }

    /// 現在読み込み済みの画像をフィット（最小ズーム）へリセット表示する（スワイプ移動時のズームリセット用）。
    func resetZoomToFit() {
        guard let image = loadedImage else { return }
        zoomScrollView.display(image: image)
    }

    /// 2枚の画像の縦横比が（誤差の範囲で）等しいか。
    private static func sameAspect(_ a: UIImage, _ b: UIImage) -> Bool {
        guard a.size.height > 0, b.size.height > 0 else { return false }
        return abs(a.size.width / a.size.height - b.size.width / b.size.height) < 0.01
    }

    // MARK: - 再利用

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        loadTask = nil
        loadedImage = nil
        zoomScrollView.imageView.image = nil
    }

    // MARK: - ジェスチャー

    @objc private func handleSingleTap() {
        delegate?.pageItemCellDidTap(self)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.pageItemCellDidDoubleTap(self, at: gesture.location(in: zoomScrollView.imageView))
    }
}
