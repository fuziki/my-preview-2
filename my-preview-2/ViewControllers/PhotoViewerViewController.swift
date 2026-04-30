import UIKit

final class PhotoViewerViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: PhotoViewerViewModel
    private var lastLayoutSize: CGSize = .zero
    private var displayedImage: UIImage?

    // MARK: - Views

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        sv.showsHorizontalScrollIndicator = false
        sv.contentInsetAdjustmentBehavior = .never
        sv.bouncesZoom = true
        return sv
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleToFill
        return iv
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    // Floating glass containers (added above scrollView — no hitTest override needed)
    private let closeBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 22
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth = 0.5
        blur.clipsToBounds = true
        return blur
    }()

    private let prevBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 22
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth = 0.5
        blur.clipsToBounds = true
        return blur
    }()

    private let nextBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 22
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth = 0.5
        blur.clipsToBounds = true
        return blur
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

    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private var thumbnailSizeConstraints: [NSLayoutConstraint] = []

    private let saveBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.layer.cornerRadius = 22
        blur.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        blur.layer.borderWidth = 0.5
        blur.clipsToBounds = true
        return blur
    }()

    private let closeButton: UIButton = {
        var config = UIButton.Configuration.borderless()
        config.image = UIImage(systemName: "xmark")
        config.baseForegroundColor = .white
        return UIButton(configuration: config)
    }()

    private let prevButton: UIButton = {
        var config = UIButton.Configuration.borderless()
        config.image = UIImage(systemName: "chevron.left")
        config.baseForegroundColor = .white
        return UIButton(configuration: config)
    }()

    private let nextButton: UIButton = {
        var config = UIButton.Configuration.borderless()
        config.image = UIImage(systemName: "chevron.right")
        config.baseForegroundColor = .white
        return UIButton(configuration: config)
    }()

    private let fileNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .callout)
        label.lineBreakMode = .byTruncatingMiddle
        label.numberOfLines = 1
        label.textAlignment = .left
        return label
    }()

    private let saveButton: UIButton = {
        var config = UIButton.Configuration.borderless()
        config.title = "↓ 保存"
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.foregroundColor = .white
            return updated
        }
        let button = UIButton(configuration: config)
        return button
    }()

    // MARK: - Init

    init(input: PhotoViewerInput) {
        viewModel = PhotoViewerViewModel(input: input)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupScrollView()
        setupOverlay()
        setupGestures()
        setupActions()
        Task { await viewModel.loadCurrentImage() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let newSize = scrollView.bounds.size
        guard newSize != lastLayoutSize, newSize.width > 0, newSize.height > 0 else { return }
        lastLayoutSize = newSize
        if let image = viewModel.currentImage {
            resetZoom(for: image)
        }
    }

    // MARK: - Status Bar

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var prefersStatusBarHidden: Bool { !viewModel.isOverlayVisible }

    // MARK: - updateProperties

    override func updateProperties() {
        super.updateProperties()
        fileNameLabel.text = viewModel.currentFileName
        prevButton.isEnabled = viewModel.canGoPrevious
        prevButton.tintColor = viewModel.canGoPrevious ? .white : .systemGray
        nextButton.isEnabled = viewModel.canGoNext
        nextButton.tintColor = viewModel.canGoNext ? .white : .systemGray
        updateSaveButton(status: viewModel.saveStatus)
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
            updateImage(image)
        }
    }

    // MARK: - Setup

    private func setupScrollView() {
        scrollView.delegate = self
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        scrollView.addSubview(imageView)
    }

    private func setupOverlay() {
        // Each floating element is added directly to view above scrollView.
        // Touches pass naturally to scrollView in uncovered areas — no hitTest override needed.

        // Close button: top-left floating circle
        view.addSubview(closeBlur)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeBlur.contentView.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeBlur.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeBlur.widthAnchor.constraint(equalToConstant: 44),
            closeBlur.heightAnchor.constraint(equalToConstant: 44),
            closeButton.centerXAnchor.constraint(equalTo: closeBlur.contentView.centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: closeBlur.contentView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        // Prev button: bottom-left floating circle
        view.addSubview(prevBlur)
        prevButton.translatesAutoresizingMaskIntoConstraints = false
        prevBlur.contentView.addSubview(prevButton)
        NSLayoutConstraint.activate([
            prevBlur.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            prevBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            prevBlur.widthAnchor.constraint(equalToConstant: 44),
            prevBlur.heightAnchor.constraint(equalToConstant: 44),
            prevButton.centerXAnchor.constraint(equalTo: prevBlur.contentView.centerXAnchor),
            prevButton.centerYAnchor.constraint(equalTo: prevBlur.contentView.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 44),
            prevButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        // Next button: bottom-right floating circle
        view.addSubview(nextBlur)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextBlur.contentView.addSubview(nextButton)
        NSLayoutConstraint.activate([
            nextBlur.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            nextBlur.widthAnchor.constraint(equalToConstant: 44),
            nextBlur.heightAnchor.constraint(equalToConstant: 44),
            nextButton.centerXAnchor.constraint(equalTo: nextBlur.contentView.centerXAnchor),
            nextButton.centerYAnchor.constraint(equalTo: nextBlur.contentView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        // File name label: top-right floating pill (pinned to right edge)
        view.addSubview(fileNameBlur)
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileNameBlur.contentView.addSubview(fileNameLabel)
        NSLayoutConstraint.activate([
            fileNameBlur.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            fileNameBlur.leadingAnchor.constraint(greaterThanOrEqualTo: closeBlur.trailingAnchor, constant: 8),
            fileNameBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            fileNameBlur.heightAnchor.constraint(equalToConstant: 44),
            fileNameLabel.centerYAnchor.constraint(equalTo: fileNameBlur.contentView.centerYAnchor),
            fileNameLabel.leadingAnchor.constraint(equalTo: fileNameBlur.contentView.leadingAnchor, constant: 14),
            fileNameLabel.trailingAnchor.constraint(equalTo: fileNameBlur.contentView.trailingAnchor, constant: -14),
        ])

        // Thumbnail: below file name label, right-aligned, sized by aspect ratio
        view.addSubview(thumbnailImageView)
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: fileNameBlur.bottomAnchor, constant: 8),
            thumbnailImageView.trailingAnchor.constraint(equalTo: fileNameBlur.trailingAnchor),
        ])

        // Save button: bottom-center capsule
        view.addSubview(saveBlur)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveBlur.contentView.addSubview(saveButton)
        NSLayoutConstraint.activate([
            saveBlur.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            saveBlur.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveBlur.leadingAnchor.constraint(greaterThanOrEqualTo: prevBlur.trailingAnchor, constant: 8),
            saveBlur.trailingAnchor.constraint(lessThanOrEqualTo: nextBlur.leadingAnchor, constant: -8),
            saveBlur.heightAnchor.constraint(equalToConstant: 44),
            saveButton.topAnchor.constraint(equalTo: saveBlur.contentView.topAnchor),
            saveButton.bottomAnchor.constraint(equalTo: saveBlur.contentView.bottomAnchor),
            saveButton.leadingAnchor.constraint(equalTo: saveBlur.contentView.leadingAnchor),
            saveButton.trailingAnchor.constraint(equalTo: saveBlur.contentView.trailingAnchor),
        ])

        // Loading indicator: above save button
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: saveBlur.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: saveBlur.topAnchor, constant: -8),
        ])
    }

    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)

        scrollView.addGestureRecognizer(singleTap)
        scrollView.addGestureRecognizer(doubleTap)
    }

    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        // Prevent UIKit from automatically dimming the save button when disabled.
        // The glass background makes white text at ~30% opacity nearly invisible.
        saveButton.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.baseForegroundColor = .white
            button.configuration = config
        }
    }

    // MARK: - Image Display

    private func updateImage(_ image: UIImage) {
        imageView.image = image
        let newOrientation = image.photoOrientation
        if viewModel.previousOrientation == nil || viewModel.previousOrientation != newOrientation {
            resetZoom(for: image)
        } else {
            updateZoomForSameOrientation(for: image)
        }
    }

    private func resetZoom(for image: UIImage) {
        // Must reset to zoomScale=1 before modifying imageView.frame.
        // Setting frame while a non-identity transform is active is undefined behavior (Apple docs).
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.zoomScale = 1.0
        scrollView.contentInset = .zero

        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size

        let scale = aspectFitScale(for: image)
        scrollView.minimumZoomScale = scale
        scrollView.maximumZoomScale = max(1.0, scale)
        scrollView.zoomScale = scale

        centerImageView()
    }

    private func updateZoomForSameOrientation(for image: UIImage) {
        let prevMinScale = scrollView.minimumZoomScale
        let zoomRatio = prevMinScale > 0 ? scrollView.zoomScale / prevMinScale : 1.0

        // Must reset to zoomScale=1 before modifying imageView.frame (same reason as resetZoom).
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.zoomScale = 1.0
        scrollView.contentInset = .zero

        imageView.frame = CGRect(origin: .zero, size: image.size)
        scrollView.contentSize = image.size

        let scale = aspectFitScale(for: image)
        scrollView.minimumZoomScale = scale
        scrollView.maximumZoomScale = max(1.0, scale)
        // Restore zoom proportional to previous fit level, clamped to new valid range
        let targetZoom = min(max(scale * zoomRatio, scale), max(1.0, scale))
        scrollView.zoomScale = targetZoom

        centerImageView()
        clampContentOffset()
    }

    private func aspectFitScale(for image: UIImage) -> CGFloat {
        let bounds = scrollView.bounds
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        return min(bounds.width / image.size.width, bounds.height / image.size.height)
    }

    private func centerImageView() {
        // Use contentInset for centering — never modify imageView.frame directly while UIScrollView
        // has a zoom transform applied (doing so is undefined behavior per Apple docs).
        let boundsSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize
        let offsetX = max((boundsSize.width - contentSize.width) / 2, 0)
        let offsetY = max((boundsSize.height - contentSize.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    private func clampContentOffset() {
        // Account for contentInset when clamping (inset shifts the valid offset range).
        let inset = scrollView.contentInset
        let minX = -inset.left
        let minY = -inset.top
        let maxX = max(minX, scrollView.contentSize.width - scrollView.bounds.width)
        let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height)
        var offset = scrollView.contentOffset
        offset.x = min(max(offset.x, minX), maxX)
        offset.y = min(max(offset.y, minY), maxY)
        scrollView.setContentOffset(offset, animated: false)
    }

    // MARK: - Overlay

    private func updateOverlayVisibility(visible: Bool) {
        UIView.animate(withDuration: 0.2) {
            let alpha: CGFloat = visible ? 1 : 0
            self.closeBlur.alpha = alpha
            self.prevBlur.alpha = alpha
            self.nextBlur.alpha = alpha
            self.fileNameBlur.alpha = alpha
            self.thumbnailImageView.alpha = alpha
            self.saveBlur.alpha = alpha
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - Save Button

    private func updateSaveButton(status: SaveStatus) {
        switch status {
        case .idle:
            saveButton.configuration?.title = "↓ 保存"
            saveButton.isEnabled = true
        case .saving:
            saveButton.configuration?.title = "⏳ 保存中..."
            saveButton.isEnabled = false
        case .success:
            saveButton.configuration?.title = "✓ 保存完了"
            saveButton.isEnabled = false
        case .failure:
            saveButton.configuration?.title = "✕ 失敗"
            saveButton.isEnabled = true
        }
    }

    // MARK: - Actions

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

    @objc private func handleSingleTap() {
        viewModel.toggleOverlay()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale + 0.001 {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let tapPoint = gesture.location(in: imageView)
            let rect = zoomRect(for: scrollView.maximumZoomScale, center: tapPoint)
            scrollView.zoom(to: rect, animated: true)
        }
    }

    private func zoomRect(for scale: CGFloat, center: CGPoint) -> CGRect {
        let width = scrollView.bounds.width / scale
        let height = scrollView.bounds.height / scale
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }
}

// MARK: - UIScrollViewDelegate

extension PhotoViewerViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
    }
}
