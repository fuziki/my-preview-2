import UIKit

/// A UIScrollView subclass that manages image display with pinch-to-zoom,
/// aspect-fit scaling, and centered content insets.
/// Automatically recalculates zoom when its bounds change (e.g., device rotation).
final class PhotoZoomScrollView: UIScrollView {

    // MARK: - Properties

    private(set) var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleToFill
        return iv
    }()

    private var currentImage: UIImage?
    private var lastKnownBoundsSize: CGSize = .zero

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupScrollView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupScrollView() {
        translatesAutoresizingMaskIntoConstraints = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        bouncesZoom = true
        delegate = self
        addSubview(imageView)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let newSize = bounds.size
        if newSize != lastKnownBoundsSize, newSize.width > 0, newSize.height > 0 {
            // Bounds changed (e.g. rotation): recalculate fit scale.
            lastKnownBoundsSize = newSize
            if let image = currentImage {
                resetZoom(for: image)
            }
        } else {
            centerImageView()
        }
    }

    // MARK: - Image Display

    /// Updates the displayed image and adjusts zoom based on orientation change.
    func display(image: UIImage, previousOrientation: ImageOrientation?) {
        currentImage = image
        imageView.image = image
        let newOrientation = image.photoOrientation
        if previousOrientation == nil || previousOrientation != newOrientation {
            resetZoom(for: image)
        } else {
            updateZoomForSameOrientation(for: image)
        }
    }

    // MARK: - Zoom

    func resetZoom(for image: UIImage) {
        // Must reset to zoomScale=1 before modifying imageView.frame.
        // Setting frame while a non-identity transform is active is undefined behavior (Apple docs).
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
    }

    private func updateZoomForSameOrientation(for image: UIImage) {
        let prevMinScale = minimumZoomScale
        let zoomRatio = prevMinScale > 0 ? zoomScale / prevMinScale : 1.0

        // Must reset to zoomScale=1 before modifying imageView.frame (same reason as resetZoom).
        minimumZoomScale = 1.0
        maximumZoomScale = 1.0
        zoomScale = 1.0
        contentInset = .zero

        imageView.frame = CGRect(origin: .zero, size: image.size)
        contentSize = image.size

        let scale = aspectFitScale(for: image)
        minimumZoomScale = scale
        maximumZoomScale = max(1.0, scale)
        // Restore zoom proportional to previous fit level, clamped to valid range.
        let targetZoom = min(max(scale * zoomRatio, scale), max(1.0, scale))
        zoomScale = targetZoom

        centerImageView()
        clampContentOffset()
    }

    private func aspectFitScale(for image: UIImage) -> CGFloat {
        let size = bounds.size
        guard image.size.width > 0, image.size.height > 0 else { return 1 }
        return min(size.width / image.size.width, size.height / image.size.height)
    }

    private func centerImageView() {
        // Use contentInset for centering — never modify imageView.frame directly while UIScrollView
        // has a zoom transform applied (doing so is undefined behavior per Apple docs).
        let boundsSize = bounds.size
        let contentSize = self.contentSize
        let offsetX = max((boundsSize.width - contentSize.width) / 2, 0)
        let offsetY = max((boundsSize.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: offsetY, right: offsetX)
    }

    private func clampContentOffset() {
        // Account for contentInset when clamping (inset shifts the valid offset range).
        let inset = contentInset
        let minX = -inset.left
        let minY = -inset.top
        let maxX = max(minX, contentSize.width - bounds.width)
        let maxY = max(minY, contentSize.height - bounds.height)
        var offset = contentOffset
        offset.x = min(max(offset.x, minX), maxX)
        offset.y = min(max(offset.y, minY), maxY)
        setContentOffset(offset, animated: false)
    }
}

// MARK: - UIScrollViewDelegate

extension PhotoZoomScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerImageView()
    }
}
