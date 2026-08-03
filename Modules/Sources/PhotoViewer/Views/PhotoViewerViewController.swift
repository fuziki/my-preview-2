import UIKit
import Core
import Localization
import ImagePiPKit

public final class PhotoViewerViewController: UIViewController {

    // MARK: - プロパティ

    private let viewModel: PhotoViewerViewModel
    private var displayedImage: UIImage?
    private var autoNavigationTask: Task<Void, Never>?
    private var longPressZoomCircleView: UIView?
    private var longPressLastLocation: CGPoint = .zero
    /// 現在表示中のURL（FileBrowserがズーム戻り先セルを特定するために使用する）
    public var currentURL: URL { viewModel.currentURL }

    /// 閉じる時に呼ばれるコールバック（最後に表示していたURLを通知する）
    public var onDismiss: ((URL) -> Void)?

    // MARK: - コレクションビュー

    private let interPageSpacing: CGFloat = 16

    /// レイアウト位置（contentOffsetベース）と論理インデックスの差分。
    /// ボタンナビゲーション時にセルをそのまま維持するため、スクロールせずにこの値を更新する。
    private var layoutPageOffset: Int = 0

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

    /// contentOffsetから計算したレイアウト上の現在ページ位置（論理インデックスとは異なる場合がある）
    private var currentLayoutPage: Int {
        guard collectionView.bounds.width > 0 else { return viewModel.currentIndex - layoutPageOffset }
        return Int(round(collectionView.contentOffset.x / collectionView.bounds.width))
    }

    /// 現在表示中の論理インデックス（レイアウトページ + オフセット）
    private var currentDisplayedPage: Int {
        currentLayoutPage + layoutPageOffset
    }

    /// 現在表示中のセル（論理インデックスからレイアウト位置を逆算して取得）
    private var currentItemCell: PhotoPageItemCell? {
        let layoutPos = viewModel.currentIndex - layoutPageOffset
        guard layoutPos >= 0, layoutPos < viewModel.allURLs.count else { return nil }
        return collectionView.cellForItem(at: IndexPath(item: layoutPos, section: 0)) as? PhotoPageItemCell
    }

    // MARK: - ビュー

    private let closeButtonView = GlassButtonView.circle(systemImageName: "xmark")
    private let prevButtonView = GlassButtonView.circle(systemImageName: "chevron.left")
    private let nextButtonView = GlassButtonView.circle(systemImageName: "chevron.right")

    /// ガラスボタンの前面に重ねる透明タッチ領域（88×88）。
    /// GlassButtonViewは視覚のみ担当し、タップ・長押しはこちらで検出する。
    private let prevHitAreaButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let nextHitAreaButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let photoInfoPillView = PhotoInfoPillView()

    /// 画面回転設定を循環させるボタン（端末の設定に追従 → 縦画面固定 → 横画面固定）
    private let orientationLockButtonView = GlassButtonView.circle(systemImageName: "arrow.triangle.2.circlepath")

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        // ズーム中のみ表示するため、初期状態は非表示にする
        iv.isHidden = true
        return iv
    }()

    private var thumbnailSizeConstraints: [NSLayoutConstraint] = []

    /// レーティングバー・保存ボタン付近の縦持ち/横持ち向けの制約セット（isRatingEnabled時のみ使用）
    private var portraitBottomBarConstraints: [NSLayoutConstraint] = []
    private var landscapeBottomBarConstraints: [NSLayoutConstraint] = []
    private var isCurrentlyLandscape: Bool?
    /// 横持ち時にレーティングバー＋保存ボタンの組を左右中央揃えするための不可視ガイド
    private let bottomBarGroupGuide = UILayoutGuide()

    private let saveButtonView: GlassButtonView = {
        var config = UIButton.Configuration.borderless()
        config.title = L10n.PhotoViewer.saveIdle
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.foregroundColor = .white
            return updated
        }
        let button = UIButton(configuration: config)
        return GlassButtonView(button: button, cornerRadius: 22)
    }()

    private let ratingLabelBarView = RatingLabelBarView()

    /// PiP開始ボタン。保存ボタンの右隣に配置する
    private let pipButtonView = GlassButtonView.circle(systemImageName: "pip.enter")
    private lazy var pipController = ImagePiPController(containerView: view)
    /// 保存ボタン + PiPボタンの組を左右中央に配置するための不可視ガイド
    private let saveButtonGroupGuide = UILayoutGuide()

    private let lastSavedDateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = UIColor.white.withAlphaComponent(0.65)
        label.font = .preferredFont(forTextStyle: .caption2)
        label.isHidden = true
        return label
    }()

    private static let savedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return f
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // MARK: - 初期化

    private let imageLoader: any ImageLoaderServiceProtocol

    public init(input: PhotoViewerInput, services: PhotoViewerServices) {
        viewModel = PhotoViewerViewModel(input: input, services: services)
        imageLoader = services.imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ライフサイクル

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCollectionView()
        setupOverlay()
        setupActions()
        setupPictureInPicture()
        Task { await viewModel.loadInitial() }
    }

    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateCollectionViewFrame()
        updateBottomBarLayoutIfNeeded()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 写真閲覧中は画面ロックを防止する
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ズームトランジションのスワイプ閉じ制御のため、プレゼンテーションコントローラのデリゲートを設定する
        presentationController?.delegate = self
        // 表示直後、ロック中の向きへ能動的に回転させる（マスクを絞るだけでは自動回転しないため）
        applyOrientationLock()
    }

    /// dismiss完了後に向きを戻すための参照。`presentingViewController`/`view.window`は
    /// `viewDidDisappear`の時点では既に`nil`になっているため、まだ有効な`viewWillDisappear`で捕捉しておく。
    private weak var orientationRevertPresenter: UIViewController?
    private weak var orientationRevertScene: UIWindowScene?

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
        if isBeingDismissed {
            // PiPソースレイヤーの土台であるviewが破棄されるため、閉じる前に停止する
            pipController.stop()
            // 閉じる時点での表示URLをFileBrowserへ通知する
            onDismiss?(viewModel.currentURL)
            // 縦/横固定中はコントロールセンターの回転ロックを一時的に上書きしていることがあり、
            // 何もしないと閉じた後もその向きのまま残ってしまうため、presenter側へ能動的に
            // 回転要求を出し直す。参照はまだ有効なここで捕捉し、実際の要求はトランジション完了後の
            // viewDidDisappearで行う（進行中に発行するとビュー階層と衝突して表示が崩れるため）。
            if viewModel.orientationLock != .followSystem {
                orientationRevertPresenter = presentingViewController
                orientationRevertScene = view.window?.windowScene
            }
        }
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard let presenter = orientationRevertPresenter, let scene = orientationRevertScene else { return }
        orientationRevertPresenter = nil
        orientationRevertScene = nil
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: presenter.supportedInterfaceOrientations)) { _ in }
    }

    // MARK: - ステータスバー

    override public var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override public var prefersStatusBarHidden: Bool { !viewModel.isOverlayVisible }

    // MARK: - 画面回転

    override public var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        switch viewModel.orientationLock {
        case .followSystem: super.supportedInterfaceOrientations
        case .portrait: .portrait
        case .landscape: .landscape
        }
    }

    /// 画面回転設定を切り替えた際、その場で能動的に回転させる。
    private func applyOrientationLock() {
        guard let windowScene = view.window?.windowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: supportedInterfaceOrientations)) { _ in }
    }

    // MARK: - updateProperties

    override public func updateProperties() {
        super.updateProperties()
        photoInfoPillView.configure(fileName: viewModel.currentFileName, exifInfo: viewModel.exifInfo)
        prevButtonView.button.isEnabled = viewModel.canGoPrevious
        prevButtonView.button.tintColor = viewModel.canGoPrevious ? .white : .systemGray
        prevHitAreaButton.isEnabled = viewModel.canGoPrevious
        nextButtonView.button.isEnabled = viewModel.canGoNext
        nextButtonView.button.tintColor = viewModel.canGoNext ? .white : .systemGray
        nextHitAreaButton.isEnabled = viewModel.canGoNext
        updateSaveButton(status: viewModel.saveStatus)
        orientationLockButtonView.button.configuration?.image = UIImage(systemName: orientationLockIconName(for: viewModel.orientationLock))
        ratingLabelBarView.setRating(viewModel.currentRating)
        ratingLabelBarView.setColorLabel(viewModel.currentColorLabel)
        if viewModel.shouldDismiss, !isBeingDismissed {
            // フィルタに適合する写真が1枚も無くなったのでビューアーを閉じる
            dismiss(animated: true)
        }
        if let date = viewModel.lastSavedDate {
            lastSavedDateLabel.text = L10n.PhotoViewer.lastSavedLabel(Self.savedDateFormatter.string(from: date))
            lastSavedDateLabel.isHidden = false
        } else {
            lastSavedDateLabel.isHidden = true
        }
        viewModel.isLoading ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
        updateOverlayVisibility(visible: viewModel.isOverlayVisible)

        if let image = viewModel.currentImage, image !== displayedImage {
            displayedImage = image
            NSLayoutConstraint.deactivate(thumbnailSizeConstraints)
            let maxSide: CGFloat = 80
            let ratio = image.size.width / image.size.height
            let w = ratio >= 1 ? maxSide : maxSide * ratio
            let h = ratio >= 1 ? maxSide / ratio : maxSide
            thumbnailSizeConstraints = [
                thumbnailImageView.widthAnchor.constraint(equalToConstant: w),
                thumbnailImageView.heightAnchor.constraint(equalToConstant: h),
            ]
            NSLayoutConstraint.activate(thumbnailSizeConstraints)
            thumbnailImageView.image = image
            if isPiPActive {
                pipController.update(image: image)
            }

            if currentDisplayedPage != viewModel.currentIndex {
                // ボタンナビゲーション: セルをそのまま維持して画像を差し替える（ズーム状態を保持するため）。
                // layoutPageOffsetを更新し、現在のレイアウト位置が新しい論理インデックスを指すようにする。
                let currentLayoutPos = currentLayoutPage
                layoutPageOffset = viewModel.currentIndex - currentLayoutPos
                currentItemCell?.index = viewModel.currentIndex
                currentItemCell?.display(image: image, previousOrientation: viewModel.previousOrientation)
                // 隣接セルをreloadして新しいoffset基準の論理インデックスを適用する
                var toReload: [IndexPath] = []
                if currentLayoutPos > 0 {
                    toReload.append(IndexPath(item: currentLayoutPos - 1, section: 0))
                }
                if currentLayoutPos < viewModel.allURLs.count - 1 {
                    toReload.append(IndexPath(item: currentLayoutPos + 1, section: 0))
                }
                if !toReload.isEmpty { collectionView.reloadItems(at: toReload) }
            } else {
                // スワイプナビゲーションまたは初回読み込み: そのままセルに表示する。
                currentItemCell?.display(image: image, previousOrientation: viewModel.previousOrientation)
            }
        }
    }

    // MARK: - セットアップ

    private func setupCollectionView() {
        view.addSubview(collectionView)
    }

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
        scrollToPage(viewModel.currentIndex - layoutPageOffset, animated: false)
    }

    /// 指定インデックスのページへスクロールする。
    /// コレクションビューの幅（= view.width + spacing）が1ページ分のスクロール量に相当する。
    private func scrollToPage(_ index: Int, animated: Bool) {
        guard collectionView.bounds.width > 0 else { return }
        let offset = CGPoint(x: CGFloat(index) * collectionView.bounds.width, y: 0)
        collectionView.setContentOffset(offset, animated: animated)
    }

    /// 横持ち/縦持ちの切り替わりを検知し、レーティングバー・保存ボタン付近の制約セットを差し替える。
    private func updateBottomBarLayoutIfNeeded() {
        guard viewModel.isRatingEnabled else { return }
        let isLandscape = view.bounds.width > view.bounds.height
        guard isLandscape != isCurrentlyLandscape else { return }
        isCurrentlyLandscape = isLandscape
        if isLandscape {
            NSLayoutConstraint.deactivate(portraitBottomBarConstraints)
            NSLayoutConstraint.activate(landscapeBottomBarConstraints)
        } else {
            NSLayoutConstraint.deactivate(landscapeBottomBarConstraints)
            NSLayoutConstraint.activate(portraitBottomBarConstraints)
        }
    }

    private func setupOverlay() {
        // 各フローティング要素をcollectionViewの上に直接追加する。

        // 閉じるボタン: 左上のフローティング円
        view.addSubview(closeButtonView)
        NSLayoutConstraint.activate([
            closeButtonView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButtonView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
        ])

        // 前へボタン: 左下のフローティング円
        view.addSubview(prevButtonView)
        NSLayoutConstraint.activate([
            prevButtonView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            prevButtonView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
        ])

        // 次へボタン: 右下のフローティング円
        view.addSubview(nextButtonView)
        NSLayoutConstraint.activate([
            nextButtonView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButtonView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])

        // ファイル名 + EXIF: 右上のフローティングピル。コンテンツ幅に応じて自身も収縮するため、
        // leadingはcloseButtonViewと重ならないための床（下限）のみ
        view.addSubview(photoInfoPillView)
        NSLayoutConstraint.activate([
            photoInfoPillView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            photoInfoPillView.leadingAnchor.constraint(greaterThanOrEqualTo: closeButtonView.trailingAnchor, constant: 8),
            photoInfoPillView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])

        // 画面回転ボタン: ファイル名 + EXIFピルの左隣、上safeArea揃え
        view.addSubview(orientationLockButtonView)
        NSLayoutConstraint.activate([
            orientationLockButtonView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            orientationLockButtonView.trailingAnchor.constraint(equalTo: photoInfoPillView.leadingAnchor, constant: -8),
        ])

        // サムネイル: ファイル名ラベルの下、右揃え
        view.addSubview(thumbnailImageView)
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: photoInfoPillView.bottomAnchor, constant: 8),
            thumbnailImageView.trailingAnchor.constraint(equalTo: photoInfoPillView.trailingAnchor),
        ])

        // 保存ボタン: 下部中央のカプセル形
        // centerXは縦持ち/横持ちで意味が変わる（横持ちはレーティングバーとの組を中央揃えするため）ため、
        // レーティング有効時はここでは固定せずportrait/landscapeの制約セット側で設定する。
        view.addSubview(saveButtonView)
        // PiP開始ボタン: 保存ボタンの右隣（タップエリアの拡張なし）
        view.addSubview(pipButtonView)
        view.addLayoutGuide(saveButtonGroupGuide)
        NSLayoutConstraint.activate([
            saveButtonView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            saveButtonView.leadingAnchor.constraint(greaterThanOrEqualTo: prevButtonView.trailingAnchor, constant: 8),
            saveButtonView.heightAnchor.constraint(equalToConstant: 44),
            saveButtonView.button.topAnchor.constraint(equalTo: saveButtonView.topAnchor),
            saveButtonView.button.bottomAnchor.constraint(equalTo: saveButtonView.bottomAnchor),
            saveButtonView.button.leadingAnchor.constraint(equalTo: saveButtonView.leadingAnchor),
            saveButtonView.button.trailingAnchor.constraint(equalTo: saveButtonView.trailingAnchor),

            pipButtonView.leadingAnchor.constraint(equalTo: saveButtonView.trailingAnchor, constant: 8),
            pipButtonView.centerYAnchor.constraint(equalTo: saveButtonView.centerYAnchor),
            pipButtonView.trailingAnchor.constraint(lessThanOrEqualTo: nextButtonView.leadingAnchor, constant: -8),

            // 保存ボタン + PiPボタンをひとつの組とみなし、中央揃えの基準として使う
            saveButtonGroupGuide.leadingAnchor.constraint(equalTo: saveButtonView.leadingAnchor),
            saveButtonGroupGuide.trailingAnchor.constraint(equalTo: pipButtonView.trailingAnchor),
        ])

        // レーティング星 + カラーラベル: 保存ボタンの上のカプセル（レーティング有効時のみ）
        // 縦持ち/横持ちで配置が異なるため、両方の制約セットを用意しviewWillLayoutSubviewsで切り替える
        if viewModel.isRatingEnabled {
            view.addSubview(ratingLabelBarView)
            view.addLayoutGuide(bottomBarGroupGuide)
            portraitBottomBarConstraints = [
                saveButtonGroupGuide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                ratingLabelBarView.bottomAnchor.constraint(equalTo: saveButtonView.topAnchor, constant: -8),
                ratingLabelBarView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ]
            landscapeBottomBarConstraints = [
                ratingLabelBarView.centerYAnchor.constraint(equalTo: saveButtonView.centerYAnchor),
                ratingLabelBarView.trailingAnchor.constraint(equalTo: saveButtonView.leadingAnchor, constant: -8),
                // レーティングバー＋保存ボタン＋PiPボタンの組をひとつのグループとみなし、左右中央に配置する
                bottomBarGroupGuide.leadingAnchor.constraint(equalTo: ratingLabelBarView.leadingAnchor),
                bottomBarGroupGuide.trailingAnchor.constraint(equalTo: pipButtonView.trailingAnchor),
                bottomBarGroupGuide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ]
        } else {
            NSLayoutConstraint.activate([
                saveButtonGroupGuide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ])
        }

        // ローディングインジケーター: 保存ボタン（レーティング有効時は星 + カラーラベル）の上
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: saveButtonView.centerXAnchor),
        ])
        if viewModel.isRatingEnabled {
            portraitBottomBarConstraints.append(
                loadingIndicator.bottomAnchor.constraint(equalTo: ratingLabelBarView.topAnchor, constant: -8)
            )
            landscapeBottomBarConstraints.append(
                loadingIndicator.bottomAnchor.constraint(equalTo: saveButtonView.topAnchor, constant: -8)
            )
        } else {
            NSLayoutConstraint.activate([
                loadingIndicator.bottomAnchor.constraint(equalTo: saveButtonView.topAnchor, constant: -8),
            ])
        }

        // 最終保存日時ラベル: 保存ボタンの下
        view.addSubview(lastSavedDateLabel)
        NSLayoutConstraint.activate([
            lastSavedDateLabel.topAnchor.constraint(equalTo: saveButtonView.bottomAnchor, constant: 4),
            lastSavedDateLabel.centerXAnchor.constraint(equalTo: saveButtonView.centerXAnchor),
        ])

        // 前へタッチ領域: 44×44のアイコンに対して左右下16pt・上8ptだけ拡張する。
        // 上をレーティングバーとの間隔(8pt)に合わせて重ならないようにしている。
        // ガラスボタンの上に重ねて前面に配置する。
        view.addSubview(prevHitAreaButton)
        NSLayoutConstraint.activate([
            prevHitAreaButton.leadingAnchor.constraint(equalTo: prevButtonView.leadingAnchor, constant: -16),
            prevHitAreaButton.trailingAnchor.constraint(equalTo: prevButtonView.trailingAnchor, constant: 16),
            prevHitAreaButton.topAnchor.constraint(equalTo: prevButtonView.topAnchor, constant: -8),
            prevHitAreaButton.bottomAnchor.constraint(equalTo: prevButtonView.bottomAnchor, constant: 16),
        ])

        // 次へタッチ領域: 44×44のアイコンに対して左右下16pt・上8ptだけ拡張する。
        // 上をレーティングバーとの間隔(8pt)に合わせて重ならないようにしている。
        // ガラスボタンの上に重ねて前面に配置する。
        view.addSubview(nextHitAreaButton)
        NSLayoutConstraint.activate([
            nextHitAreaButton.leadingAnchor.constraint(equalTo: nextButtonView.leadingAnchor, constant: -16),
            nextHitAreaButton.trailingAnchor.constraint(equalTo: nextButtonView.trailingAnchor, constant: 16),
            nextHitAreaButton.topAnchor.constraint(equalTo: nextButtonView.topAnchor, constant: -8),
            nextHitAreaButton.bottomAnchor.constraint(equalTo: nextButtonView.bottomAnchor, constant: 16),
        ])
    }

    private func setupActions() {
        closeButtonView.button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        orientationLockButtonView.button.addTarget(self, action: #selector(orientationLockTapped), for: .touchUpInside)
        // タップ・長押しはガラスボタンの前面にある広いタッチ領域ボタンで検出する。
        prevHitAreaButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextHitAreaButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        saveButtonView.button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        pipButtonView.button.addTarget(self, action: #selector(pipTapped), for: .touchUpInside)
        ratingLabelBarView.onStarTapped = { [weak self] stars in
            Task { await self?.viewModel.setRating(stars) }
        }
        ratingLabelBarView.onColorTapped = { [weak self] label in
            Task { await self?.viewModel.setColorLabel(label) }
        }

        // disabled 状態でも文字色を白に保つ。baseForegroundColor は UIKit が状態に応じて調整するが、
        // titleTextAttributesTransformer の foregroundColor は状態に関わらず直接適用される。
        saveButtonView.button.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var updated = attributes
                updated.foregroundColor = UIColor.white.withAlphaComponent(0.8)
                return updated
            }
            button.configuration = config
        }

        let prevLongPress = UILongPressGestureRecognizer(target: self, action: #selector(prevLongPressed(_:)))
        prevLongPress.minimumPressDuration = 1.0
        prevHitAreaButton.addGestureRecognizer(prevLongPress)

        let nextLongPress = UILongPressGestureRecognizer(target: self, action: #selector(nextLongPressed(_:)))
        nextLongPress.minimumPressDuration = 1.0
        nextHitAreaButton.addGestureRecognizer(nextLongPress)

        let longPressZoom = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressZoom(_:)))
        longPressZoom.minimumPressDuration = 0.5
        collectionView.addGestureRecognizer(longPressZoom)
    }

    // MARK: - オーバーレイ

    private func updateOverlayVisibility(visible: Bool) {
        UIView.animate(withDuration: 0.2) {
            let alpha: CGFloat = visible ? 1 : 0
            self.closeButtonView.alpha = alpha
            self.prevButtonView.alpha = alpha
            self.nextButtonView.alpha = alpha
            // alpha=0 のとき UIKit がタッチを無効化するため、オーバーレイ非表示中は操作不可になる。
            self.prevHitAreaButton.alpha = alpha
            self.nextHitAreaButton.alpha = alpha
            self.photoInfoPillView.alpha = alpha
            self.orientationLockButtonView.alpha = alpha
            self.thumbnailImageView.alpha = alpha
            self.saveButtonView.alpha = alpha
            self.pipButtonView.alpha = alpha
            self.ratingLabelBarView.alpha = alpha
            self.lastSavedDateLabel.alpha = alpha
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    /// サムネイルは画像をズームしている場合のみ表示する
    private func updateThumbnailVisibility() {
        thumbnailImageView.isHidden = !(currentItemCell?.isZoomed ?? false)
    }

    // MARK: - 保存ボタン

    private func updateSaveButton(status: SaveStatus) {
        switch status {
        case .idle:
            saveButtonView.button.configuration?.title = L10n.PhotoViewer.saveIdle
            saveButtonView.button.isEnabled = true
        case .saving:
            saveButtonView.button.configuration?.title = L10n.PhotoViewer.saveSaving
            saveButtonView.button.isEnabled = false
        case .success:
            saveButtonView.button.configuration?.title = L10n.PhotoViewer.saveCompleted
            saveButtonView.button.isEnabled = false
        case .failure:
            saveButtonView.button.configuration?.title = L10n.PhotoViewer.saveFailed
            saveButtonView.button.isEnabled = true
        }
    }

    // MARK: - PiP

    /// PiPが現在アクティブか。画像更新をPiP側へも反映するかの判定に使う
    private var isPiPActive = false

    private func setupPictureInPicture() {
        guard ImagePiPController.isSupported else {
            pipButtonView.button.isEnabled = false
            return
        }
        pipController.attach()
        pipController.onDidStart = { [weak self] in
            self?.isPiPActive = true
        }
        pipController.onDidStop = { [weak self] in
            self?.isPiPActive = false
        }
        pipController.onSkipForward = { [weak self] in
            Task {
                await self?.viewModel.navigateNext()
                self?.pushCurrentImageToPiPIfNeeded()
            }
        }
        pipController.onSkipBackward = { [weak self] in
            Task {
                await self?.viewModel.navigatePrevious()
                self?.pushCurrentImageToPiPIfNeeded()
            }
        }
        pipController.onAutoAdvanceTick = { [weak self] in
            Task {
                await self?.viewModel.advanceForPictureInPictureAutoPlay()
                self?.pushCurrentImageToPiPIfNeeded()
            }
        }
    }

    /// バックグラウンドではupdateProperties()（UIKitの通常の描画更新サイクルに連動）が呼ばれにくく、
    /// PiPスキップ操作による画像変更が反映されないことがあるため、ナビゲーション直後に直接反映する
    private func pushCurrentImageToPiPIfNeeded() {
        guard isPiPActive, let image = viewModel.currentImage else { return }
        pipController.update(image: image)
    }

    // MARK: - 画面回転ボタン

    private func orientationLockIconName(for lock: PhotoViewerOrientationLock) -> String {
        switch lock {
        case .followSystem: "arrow.triangle.2.circlepath"
        case .portrait: "iphone"
        case .landscape: "iphone.landscape"
        }
    }

    // MARK: - アクション

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func orientationLockTapped() {
        viewModel.cycleOrientationLock()
        applyOrientationLock()
    }

    @objc private func prevTapped() {
        Task { await viewModel.navigatePrevious() }
    }

    @objc private func nextTapped() {
        Task { await viewModel.navigateNext() }
    }

    @objc private func saveTapped() {
        Task { await viewModel.save() }
    }

    @objc private func pipTapped() {
        if isPiPActive {
            pipController.stop()
            return
        }
        guard let image = viewModel.currentImage else { return }
        pipController.start(image: image, autoAdvanceInterval: TimeInterval(viewModel.pipAutoAdvanceIntervalSeconds))
    }

    @objc private func prevLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            startAutoNavigation(forward: false)
        case .ended, .cancelled, .failed:
            stopAutoNavigation()
        default:
            break
        }
    }

    @objc private func nextLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            startAutoNavigation(forward: true)
        case .ended, .cancelled, .failed:
            stopAutoNavigation()
        default:
            break
        }
    }

    private func startAutoNavigation(forward: Bool) {
        stopAutoNavigation()
        autoNavigationTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if forward {
                    guard viewModel.canGoNext else { break }
                    await viewModel.navigateNext()
                } else {
                    guard viewModel.canGoPrevious else { break }
                    await viewModel.navigatePrevious()
                }
                guard !Task.isCancelled else { break }
                try? await Task.sleep(for: .seconds(0.12))
            }
        }
    }

    private func stopAutoNavigation() {
        autoNavigationTask?.cancel()
        autoNavigationTask = nil
    }

    // MARK: - 長押しズーム

    @objc private func handleLongPressZoom(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            let location = gesture.location(in: view)
            longPressLastLocation = location
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showZoomCircle(at: location)
        case .changed:
            let location = gesture.location(in: view)
            let dx = location.x - longPressLastLocation.x
            let dy = location.y - longPressLastLocation.y
            longPressLastLocation = location

            // UIKit座標系（Y下向き）: 右上方向成分 = dx - dy
            // 右上方向で拡大、左下方向で縮小
            let multiplier = exp((dx - dy) * 0.01)
            if let zoom = currentItemCell?.zoomScrollView {
                let newScale = max(zoom.minimumZoomScale, min(zoom.maximumZoomScale, zoom.zoomScale * multiplier))
                zoom.setZoomScale(newScale, animated: false)
                updateThumbnailVisibility()
            }
            longPressZoomCircleView?.center = location
        case .ended, .cancelled, .failed:
            hideZoomCircle()
        default:
            break
        }
    }

    private func showZoomCircle(at point: CGPoint) {
        let size: CGFloat = 60
        let circle = UIView()
        circle.bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        circle.center = point
        circle.layer.cornerRadius = size / 2
        circle.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        circle.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        circle.layer.borderWidth = 2
        circle.isUserInteractionEnabled = false
        view.addSubview(circle)

        circle.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        circle.alpha = 0
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: []) {
            circle.transform = .identity
            circle.alpha = 1
        }
        longPressZoomCircleView = circle
    }

    private func hideZoomCircle() {
        guard let circle = longPressZoomCircleView else { return }
        longPressZoomCircleView = nil
        UIView.animate(withDuration: 0.2) {
            circle.alpha = 0
            circle.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        } completion: { _ in
            circle.removeFromSuperview()
        }
    }
}

// MARK: - CurrentURLProvider & DismissNotifiable

extension PhotoViewerViewController: CurrentURLProvider {}
extension PhotoViewerViewController: DismissNotifiable {}

// MARK: - PhotoPageItemCellDelegate

extension PhotoViewerViewController: PhotoPageItemCellDelegate {
    func pageItemCellDidTap(_ cell: PhotoPageItemCell) {
        viewModel.toggleOverlay()
    }

    func pageItemCellDidDoubleTap(_ cell: PhotoPageItemCell, at locationInImage: CGPoint) {
        let zoom = cell.zoomScrollView
        if zoom.zoomScale > zoom.minimumZoomScale + 0.001 {
            zoom.setZoomScale(zoom.minimumZoomScale, animated: true)
        } else {
            let width = zoom.bounds.width / zoom.maximumZoomScale
            let height = zoom.bounds.height / zoom.maximumZoomScale
            let rect = CGRect(
                x: locationInImage.x - width / 2,
                y: locationInImage.y - height / 2,
                width: width,
                height: height
            )
            zoom.zoom(to: rect, animated: true)
        }
    }

    func pageItemCellDidChangeZoom(_ cell: PhotoPageItemCell) {
        guard cell === currentItemCell else { return }
        updateThumbnailVisibility()
    }
}

// MARK: - UICollectionViewDataSource

extension PhotoViewerViewController: UICollectionViewDataSource {
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.allURLs.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoPageItemCell.reuseIdentifier,
            for: indexPath
        ) as! PhotoPageItemCell
        // layoutPageOffsetを加算して論理インデックスに変換する。境界値はクランプする。
        let logicalIndex = max(0, min(viewModel.allURLs.count - 1, indexPath.item + layoutPageOffset))
        cell.delegate = self
        cell.configure(index: logicalIndex, url: viewModel.allURLs[logicalIndex], imageLoader: imageLoader)
        return cell
    }
}

// MARK: - UICollectionViewDelegate / UIScrollViewDelegate

extension PhotoViewerViewController: UICollectionViewDelegate {
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        // currentDisplayedPageはlayoutPageOffsetを加算した論理インデックス
        let newIndex = currentDisplayedPage
        guard newIndex != viewModel.currentIndex,
              newIndex >= 0, newIndex < viewModel.allURLs.count else { return }
        // セルはレイアウト位置（currentLayoutPage）で取得する
        let cell = collectionView.cellForItem(at: IndexPath(item: currentLayoutPage, section: 0)) as? PhotoPageItemCell
        Task { await viewModel.didSwipeTo(index: newIndex, image: cell?.loadedImage) }
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension PhotoViewerViewController: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        // 画像をズーム中はスワイプで閉じる操作を無効にする
        !(currentItemCell?.isZoomed ?? false)
    }
}
