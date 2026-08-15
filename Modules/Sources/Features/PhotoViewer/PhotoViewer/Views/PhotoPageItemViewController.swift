import UIKit
import Core

/// スワイプで隣ページへ移動した方向。
public enum PhotoPageDirection {
    case previous
    case next
}

/// フォトビューアの写真ページング（prev/current/next の3枚ウィンドウ）を担う子ViewController。
/// 内部に横スクロール・ページングの UICollectionView を持ち、PhotoPageItemCell を表示する。
///
/// 中央固定方式: ページ数は常に3で固定し、current を常に中央（page 1）に置く。端では prev/next の
/// ページが空白になり、その方向へはスクロール範囲をクランプして越えられないようにする。
/// ページ数が変わらないため、ボタン遷移でも中央セルが作り直されず、ズーム倍率が常に維持される。
///
/// - スワイプ: 隣へスクロール完了 → `onPageChanged(方向)` を通知。親が新ウィンドウを `applyWindow(.swiped)` で供給し直す。
/// - ボタン等: 親が `applyWindow(.button)` を呼ぶ。中央セルはズーム維持で画像だけ差し替え、両隣は読み直す。
public final class PhotoPageItemViewController: UIViewController {

    // MARK: - コールバック

    /// スワイプで隣ページへ移動した時に呼ばれる（移動方向と移動先セルの読み込み済み画像を通知）。
    /// 親が新しいウィンドウを供給し直す。画像はオーバーレイ/PiP用の currentImage に使う。
    public var onPageChanged: ((PhotoPageDirection, UIImage?) -> Void)?
    /// 写真がシングルタップされた時に呼ばれる（オーバーレイ表示切替などに使う）。
    public var onTap: (() -> Void)?
    /// 写真がダブルタップされた時に呼ばれる（引数はタップ位置＝画像座標）。
    public var onDoubleTap: ((CGPoint) -> Void)?
    /// 中央（current）セルのズーム倍率が変化した時に呼ばれる。
    public var onZoomChanged: (() -> Void)?

    // MARK: - 依存

    private let viewModel: PhotoPageItemViewModel
    private let imageLoader: any ImageLoaderServiceProtocol

    // MARK: - コレクションビュー

    private let interPageSpacing: CGFloat = 16

    private lazy var pageLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = interPageSpacing
        layout.minimumInteritemSpacing = 0
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: pageLayout)
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        cv.backgroundColor = .black
        cv.clipsToBounds = false
        cv.dataSource = self
        cv.delegate = self
        cv.register(PhotoPageItemCell.self, forCellWithReuseIdentifier: PhotoPageItemCell.reuseIdentifier)
        return cv
    }()

    // MARK: - 初期化

    public init(viewModel: PhotoPageItemViewModel, imageLoader: any ImageLoaderServiceProtocol) {
        self.viewModel = viewModel
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
        view.addSubview(collectionView)
        preloadNeighborImages()
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateCollectionViewFrame()
    }

    // MARK: - レイアウト

    /// 1ページ分のスクロール量（コレクションビュー幅 = 画面幅 + ページ間隔）。
    private var pageStride: CGFloat { collectionView.bounds.width }

    /// コレクションビューのフレームとレイアウトをビューのサイズに合わせて更新する。
    /// ページ間隔（interPageSpacing）を維持するため、コレクションビューを左右にはみ出させる。
    private func updateCollectionViewFrame() {
        let spacing = interPageSpacing
        let targetFrame = CGRect(
            x: -spacing / 2,
            y: 0,
            width: view.bounds.width + spacing,
            height: view.bounds.height
        )
        guard targetFrame != collectionView.frame else { return }
        collectionView.frame = targetFrame
        pageLayout.itemSize = CGSize(width: view.bounds.width, height: view.bounds.height)
        pageLayout.sectionInset = UIEdgeInsets(top: 0, left: spacing / 2, bottom: 0, right: spacing / 2)
        pageLayout.invalidateLayout()
        scrollToCenter(animated: false)
    }

    private func scrollToCenter(animated: Bool) {
        guard collectionView.bounds.width > 0 else { return }
        let offset = CGPoint(x: CGFloat(viewModel.centerPage) * pageStride, y: 0)
        collectionView.setContentOffset(offset, animated: animated)
    }

    // MARK: - ウィンドウ適用

    /// ウィンドウ更新の種別。
    public enum ApplyMode {
        /// スワイプ由来。reloadData して current を中央へ再センタリングする（スワイプはズームリセット）。
        case swiped
        /// ボタン等由来。中央セルはズーム維持で画像だけ差し替え、両隣は読み直す（中央セルは作り直さない）。
        case button
    }

    /// 新しいウィンドウ（prev/current/next）を適用する。distinct until changed で変化がなければ何もしない。
    public func applyWindow(prevURL: URL?, currentURL: URL, nextURL: URL?, mode: ApplyMode) {
        let changed = viewModel.update(prevURL: prevURL, currentURL: currentURL, nextURL: nextURL)
        guard changed else { return }

        switch mode {
        case .swiped:
            recenter()
        case .button:
            updateInPlaceKeepingCenterZoom()
        }
        // 新しい前後の画像を事前読み込みし、次のスワイプでの暗転を防ぐ。
        preloadNeighborImages()
    }

    /// 前後（prev/next）の画像を事前にキャッシュへ読み込んでおく。
    /// ImageLoaderService はデコード済み画像をキャッシュするため、隣ページへスワイプした際に
    /// キャッシュヒットで即座に表示され、非同期読み込み待ちによる暗転を防げる。
    private func preloadNeighborImages() {
        let urls = [viewModel.prevURL, viewModel.nextURL].compactMap { $0 }
        for url in urls {
            Task { [imageLoader] in _ = await imageLoader.loadImage(from: url) }
        }
    }

    /// reloadData して current を中央ページへ戻す。
    /// スワイプで着地した物理ページのセルは新しい current の画像を既に読み込んでいるため、
    /// その画像を退避し、再センタリング後に中央セルへ即時セットする。こうしないと reloadData で
    /// 中央セルが作り直されて画像が非同期に再読み込みされる一瞬だけ暗転してしまう。
    private func recenter() {
        let landedPage = currentPhysicalPage
        let landedImage = (collectionView.cellForItem(at: IndexPath(item: landedPage, section: 0)) as? PhotoPageItemCell)?.loadedImage
        collectionView.reloadData()
        scrollToCenter(animated: false)
        collectionView.layoutIfNeeded()
        if let landedImage {
            // スワイプはズームリセットのため display(image:) をそのまま使う（既読み込み画像を同期表示）。
            currentCell?.display(image: landedImage)
        }
    }

    /// 中央（current）セルはズーム維持で画像を差し替え、両隣（prev/next）は読み直す。
    /// ページ数は常に3で固定なので中央セルは作り直されず、ズーム倍率が維持される。
    private func updateInPlaceKeepingCenterZoom() {
        if let cell = currentCell {
            cell.reloadKeepingZoom(url: viewModel.currentURL, imageLoader: imageLoader)
        } else {
            // 中央セルがまだ生成されていない稀なケースのみ作り直す
            recenter()
            return
        }
        // 両隣はズーム無関係なので作り直す（内容が新しい prev/next に変わる）。アニメーションは出さない。
        let neighborPaths = [0, 2].map { IndexPath(item: $0, section: 0) }
        UIView.performWithoutAnimation {
            collectionView.reloadItems(at: neighborPaths)
        }
    }

    // MARK: - 現在セル

    /// 中央（current）に位置するセル。親がズーム状態の問い合わせやドラッグズーム操作に使う。
    /// 内部型 PhotoPageItemCell を返すため internal（親 PhotoViewerViewController は同一モジュール）。
    var currentCell: PhotoPageItemCell? {
        collectionView.cellForItem(at: IndexPath(item: viewModel.centerPage, section: 0)) as? PhotoPageItemCell
    }

    /// contentOffset から計算した現在の物理ページ番号。
    private var currentPhysicalPage: Int {
        guard collectionView.bounds.width > 0 else { return viewModel.centerPage }
        return Int(round(collectionView.contentOffset.x / pageStride))
    }
}

// MARK: - UICollectionViewDataSource

extension PhotoPageItemViewController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        PhotoPageItemViewModel.pageCount
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoPageItemCell.reuseIdentifier,
            for: indexPath
        ) as! PhotoPageItemCell
        cell.delegate = self
        if let url = viewModel.url(atPage: indexPath.item) {
            cell.configure(index: indexPath.item, url: url, imageLoader: imageLoader)
        } else {
            // 端の空白ページ（prev/next が存在しない）。越えスワイプはクランプで防ぐため表示されない。
            cell.showBlank()
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate / UIScrollViewDelegate

extension PhotoPageItemViewController: UICollectionViewDelegate {
    /// 端（prev/next が無い方向）へは空白ページを見せないよう、スクロール範囲をクランプする。
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView, pageStride > 0 else { return }
        let minX: CGFloat = viewModel.prevURL == nil ? pageStride : 0
        let maxX: CGFloat = viewModel.nextURL == nil ? pageStride : 2 * pageStride
        if scrollView.contentOffset.x < minX {
            scrollView.contentOffset.x = minX
        } else if scrollView.contentOffset.x > maxX {
            scrollView.contentOffset.x = maxX
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        let landed = currentPhysicalPage
        guard landed != viewModel.centerPage else { return }
        // 中央より右へ動いていれば next、左なら previous。
        let direction: PhotoPageDirection = landed > viewModel.centerPage ? .next : .previous
        let landedCell = collectionView.cellForItem(at: IndexPath(item: landed, section: 0)) as? PhotoPageItemCell
        onPageChanged?(direction, landedCell?.loadedImage)
    }
}

// MARK: - PhotoPageItemCellDelegate

extension PhotoPageItemViewController: PhotoPageItemCellDelegate {
    func pageItemCellDidTap(_ cell: PhotoPageItemCell) {
        onTap?()
    }

    func pageItemCellDidDoubleTap(_ cell: PhotoPageItemCell, at locationInImage: CGPoint) {
        onDoubleTap?(locationInImage)
    }

    func pageItemCellDidChangeZoom(_ cell: PhotoPageItemCell) {
        guard cell === currentCell else { return }
        onZoomChanged?()
    }
}
