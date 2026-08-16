import UIKit
import Core

/// ピンチズーム、アスペクトフィット拡縮、中央配置コンテンツインセットを管理するUIScrollViewサブクラス。
/// バウンズ変更時（例: デバイス回転）に自動でズームを再計算する。
public final class PhotoZoomScrollView: UIScrollView {

    // MARK: - プロパティ

    public private(set) var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleToFill
        return iv
    }()

    private var currentImage: UIImage?
    private var lastKnownBoundsSize: CGSize = .zero

    /// ズーム倍率が変化するたびに呼ばれる。zoomScaleを直接代入する箇所ではUIKitがdelegateを自動で呼ばないため、明示的に呼び出す。
    public var onZoomChange: ((CGFloat) -> Void)?

    // MARK: - 初期化

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupScrollView()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - セットアップ

    private func setupScrollView() {
        translatesAutoresizingMaskIntoConstraints = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        bouncesZoom = true
        delegate = self
        addSubview(imageView)
    }

    // MARK: - レイアウト

    override public func layoutSubviews() {
        super.layoutSubviews()
        let newSize = bounds.size
        if newSize != lastKnownBoundsSize, newSize.width > 0, newSize.height > 0 {
            // バウンズ変更（例: 回転）: フィットスケールを再計算する。
            lastKnownBoundsSize = newSize
            if let image = currentImage {
                resetZoom(for: image)
            }
        } else {
            centerImageView()
        }
    }

    // MARK: - 画像表示

    /// 表示画像を差し替え、フィットスケールへズームをリセットする。
    public func display(image: UIImage) {
        currentImage = image
        imageView.image = image
        resetZoom(for: image)
    }

    /// ズーム状態（zoomScale・contentOffset・contentSize・contentInset）を一切変えず、表示画像だけ差し替える。
    /// imageViewは既存フレーム（旧画像サイズ）のまま新画像をscaleToFillで流し込むため、
    /// 画像サイズが異なる場合はフィットに対する比率が変わり得る（呼び出し側が許容する前提）。
    public func swapImageKeepingZoom(_ image: UIImage) {
        currentImage = image
        imageView.image = image
    }

    // MARK: - ズーム

    public func resetZoom(for image: UIImage) {
        // imageView.frame を変更する前に zoomScale=1 にリセットする必要がある。
        // 非恒等変換が有効な状態で frame を設定するのは未定義動作（Apple ドキュメント参照）。
        minimumZoomScale = 1.0
        maximumZoomScale = 1.0
        zoomScale = 1.0
        contentInset = .zero

        imageView.frame = CGRect(origin: .zero, size: image.size)
        contentSize = image.size

        let scale = aspectFitScale(for: image)
        minimumZoomScale = scale
        maximumZoomScale = max(1.0, scale)
        zoomScale = scale

        centerImageView()
        onZoomChange?(zoomScale)
    }

    private func aspectFitScale(for image: UIImage) -> CGFloat {
        let size = bounds.size
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        return min(size.width / image.size.width, size.height / image.size.height)
    }

    private func centerImageView() {
        // 中央揃えには contentInset を使う — UIScrollViewにズーム変換が適用された状態で
        // imageView.frame を直接変更してはいけない（Apple ドキュメントで未定義動作とされている）。
        let boundsSize = bounds.size
        let contentSize = self.contentSize
        let offsetX = max((boundsSize.width - contentSize.width) / 2, 0)
        let offsetY = max((boundsSize.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

}

// MARK: - UIScrollViewDelegate

extension PhotoZoomScrollView: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
        onZoomChange?(zoomScale)
    }
}
