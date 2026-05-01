import Foundation
import UIKit
import Observation
import Photos
import ImageIO

enum SaveStatus {
    case idle, saving, success, failure
}

struct ExifInfo {
    let iso: String?
    let focalLength: String?
    let exposureValue: String?
    let fNumber: String?
    let shutterSpeed: String?
}

enum ImageOrientation {
    case portrait, landscape
}

extension UIImage {
    var photoOrientation: ImageOrientation {
        size.width >= size.height ? .landscape : .portrait
    }
}

@Observable
final class PhotoViewerViewModel {
    private(set) var currentIndex: Int
    private(set) var allURLs: [URL]
    private(set) var currentImage: UIImage? = nil
    private(set) var previousOrientation: ImageOrientation? = nil
    private(set) var isLoading: Bool = false
    private(set) var exifInfo: ExifInfo? = nil
    var saveStatus: SaveStatus = .idle
    var isOverlayVisible: Bool = true

    var currentURL: URL { allURLs[currentIndex] }
    var currentFileName: String { currentURL.lastPathComponent }
    var canGoPrevious: Bool { currentIndex > 0 }
    var canGoNext: Bool { currentIndex < allURLs.count - 1 }

    init(input: PhotoViewerInput) {
        allURLs = input.allURLs
        currentIndex = input.allURLs.firstIndex(of: input.initialURL) ?? 0
    }

    func loadCurrentImage() async {
        let url = currentURL
        isLoading = true
        let result = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return (nil as UIImage?, nil as ExifInfo?) }
            return (UIImage(data: data), await Self.extractExif(from: data))
        }.value
        currentImage = result.0
        exifInfo = result.1
        isLoading = false
    }

    private static func extractExif(from data: Data) -> ExifInfo? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = props[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
            return nil
        }

        let iso: String? = {
            guard let array = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
                  let value = array.first else { return nil }
            return "ISO \(value)"
        }()

        let focalLength: String? = {
            guard let fl = exif[kCGImagePropertyExifFocalLength as String] as? Double else { return nil }
            return String(format: "%.0fmm", fl)
        }()

        let exposureValue: String? = {
            guard let ev = exif[kCGImagePropertyExifExposureBiasValue as String] as? Double else { return nil }
            return ev == 0 ? "±0EV" : String(format: "%+.1fEV", ev)
        }()

        let fNumber: String? = {
            guard let fn = exif[kCGImagePropertyExifFNumber as String] as? Double else { return nil }
            return String(format: "f/%.1f", fn)
        }()

        let shutterSpeed: String? = {
            guard let et = exif[kCGImagePropertyExifExposureTime as String] as? Double, et > 0 else { return nil }
            return et >= 1.0 ? String(format: "%.0fs", et) : "1/\(Int(round(1.0 / et)))s"
        }()

        return ExifInfo(iso: iso, focalLength: focalLength, exposureValue: exposureValue, fNumber: fNumber, shutterSpeed: shutterSpeed)
    }

    func navigatePrevious() async {
        guard canGoPrevious else { return }
        previousOrientation = currentImage?.photoOrientation
        currentIndex -= 1
        saveStatus = .idle
        await loadCurrentImage()
    }

    func navigateNext() async {
        guard canGoNext else { return }
        previousOrientation = currentImage?.photoOrientation
        currentIndex += 1
        saveStatus = .idle
        await loadCurrentImage()
    }

    /// Called after a swipe gesture completes in UIPageViewController.
    /// Updates the current index and reloads only EXIF metadata (the image is already displayed by the page item VC).
    func didSwipeTo(index: Int, image: UIImage?) async {
        previousOrientation = nil  // Swipe always resets zoom on new VC
        currentIndex = index
        saveStatus = .idle
        currentImage = image

        let url = allURLs[index]
        isLoading = true
        let exif = await Task.detached(priority: .userInitiated) { [url] () -> ExifInfo? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return await Self.extractExif(from: data)
        }.value
        exifInfo = exif
        isLoading = false
    }

    func save() async {
        guard currentImage != nil else { return }
        let url = currentURL
        saveStatus = .saving
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveStatus = .failure
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let options = PHAssetResourceCreationOptions()
                options.originalFilename = url.lastPathComponent
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: url, options: options)
            }
            saveStatus = .success
            try await Task.sleep(for: .seconds(2))
            saveStatus = .idle
        } catch {
            saveStatus = .failure
        }
    }

    func toggleOverlay() {
        isOverlayVisible.toggle()
    }
}
