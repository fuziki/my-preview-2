import UIKit

final class PhotoViewerViewController: UIViewController {

    // MARK: - プロパティ

    private let viewModel: PhotoViewerViewModel
    private var displayedImage: UIImage?
    private var autoNavigationTask: Task<Void, Never>?

    // MARK: - ページビューコントローラー

    private lazy var pageViewController: UIPageViewController = {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 16]
        )
        pvc.dataSource = self
        pvc.delegate = self
        return pvc
    }()

    private var currentItemVC: PhotoPageItemViewController? {
        pageViewController.viewControllers?.first as? PhotoPageItemViewController
    }

    // MARK: - ビュー

    private let closeButtonView = GlassButtonView.circle(systemImageName: "xmark")
    private let prevButtonView = GlassButtonView.circle(systemImageName: "chevron.left")
    private let nextButtonView = GlassButtonView.circle(systemImageName: "chevron.right")

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
        setupPageViewController()
        setupOverlay()
        setupActions()
        Task { await viewModel.loadInitial() }
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
        nextButtonView.button.isEnabled = viewModel.canGoNext
        nextButtonView.button.tintColor = viewModel.canGoNext ? .white : .systemGray
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

            if currentItemVC?.index != viewModel.currentIndex {
                // ボタンナビゲーション: 同じVCのインデックスを更新し、画像を上書きする。
                // VCを新規作成しないことで、同じ向きの場合にズーム状態が自然に引き継がれる。
                currentItemVC?.index = viewModel.currentIndex
            }
            // スワイプナビゲーション（または初回読み込み）はインデックスが既に一致している。
            currentItemVC?.display(image: image, previousOrientation: viewModel.previousOrientation)
            if let currentVC = currentItemVC {
                // UIPageViewControllerに現在のVCを通知し、隣ページのキャッシュを再生成させる。
                pageViewController.setViewControllers([currentVC], direction: .forward, animated: false)
            }
        }
    }

    // MARK: - セットアップ

    private func setupPageViewController() {
        let initialVC = makeItemVC(for: viewModel.currentIndex)
        pageViewController.setViewControllers([initialVC], direction: .forward, animated: false)

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        pageViewController.didMove(toParent: self)

        // ズーム中はページスワイプを無効化する。
        for recognizer in pageViewController.gestureRecognizers {
            recognizer.delegate = self
        }
    }

    private func makeItemVC(for index: Int) -> PhotoPageItemViewController {
        let vc = PhotoPageItemViewController(index: index, url: viewModel.allURLs[index])
        vc.delegate = self
        return vc
    }

    private func setupOverlay() {
        // 各フローティング要素をpageViewController.viewの上に直接追加する。

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
    }

    private func setupActions() {
        closeButtonView.button.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        prevButtonView.button.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextButtonView.button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        saveButtonView.button.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let prevLongPress = UILongPressGestureRecognizer(target: self, action: #selector(prevLongPressed(_:)))
        prevLongPress.minimumPressDuration = 1.0
        prevButtonView.button.addGestureRecognizer(prevLongPress)

        let nextLongPress = UILongPressGestureRecognizer(target: self, action: #selector(nextLongPressed(_:)))
        nextLongPress.minimumPressDuration = 1.0
        nextButtonView.button.addGestureRecognizer(nextLongPress)

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

// MARK: - PhotoPageItemDelegate

extension PhotoViewerViewController: PhotoPageItemDelegate {
    func pageItemDidTap(_ vc: PhotoPageItemViewController) {
        viewModel.toggleOverlay()
    }

    func pageItemDidDoubleTap(_ vc: PhotoPageItemViewController, at locationInImage: CGPoint) {
        let zoom = vc.zoomScrollView
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

// MARK: - UIPageViewControllerDataSource

extension PhotoViewerViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let itemVC = viewController as? PhotoPageItemViewController,
              itemVC.index > 0 else { return nil }
        return makeItemVC(for: itemVC.index - 1)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let itemVC = viewController as? PhotoPageItemViewController,
              itemVC.index < viewModel.allURLs.count - 1 else { return nil }
        return makeItemVC(for: itemVC.index + 1)
    }
}

// MARK: - UIPageViewControllerDelegate

extension PhotoViewerViewController: UIPageViewControllerDelegate {
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let newVC = pageViewController.viewControllers?.first as? PhotoPageItemViewController else { return }
        // ここで displayedImage を設定しない — updateProperties() が画像の変化を検知してサムネイルを更新するため。
        Task { await viewModel.didSwipeTo(index: newVC.index, image: newVC.loadedImage) }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension PhotoViewerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // ズーム中はページスワイプを無効化する。
        !(currentItemVC?.isZoomed ?? false)
    }
}
