import UIKit

final class PhotoViewerViewController: UIViewController {

    // MARK: - Properties

    private let viewModel: PhotoViewerViewModel
    private var displayedImage: UIImage?
    private var autoNavigationTask: Task<Void, Never>?

    // MARK: - Views

    private let zoomScrollView = PhotoZoomScrollView()

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

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
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

    // MARK: - Status Bar

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
            zoomScrollView.display(image: image, previousOrientation: viewModel.previousOrientation)
        }
    }

    // MARK: - Setup

    private func setupScrollView() {
        view.addSubview(zoomScrollView)
        NSLayoutConstraint.activate([
            zoomScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            zoomScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            zoomScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            zoomScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupOverlay() {
        // Each floating element is added directly to view above zoomScrollView.
        // Touches pass naturally to zoomScrollView in uncovered areas — no hitTest override needed.

        // Close button: top-left floating circle
        view.addSubview(closeButtonView)
        NSLayoutConstraint.activate([
            closeButtonView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButtonView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        ])

        // Prev button: bottom-left floating circle
        view.addSubview(prevButtonView)
        NSLayoutConstraint.activate([
            prevButtonView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            prevButtonView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        ])

        // Next button: bottom-right floating circle
        view.addSubview(nextButtonView)
        NSLayoutConstraint.activate([
            nextButtonView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButtonView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        // File name + exif: top-right floating pill
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

        // Thumbnail: below file name label, right-aligned
        view.addSubview(thumbnailImageView)
        NSLayoutConstraint.activate([
            thumbnailImageView.topAnchor.constraint(equalTo: fileNameBlur.bottomAnchor, constant: 8),
            thumbnailImageView.trailingAnchor.constraint(equalTo: fileNameBlur.trailingAnchor),
        ])

        // Save button: bottom-center capsule
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

        // Loading indicator: above save button
        view.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: saveButtonView.centerXAnchor),
            loadingIndicator.bottomAnchor.constraint(equalTo: saveButtonView.topAnchor, constant: -8),
        ])
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

        // Prevent UIKit from automatically dimming the save button when disabled.
        // The glass background makes white text at ~30% opacity nearly invisible.
        saveButtonView.button.configurationUpdateHandler = { button in
            var config = button.configuration
            config?.baseForegroundColor = .white
            button.configuration = config
        }
    }

    // MARK: - Overlay

    private func updateOverlayVisibility(visible: Bool) {
        UIView.animate(withDuration: 0.2) {
            let alpha: CGFloat = visible ? 1 : 0
            self.closeButtonView.alpha = alpha
            self.prevButtonView.alpha = alpha
            self.nextButtonView.alpha = alpha
            self.fileNameBlur.alpha = alpha
            self.thumbnailImageView.alpha = alpha
            self.saveButtonView.alpha = alpha
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    // MARK: - Save Button

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

    @objc private func handleSingleTap() {
        viewModel.toggleOverlay()
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScrollView.zoomScale > zoomScrollView.minimumZoomScale + 0.001 {
            zoomScrollView.setZoomScale(zoomScrollView.minimumZoomScale, animated: true)
        } else {
            let tapPoint = gesture.location(in: zoomScrollView.imageView)
            let width = zoomScrollView.bounds.width / zoomScrollView.maximumZoomScale
            let height = zoomScrollView.bounds.height / zoomScrollView.maximumZoomScale
            let rect = CGRect(
                x: tapPoint.x - width / 2,
                y: tapPoint.y - height / 2,
                width: width,
                height: height
            )
            zoomScrollView.zoom(to: rect, animated: true)
        }
    }
}
