import Foundation
import UIKit
import Observation
import Photos

enum SaveStatus {
    case idle, saving, success, failure
}

enum ImageOrientation {
    case portrait, landscape
}

extension UIImage {
    var photoOrientation: ImageOrientation {
        size.width >= size.height ? .landscape : .portrait
    }
}

@MainActor
@Observable
final class PhotoViewerViewModel {
    private(set) var currentIndex: Int
    private(set) var allURLs: [URL]
    private(set) var currentImage: UIImage? = nil
    private(set) var previousOrientation: ImageOrientation? = nil
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
        let image = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url) else { return nil as UIImage? }
            return UIImage(data: data)
        }.value
        await MainActor.run {
            self.currentImage = image
        }
    }

    func navigatePrevious() {
        guard canGoPrevious else { return }
        previousOrientation = currentImage?.photoOrientation
        currentIndex -= 1
        saveStatus = .idle
        Task { await loadCurrentImage() }
    }

    func navigateNext() {
        guard canGoNext else { return }
        previousOrientation = currentImage?.photoOrientation
        currentIndex += 1
        saveStatus = .idle
        Task { await loadCurrentImage() }
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
