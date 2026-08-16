import UIKit
import Core
import Localization
import ImagePiPKit

public final class PhotoViewerViewController: UIViewController {

    // MARK: - プロパティ

    private let viewModel: PhotoViewerViewModel
    private var displayedImage: UIImage?
    private var longPressZoomCircleView: UIView?
    private var longPressLastLocation: CGPoint = .zero
    /// 現在表示中のURL（FileBrowserがズーム戻り先セルを特定するために使用する）
    public var currentURL: URL { viewModel.currentURL }

    /// 閉じる時に呼ばれるコールバック（最後に表示していたURLを通知する）
    public var onDismiss: ((URL) -> Void)?

    // MARK: - 写真ページャ（子ViewController）

    /// UICollectionView（diffable・UUIDウィンドウ）ベースの写真ページング子VC。スワイプ・プログラム遷移を担う。
    private var pageItemVC: PhotoPageItemViewController!

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

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        // ズーム中のみ表示するため、初期状態は非表示にする
        iv.isHidden = true
        return iv
    }()

    private var thumbnailSizeConstraints: [NSLayoutConstraint] = []

    /// レーティングバー・PiP/回転座布団・保存ボタン付近の縦持ち/横持ち向けの制約セット
    private var portraitBottomBarConstraints: [NSLayoutConstraint] = []
    private var landscapeBottomBarConstraints: [NSLayoutConstraint] = []
    private var isCurrentlyLandscape: Bool?
    /// 横持ち時にレーティングバー＋保存ボタン＋PiP/回転座布団の組を左右中央揃えするための不可視ガイド（isRatingEnabled時のみ使用）
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

    /// PiP開始ボタン + 画面回転ボタンをまとめた座布団。評価機能有効時は星+カラーラベルの座布団の右隣に、
    /// 無効時は座布団があった位置の右端（保存ボタン基準）に配置する
    private let pipOrientationBarView = PiPOrientationBarView(
        pipSystemImageName: "pip.enter",
        orientationSystemImageName: "arrow.triangle.2.circlepath"
    )
    private lazy var pipController = ImagePiPController(containerView: view)

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

    public init(input: PhotoViewerInput, dependencies: PhotoViewerDependencies) {
        viewModel = PhotoViewerViewModel(input: input, dependencies: dependencies)
        imageLoader = dependencies.imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ライフサイクル

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPhotoPager()
        setupOverlay()
        setupActions()
        setupPictureInPicture()
        Task { await viewModel.loadInitial() }
    }

    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
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
        pipOrientationBarView.orientationButton.configuration?.image = UIImage(systemName: orientationLockIconName(for: viewModel.orientationLock))
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

        // オーバーレイ用サムネイル（ズーム時のみ表示）とPiP画像をcurrentImageの変化に応じて更新する。
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
        }

        // 子ページャは、プログラム遷移（ボタン/PiP/フィルタ/初回）でのみ currentIndex へ同期する。
        // スワイプ由来ではページャ自身が既に移動済みで、ここで moveToIndex を呼ぶと高速スワイプ中に
        // 非同期遅延したインデックスでページャと綱引きになり引っ掛かるため、呼ばない。
        if !viewModel.lastChangeWasSwipe {
            pageItemVC.moveToIndex(viewModel.currentIndex)
        }
    }

    // MARK: - セットアップ
    // setupOverlay() / updateBottomBarLayoutIfNeeded() の制約組み立て部分はPhotoViewerLayoutBuilder
    // （別ファイル）の静的関数に切り出しており、そこでは自身のprivateプロパティを引数として渡し、
    // 戻り値を制約配列プロパティへ書き戻すだけにしている。

    /// 写真ページャ（子ViewController）を最背面に配置し、コールバックを配線する。
    private func setupPhotoPager() {
        let vc = PhotoPageItemViewController(
            allURLs: viewModel.allURLs,
            initialIndex: viewModel.currentIndex,
            imageLoader: imageLoader
        )
        addChild(vc)
        vc.view.frame = view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(vc.view)
        vc.didMove(toParent: self)
        pageItemVC = vc
        wirePhotoPagerCallbacks()
    }

    private func wirePhotoPagerCallbacks() {
        // スワイプ移動: 子ページャが移動完了した新インデックスと表示中画像を通知する。
        // ViewModel 更新後、updateProperties が moveToIndex を呼ぶが、既に同インデックスなので冪等に無視される。
        pageItemVC.onPageChanged = { [weak self] index, image in
            guard let self else { return }
            Task { await viewModel.didSwipeTo(index: index, image: image) }
        }
        pageItemVC.onTap = { [weak self] in
            self?.viewModel.toggleOverlay()
        }
        pageItemVC.onDoubleTap = { [weak self] locationInImage in
            self?.handleDoubleTapZoom(at: locationInImage)
        }
        pageItemVC.onZoomChanged = { [weak self] in
            self?.updateThumbnailVisibility()
        }
    }

    /// 横持ち/縦持ちの切り替わりを検知し、レーティングバー・PiPボタン・保存ボタン付近の制約セットを差し替える。
    private func updateBottomBarLayoutIfNeeded() {
        let isLandscape = view.bounds.width > view.bounds.height
        guard isLandscape != isCurrentlyLandscape else { return }
        isCurrentlyLandscape = isLandscape
        PhotoViewerLayoutBuilder.toggleBottomBarLayout(
            toLandscape: isLandscape,
            portraitConstraints: portraitBottomBarConstraints,
            landscapeConstraints: landscapeBottomBarConstraints
        )
    }

    private func setupOverlay() {
        let bottomBarConstraints = PhotoViewerLayoutBuilder.setupOverlay(
            containerView: view,
            closeButtonView: closeButtonView,
            prevButtonView: prevButtonView,
            nextButtonView: nextButtonView,
            prevHitAreaButton: prevHitAreaButton,
            nextHitAreaButton: nextHitAreaButton,
            photoInfoPillView: photoInfoPillView,
            thumbnailImageView: thumbnailImageView,
            saveButtonView: saveButtonView,
            pipOrientationBarView: pipOrientationBarView,
            ratingLabelBarView: ratingLabelBarView,
            bottomBarGroupGuide: bottomBarGroupGuide,
            loadingIndicator: loadingIndicator,
            lastSavedDateLabel: lastSavedDateLabel,
            isRatingEnabled: viewModel.isRatingEnabled
        )
        portraitBottomBarConstraints = bottomBarConstraints.portrait
        landscapeBottomBarConstraints = bottomBarConstraints.landscape
    }

    private func setupActions() {
        closeButtonView.button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        pipOrientationBarView.orientationButton.addTarget(self, action: #selector(orientationLockTapped), for: .touchUpInside)
        // タップ・長押しはガラスボタンの前面にある広いタッチ領域ボタンで検出する。
        prevHitAreaButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextHitAreaButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        saveButtonView.button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        pipOrientationBarView.pipButton.addTarget(self, action: #selector(pipTapped), for: .touchUpInside)
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

        // ドラッグズーム（長押し）は写真ページャの領域で検出する。
        let longPressZoom = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressZoom(_:)))
        longPressZoom.minimumPressDuration = 0.5
        pageItemVC.view.addGestureRecognizer(longPressZoom)
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
            self.thumbnailImageView.alpha = alpha
            self.saveButtonView.alpha = alpha
            self.pipOrientationBarView.alpha = alpha
            self.ratingLabelBarView.alpha = alpha
            self.lastSavedDateLabel.alpha = alpha
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    /// サムネイルは画像をズームしている場合のみ表示する
    private func updateThumbnailVisibility() {
        thumbnailImageView.isHidden = !(pageItemVC.currentPhotoCell?.isZoomed ?? false)
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
            pipOrientationBarView.pipButton.isEnabled = false
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
            viewModel.startAutoNavigation(forward: false)
        case .ended, .cancelled, .failed:
            viewModel.stopAutoNavigation()
        default:
            break
        }
    }

    @objc private func nextLongPressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            viewModel.startAutoNavigation(forward: true)
        case .ended, .cancelled, .failed:
            viewModel.stopAutoNavigation()
        default:
            break
        }
    }

    // MARK: - ダブルタップズーム

    /// ダブルタップで、ズーム中なら最小へ、そうでなければタップ位置へズームインする（中央セルに適用）。
    private func handleDoubleTapZoom(at locationInImage: CGPoint) {
        guard let zoom = pageItemVC.currentPhotoCell?.zoomScrollView else { return }
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

    // MARK: - 長押しドラッグズーム

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
            if let zoom = pageItemVC.currentPhotoCell?.zoomScrollView {
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

// MARK: - UIAdaptivePresentationControllerDelegate

extension PhotoViewerViewController: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        // 画像をズーム中はスワイプで閉じる操作を無効にする
        !(pageItemVC.currentPhotoCell?.isZoomed ?? false)
    }
}
