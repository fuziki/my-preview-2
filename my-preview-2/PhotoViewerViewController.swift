import UIKit

final class PhotoViewerViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: PhotoViewerViewModel
    private var lastLayoutSize: CGSize = .zero

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

    private let overlayView: PassthroughView = {
        let view = PassthroughView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let topBarBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        return blur
    }()

    private let bottomBarBlur: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        blur.translatesAutoresizingMaskIntoConstraints = false
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
        label.textAlignment = .center
        return label
    }()

    private let saveButton: UIButton = {
        var config = UIButton.Configuration.borderless()
        config.title = "↓ 保存"
        config.baseForegroundColor = .white
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = UIFont.preferredFont(forTextStyle: .footnote)
            return updated
        }
        return UIButton(configuration: config)
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
        updateOverlayVisibility(visible: viewModel.isOverlayVisible)

        if let image = viewModel.currentImage {
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
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Top bar
        overlayView.addSubview(topBarBlur)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        topBarBlur.contentView.addSubview(closeButton)
        NSLayoutConstraint.activate([
            topBarBlur.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
            topBarBlur.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
            topBarBlur.topAnchor.constraint(equalTo: overlayView.topAnchor),
            topBarBlur.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            closeButton.leadingAnchor.constraint(equalTo: topBarBlur.leadingAnchor, constant: 8),
            closeButton.bottomAnchor.constraint(equalTo: topBarBlur.bottomAnchor, constant: -8),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        // Bottom bar
        overlayView.addSubview(bottomBarBlur)

        // Center stack (filename + save)
        let centerStack = UIStackView(arrangedSubviews: [fileNameLabel, saveButton])
        centerStack.axis = .vertical
        centerStack.alignment = .center
        centerStack.spacing = 4
        centerStack.translatesAutoresizingMaskIntoConstraints = false

        prevButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBarBlur.contentView.addSubview(prevButton)
        bottomBarBlur.contentView.addSubview(nextButton)
        bottomBarBlur.contentView.addSubview(centerStack)

        NSLayoutConstraint.activate([
            bottomBarBlur.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
            bottomBarBlur.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
            bottomBarBlur.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor),
            bottomBarBlur.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -72),

            prevButton.leadingAnchor.constraint(equalTo: bottomBarBlur.contentView.leadingAnchor, constant: 16),
            prevButton.centerYAnchor.constraint(equalTo: bottomBarBlur.contentView.centerYAnchor),
            prevButton.widthAnchor.constraint(equalToConstant: 44),
            prevButton.heightAnchor.constraint(equalToConstant: 44),

            nextButton.trailingAnchor.constraint(equalTo: bottomBarBlur.contentView.trailingAnchor, constant: -16),
            nextButton.centerYAnchor.constraint(equalTo: bottomBarBlur.contentView.centerYAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 44),
            nextButton.heightAnchor.constraint(equalToConstant: 44),

            centerStack.centerXAnchor.constraint(equalTo: bottomBarBlur.contentView.centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: bottomBarBlur.contentView.centerYAnchor),
            centerStack.leadingAnchor.constraint(greaterThanOrEqualTo: prevButton.trailingAnchor, constant: 8),
            centerStack.trailingAnchor.constraint(lessThanOrEqualTo: nextButton.leadingAnchor, constant: -8),
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
            self.overlayView.alpha = visible ? 1 : 0
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
        viewModel.navigatePrevious()
    }

    @objc private func nextTapped() {
        viewModel.navigateNext()
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

// MARK: - PassthroughView

/// A UIView that lets touches pass through to views behind it when no subview claims the touch.
/// Without this, the overlay would intercept ALL touches (including pinch-to-zoom on the scroll view).
private final class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit == self ? nil : hit
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
