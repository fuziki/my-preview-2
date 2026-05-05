import Photos

enum PhotoLibraryError: Error {
    case unauthorized
}

protocol PhotoLibraryServiceProtocol: AnyObject {
    func save(fileURL: URL) async throws
}

final class PhotoLibraryService: PhotoLibraryServiceProtocol {
    func save(fileURL: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.unauthorized
        }
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = fileURL.lastPathComponent
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, fileURL: fileURL, options: options)
        }
    }
}
