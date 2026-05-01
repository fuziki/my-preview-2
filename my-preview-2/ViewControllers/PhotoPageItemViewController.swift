import UIKit

protocol PhotoPageItemDelegate: AnyObject {
    func pageItemDidTap(_ vc: PhotoPageItemViewController)
    func pageItemDidDoubleTap(_ vc: PhotoPageItemViewController, at locationInImage: CGPoint)
}

/// A single-image page used inside UIPageViewController for swipe navigation.
/// Owns its own PhotoZoomScrollView and loads the image asynchronously from a URL.
final class PhotoPageItemViewController: UIViewController {

    // MARK: - Properties

    let index: Int
    let url: URL
    private(set) var loadedImage: UIImage?

    weak var delegate: PhotoPageItemDelegate?

    let zoomScrollView = PhotoZoomScrollView()

    var isZoomed: Bool {
        zoomScrollView.zoomScale > zoomScrollView.minimumZoomScale + 0.001
    }

    // MARK: - Init

    init(index: Int, url: URL) {
        self.index = index
        self.url = url
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
        setupGestures()
        Task { await loadImage() }
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

    private func setupGestures() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)

        zoomScrollView.addGestureRecognizer(singleTap)
        zoomScrollView.addGestureRecognizer(doubleTap)
    }

    // MARK: - Image Display

    /// Replaces the displayed image without changing the zoom level if orientation matches.
    func display(image: UIImage, previousOrientation: ImageOrientation? = nil) {
        loadedImage = image
        zoomScrollView.display(image: image, previousOrientation: previousOrientation)
    }

    // MARK: - Private

    private func loadImage() async {
        let url = self.url
        let data = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value
        guard let data, let image = UIImage(data: data) else { return }
        display(image: image)
    }

    @objc private func handleSingleTap() {
        delegate?.pageItemDidTap(self)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        delegate?.pageItemDidDoubleTap(self, at: gesture.location(in: zoomScrollView.imageView))
    }
}
