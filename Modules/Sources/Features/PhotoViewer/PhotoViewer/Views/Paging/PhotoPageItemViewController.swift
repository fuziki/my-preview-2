import UIKit
import Core

/// フォトビューアの写真ページングを担う子ViewController。
/// 内部に横スクロール・ページングの UICollectionView と `UICollectionViewDiffableDataSource` を持つ。
///
/// データソースは**全写真ぶんのアイテム**（写真に紐づかない UUID を要素数分）を常に保持する。
/// 「位置 p のセルは写真 p を表示する」という不変条件を保ち、cellProvider は `indexPath.item` を写真インデックスとして構成する。
/// 全件を確保することで、スワイプは（ウィンドウのスライド無しで）常にセルが用意済みのままスムーズに移動できる。
///
/// - スワイプ: 素の UICollectionView ページングでスクロールするだけ（スナップショット変更なし）。移動完了時に着地セルの
///   ズームをリセットし、`onPageChanged` で親へ通知する。
/// - ボタン/PiP（プログラム遷移）: `moveToIndex(_:)`。**表示中セルの UUID を維持したまま**目的位置へ移動させ（移動元から
///   その UUID を抜き、目的位置へ挿し込む）、そのセルはズーム維持（縦横比が変わる場合はリセット）で画像だけ差し替える。
///   間に挟まれて位置がずれたセルは reconfigure（内容は写真=位置なので更新される）。表示セルは作り直さないので暗転しない。
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
    private let initialIndex: Int

    // MARK: - ウィンドウ状態

    /// 位置 → UUID。位置 p のセルは写真 p を表示する（不変条件）。UUID はセル実体の同一性を表す
    /// （プログラム遷移で表示中セルを目的位置へ移すために使う）。
    private var orderedIDs: [UUID] = []
    /// 現在表示中（中央）のセルの UUID。
    private var currentID = UUID()

    // MARK: - コレクションビュー
    // セクション識別子は単一セクションを表す Int（0固定）。diffable の SectionIdentifierType は
    // Sendable が要求されるため、主アクター隔離になり得るネスト enum ではなく Int を使う。

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
        cv.delegate = self
        return cv
    }()

    private var dataSource: UICollectionViewDiffableDataSource<Int, UUID>!
    private var cellRegistration: UICollectionView.CellRegistration<PhotoPageItemCell, URL>!

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
        view.addSubview(collectionView)
        setupDataSource()
        buildFullList()
    }

    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateCollectionViewFrame()
    }

    // MARK: - レイアウト

    /// 1ページ分のスクロール量（コレクションビュー幅 = 画面幅 + ページ間隔）。
    private var pageStride: CGFloat { collectionView.bounds.width }

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
        scrollToPosition(currentIndex, animated: false)
    }

    private func scrollToPosition(_ position: Int, animated: Bool) {
        guard collectionView.bounds.width > 0 else { return }
        let offset = CGPoint(x: CGFloat(position) * pageStride, y: 0)
        collectionView.setContentOffset(offset, animated: animated)
    }

    // MARK: - データソース

    private func setupDataSource() {
        cellRegistration = UICollectionView.CellRegistration<PhotoPageItemCell, URL> { [imageLoader] cell, _, url in
            cell.configure(url: url, imageLoader: imageLoader)
        }
        dataSource = UICollectionViewDiffableDataSource<Int, UUID>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, _ in
            guard let self else { return nil }
            // 不変条件: 位置 p のセルは写真 p を表示する
            let cell = collectionView.dequeueConfiguredReusableCell(
                using: cellRegistration, for: indexPath, item: allURLs[indexPath.item]
            )
            cell.delegate = self
            return cell
        }
    }

    // MARK: - 現在ページ

    /// 現在表示中（中央）のセルの位置＝写真インデックス。
    private var currentIndex: Int {
        orderedIDs.firstIndex(of: currentID) ?? min(max(initialIndex, 0), max(0, allURLs.count - 1))
    }

    /// 現在表示中のセル。親がズーム状態の問い合わせやドラッグズーム操作に使う。
    var currentPhotoCell: PhotoPageItemCell? {
        cell(atPosition: currentIndex)
    }

    private func cell(atPosition position: Int) -> PhotoPageItemCell? {
        guard orderedIDs.indices.contains(position) else { return nil }
        return collectionView.cellForItem(at: IndexPath(item: position, section: 0)) as? PhotoPageItemCell
    }

    // MARK: - 全件リスト構築

    private func buildFullList() {
        guard !allURLs.isEmpty else { return }
        orderedIDs = allURLs.indices.map { _ in UUID() }
        let start = min(max(initialIndex, 0), allURLs.count - 1)
        currentID = orderedIDs[start]
        applySnapshot(reconfigure: [], animated: false)
        scrollToPosition(start, animated: false)
    }

    /// orderedIDs からスナップショットを構築して適用する。`reconfigure` のUUIDは内容を再構成する。
    private func applySnapshot(reconfigure: [UUID], animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(orderedIDs, toSection: 0)
        let reconfigurable = reconfigure.filter { orderedIDs.contains($0) }
        if !reconfigurable.isEmpty {
            snapshot.reconfigureItems(reconfigurable)
        }
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    // MARK: - プログラム遷移（ボタン・PiP・フィルタ自動遷移）

    /// 指定インデックスへプログラム遷移する。表示中セルの UUID を維持したまま目的位置へ移し、
    /// そのセルはズーム維持（縦横比が変わる場合はリセット）で画像だけ差し替える。既に current が同じなら何もしない。
    public func moveToIndex(_ newIndex: Int) {
        guard allURLs.indices.contains(newIndex),
              let oldPos = orderedIDs.firstIndex(of: currentID),
              oldPos != newIndex else { return }

        // 表示中セルの UUID を移動元から抜いて目的位置へ挿し込む（＝そのセル実体が目的位置へ移る）。
        orderedIDs.remove(at: oldPos)
        orderedIDs.insert(currentID, at: newIndex)

        // 間に挟まれて位置がずれた（＝写真が変わる）セルは reconfigure する。表示セル（currentID）は作り直さない。
        let lo = min(oldPos, newIndex)
        let hi = max(oldPos, newIndex)
        let shifted = orderedIDs[lo...hi].filter { $0 != currentID }
        applySnapshot(reconfigure: Array(shifted), animated: false)

        // 先に目的位置へ寄せて表示セルを可視化してから、そのセルの画像を差し替える。
        scrollToPosition(newIndex, animated: false)
        collectionView.layoutIfNeeded()
        // 表示セルはズーム維持（縦横比が変わる場合はリセット）で画像だけ差し替える。
        currentPhotoCell?.updateKeepingZoomIfSameAspect(url: allURLs[newIndex], imageLoader: imageLoader)
    }
}

// MARK: - UICollectionViewDelegate / UIScrollViewDelegate

extension PhotoPageItemViewController: UICollectionViewDelegate {
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === collectionView, pageStride > 0 else { return }
        let landedPosition = Int(round(scrollView.contentOffset.x / pageStride))
        guard orderedIDs.indices.contains(landedPosition), landedPosition != currentIndex else { return }
        currentID = orderedIDs[landedPosition]
        // スワイプでの移動はズームをリセットする
        currentPhotoCell?.resetZoomToFit()
        onPageChanged?(landedPosition, currentPhotoCell?.loadedImage)
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
        guard cell === currentPhotoCell else { return }
        onZoomChanged?()
    }
}
