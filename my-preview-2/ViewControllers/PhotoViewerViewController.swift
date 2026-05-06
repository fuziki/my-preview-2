import UIKit

final class PhotoViewerViewController: UIViewController {

    // MARK: - プロパティ

    private let viewModel: PhotoViewerViewModel
    private var displayedImage: UIImage?
    private var autoNavigationTask: Task<Void, Never>?
    /// 現在表示中のURL（FileBrowserがズーム戻り先セルを特定するために使用する）
    var currentURL: URL { viewModel.currentURL }

    /// 閉じる時に呼ばれるコールバック（最後に表示していたURLを通知する）
    var onDismiss: ((URL) -> Void)?

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

    private let fileNameBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 16
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth = 0.5
        blur.clipsToBounds = true
        return blur
    }()

    private let fileNameStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 2
        stack.alignment = .leading
        return stack
    }()

    private let fileNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .callout)
        label.lineBreakMode = .byTruncatingMiddle
        label.numberOfLines = 1
        return label
    }()

    private let exifLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.font = .preferredFont(forTextStyle: .caption1)
        label.numberOfLines = 1
        label.isHidden = true
        return label
    }()

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private var thumbnailSizeConstraints: [NSLayoutConstraint] = []

    private let saveButtonView: GlassButtonView = {
        var config = UIButton.Configuration.borderless()
        config.title = "↓ 保存"
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.foregroundColor = .white
            return updated
        }
        let button = UIButton(configuration: config)
        return GlassButtonView(button: button, cornerRadius: 22)
    }()

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

    init(input: PhotoViewerInput, services: PhotoViewerServices) {
        viewModel = PhotoViewerViewModel(input: input, services: services)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - ライフサイクル

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCollectionView()
        setupOverlay()
        setupActions()
        Task { await viewModel.loadInitial() }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateCollectionViewFrame()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // ズームトランジションのスワイプ閉じ制御のため、プレゼンテーションコントローラのデリゲートを設定する
        presentationController?.delegate = self
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed {
            // 閉じる時点での表示URLをFileBrowserへ通知する
            onDismiss?(viewModel.currentURL)
        }
    }

    // MARK: - ステータスバー

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersStatusBarHidden: Bool { !viewModel.isOverlayVisible }

    // MARK: - updateProperties

    override func updateProperties() {
        super.updateProperties()
        fileNameLabel.text = viewModel.currentFileName
        let exifParts = [
            viewModel.exifInfo?.iso,
            viewModel.exifInfo?.focalLength,
            viewModel.exifInfo?.exposureValue,
            viewModel.exifInfo?.fNumber,
            viewModel.exifInfo?.shutterSpeed,
        ].compactMap { $0 }
        exifLabel.text = exifParts.joined(separator: "  ")
        exifLabel.isHidden = exifParts.isEmpty
        prevButtonView.button.isEnabled = viewModel.canGoPrevious
        prevButtonView.button.tintColor = viewModel.canGoPrevious ? .white : .systemGray
        prevHitAreaButton.isEnabled = viewModel.canGoPrevious
        nextButtonView.button.isEnabled = viewModel.canGoNext
        nextButtonView.button.tintColor = viewModel.canGoNext ? .white : .systemGray
        nextHitAreaButton.isEnabled = viewModel.canGoNext
        updateSaveButton(status: viewModel.saveStatus)
        if let date = viewModel.lastSavedDate {
            lastSavedDateLabel.text = "最終保存: " + Self.savedDateFormatter.string(from: date)
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

    private func setupOverlay() {
        // 各フローティング要素をcollectionViewの上に直接追加する。

        // 閉じるボタン: 左上のフローティング円
        view.addSubview(closeButtonView)
        NSLayoutConstraint.activate([
            closeButtonView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButtonView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        ])

        // 前へボタン: 左下のフローティング円
        view.addSubview(prevButtonView)
        NSLayoutConstraint.activate([
            prevButtonView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            prevButtonView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        ])

        // 次へボタン: 右下のフローティング円
        view.addSubview(nextButtonView)
        NSLayoutConstraint.activate([
            nextButtonView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButtonView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        // ファイル名 + EXIF: 右上のフローティングピル
        fileNameStack.addArrangedSubview(fileNameLabel)
        fileNameStack.addArrangedSubview(exifLabel)
        view.addSubview(fileNameBlur)
        fileNameBlur.contentView.addSubview(fileNameStack)
        NSLayoutConstraint.activate([
            fileNameBlur.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            fileNameBlur.leadingAnchor.constraint(greaterThanOrEqualTo: closeButtonView.trailingAnchor, constant: 8),
            fileNameBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            fileNameBlur.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            fileNameStack.centerYAnchor.constraint(equalTo: fileNameBlur.contentView.centerYAnchor),
            fileNameStack.topAnchor.constraint(greaterThanOrEqualTo: fileNameBlur.contentView.topAnchor, constant: 8),
            fileNameStack.bottomAnchor.constraint(lessThanOrEqualTo: fileNameBlur.contentView.bottomAnchor, constant: -8),
            fileNameStack.leadingAnchor.constraint(equalTo: fileNameBlur.contentView.leadingAnchor, constant: 14),
            fileNameStack.trailingAnchor.constraint(equalTo: fileNameBlur.contentView.trailingAnchor, constant: -14),
        ])

        // サムネイル: ファイル名ラベルの下、右揃え
        view.addSubview(thumbnailImageView)
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: fileNameBlur.bottomAnchor, constant: 8),
            thumbnailImageView.trailingAnchor.constraint(equalTo: fileNameBlur.trailingAnchor),
        ])

        // 保存ボタン: 下部中央のカプセル形
        view.addSubview(saveButtonView)
        NSLayoutConstraint.activate([
            saveButtonView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            saveButtonView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveButtonView.leadingAnchor.constraint(greaterThanOrEqualTo: prevButtonView.trailingAnchor, constant: 8),
            saveButtonView.trailingAnchor.constraint(lessThanOrEqualTo: nextButtonView.leadingAnchor, constant: -8),
            saveButtonView.heightAnchor.constraint(equalToConstant: 44),
            saveButtonView.button.topAnchor.constraint(equalTo: saveButtonView.topAnchor),
            saveButtonView.button.bottomAnchor.constraint(equalTo: saveButtonView.bottomAnchor),
            saveButtonView.button.leadingAnchor.constraint(equalTo: saveButtonView.leadingAnchor),
            saveButtonView.button.trailingAnchor.constraint(equalTo: saveButtonView.trailingAnchor),
        ])

        // ローディングインジケーター: 保存ボタンの上
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: saveButtonView.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: saveButtonView.topAnchor, constant: -8),
        ])

        // 最終保存日時ラベル: 保存ボタンの下
        view.addSubview(lastSavedDateLabel)
        NSLayoutConstraint.activate([
            lastSavedDateLabel.topAnchor.constraint(equalTo: saveButtonView.bottomAnchor, constant: 4),
            lastSavedDateLabel.centerXAnchor.constraint(equalTo: saveButtonView.centerXAnchor),
        ])

        // 前へタッチ領域: ガラスボタンより広い四角形（88×88）。ガラスボタンの上に重ねて前面に配置する。
        // leadingをそろえることで、タッチ領域がガラスボタンの右・上方向に広がる。
        view.addSubview(prevHitAreaButton)
        NSLayoutConstraint.activate([
            prevHitAreaButton.widthAnchor.constraint(equalToConstant: 88),
            prevHitAreaButton.heightAnchor.constraint(equalToConstant: 88),
            prevHitAreaButton.bottomAnchor.constraint(equalTo: prevButtonView.bottomAnchor),
            prevHitAreaButton.leadingAnchor.constraint(equalTo: prevButtonView.leadingAnchor),
        ])

        // 次へタッチ領域: ガラスボタンより広い四角形（88×88）。ガラスボタンの上に重ねて前面に配置する。
        // trailingをそろえることで、タッチ領域がガラスボタンの左・上方向に広がる。
        view.addSubview(nextHitAreaButton)
        NSLayoutConstraint.activate([
            nextHitAreaButton.widthAnchor.constraint(equalToConstant: 88),
            nextHitAreaButton.heightAnchor.constraint(equalToConstant: 88),
            nextHitAreaButton.bottomAnchor.constraint(equalTo: nextButtonView.bottomAnchor),
            nextHitAreaButton.trailingAnchor.constraint(equalTo: nextButtonView.trailingAnchor),
        ])
    }

    private func setupActions() {
        closeButtonView.button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        // タップ・長押しはガラスボタンの前面にある広いタッチ領域ボタンで検出する。
        prevHitAreaButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextHitAreaButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        saveButtonView.button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let prevLongPress = UILongPressGestureRecognizer(target: self, action: #selector(prevLongPressed(_:)))
        prevLongPress.minimumPressDuration = 1.0
        prevHitAreaButton.addGestureRecognizer(prevLongPress)

        let nextLongPress = UILongPressGestureRecognizer(target: self, action: #selector(nextLongPressed(_:)))
        nextLongPress.minimumPressDuration = 1.0
        nextHitAreaButton.addGestureRecognizer(nextLongPress)

        // UIKitが無効時に保存ボタンを自動的に暗くするのを防ぐ。
        // ガラス背景では約30%の不透明度の白テキストがほぼ見えなくなるため。
        saveButtonView.button.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.baseForegroundColor = .white
            button.configuration = config
        }
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
            self.fileNameBlur.alpha = alpha
            self.thumbnailImageView.alpha = alpha
            self.saveButtonView.alpha = alpha
            self.lastSavedDateLabel.alpha = alpha
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - 保存ボタン

    private func updateSaveButton(status: SaveStatus) {
        switch status {
        case .idle:
            saveButtonView.button.configuration?.title = "↓ 保存"
            saveButtonView.button.isEnabled = true
        case .saving:
            saveButtonView.button.configuration?.title = "⏳ 保存中..."
            saveButtonView.button.isEnabled = false
        case .success:
            saveButtonView.button.configuration?.title = "✓ 保存完了"
            saveButtonView.button.isEnabled = false
        case .failure:
            saveButtonView.button.configuration?.title = "✕ 失敗"
            saveButtonView.button.isEnabled = true
        }
    }

    // MARK: - アクション

    @objc private func closeTapped() {
        dismiss(animated: true)
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
}

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
}

// MARK: - UICollectionViewDataSource

extension PhotoViewerViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.allURLs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoPageItemCell.reuseIdentifier,
            for: indexPath
        ) as! PhotoPageItemCell
        // layoutPageOffsetを加算して論理インデックスに変換する。境界値はクランプする。
        let logicalIndex = max(0, min(viewModel.allURLs.count - 1, indexPath.item + layoutPageOffset))
        cell.delegate = self
        cell.configure(index: logicalIndex, url: viewModel.allURLs[logicalIndex])
        return cell
    }
}

// MARK: - UICollectionViewDelegate / UIScrollViewDelegate

extension PhotoViewerViewController: UICollectionViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
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
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        // 画像をズーム中はスワイプで閉じる操作を無効にする
        !(currentItemCell?.isZoomed ?? false)
    }
}
